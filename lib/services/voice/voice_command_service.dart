import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:vosk_flutter_fixed/vosk_flutter.dart';

import '../settings_service.dart';
import '../../utils/app_logger.dart';
import 'voice_command.dart';
import 'voice_command_parser.dart';
import 'voice_command_executor.dart';
import 'voice_language.dart';

/// Stato del motore dei comandi vocali.
enum VoiceStatus {
  /// Il motore non e' ancora stato preparato.
  idle,

  /// Modello in download o in caricamento.
  preparing,

  /// Pronto ad ascoltare.
  ready,

  /// Microfono attivo.
  listening,

  /// Ultimo errore, il dettaglio e' in [VoiceCommandService.errorDetails].
  error,
}

/// Errore che puo' impedire l'uso dei comandi vocali.
enum VoiceError {
  none,
  unsupportedPlatform,
  nativeLibraryMissing,
  modelDownloadFailed,
  modelLoadFailed,
  microphoneDenied,
  recorderUnavailable,
}

/// Motore dei comandi vocali.
///
/// Scarica il modello Vosk, cattura l'audio dal microfono e trasforma le
/// frasi riconosciute in azioni sull'applicazione: il playback di VLC, il
/// volume, lo spostamento nella traccia e le playlist di MyPlaylist.
///
/// Il riconoscimento e' offline: l'audio non lascia mai il dispositivo.
class VoiceCommandService extends ChangeNotifier {
  VoiceCommandService({required this.executor, required this.settingsService}) {
    _language = VoiceLanguage.fromCode(settingsService.voiceLanguage);
    AppLogger.i(
      _tag,
      'Libreria nativa Vosk: ${_nativeLibraryPath ?? 'non impostata'}',
    );
  }

  /// Tag usato nei log di questo servizio.
  static const String _tag = 'VoiceCommandService';

  /// Chi esegue i comandi riconosciuti: il motore non conosce il provider,
  /// cosi' si puo' provarlo con un esecutore finto.
  final VoiceCommandExecutor executor;

  /// Impostazioni: lingua del riconoscimento e microfono scelto.
  final SettingsService settingsService;

  /// Frequenza di campionamento richiesta da Vosk.
  static const int sampleRate = 16000;

  /// Quante voci tiene la cronologia.
  static const int maxHistory = 50;

  static const RecordConfig _recordConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: 1,
  );

  VoiceStatus _status = VoiceStatus.idle;
  VoiceError _error = VoiceError.none;
  String? _errorDetails;
  String _partialTranscript = '';
  final List<VoiceLogEntry> _history = <VoiceLogEntry>[];
  late VoiceLanguage _language;
  final List<InputDevice> _inputDevices = <InputDevice>[];
  String? _selectedDeviceId;
  bool _loadingDevices = false;

  /// Livello di ingresso del microfono in dBFS.
  ///
  /// -160 indica silenzio, 0 il massimo. Viene aggiornato mentre si
  /// ascolta, per far capire se il microfono sta capturing qualcosa.
  final ValueNotifier<double> inputLevel = ValueNotifier<double>(-160);

  Timer? _levelTimer;
  double _peakLevelDb = -160;

  Model? _model;
  Recognizer? _recognizer;
  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _audioSubscription;
  Future<void> _audioChain = Future<void>.value();
  bool _disposed = false;

  VoiceStatus get status => _status;
  VoiceError get error => _error;
  String? get errorDetails => _errorDetails;
  String get partialTranscript => _partialTranscript;
  List<VoiceLogEntry> get history => List<VoiceLogEntry>.unmodifiable(_history);
  VoiceLanguage get language => _language;
  bool get isListening => _status == VoiceStatus.listening;
  bool get isPreparing => _status == VoiceStatus.preparing;

  /// Microfoni disponibili sul sistema.
  List<InputDevice> get inputDevices =>
      List<InputDevice>.unmodifiable(_inputDevices);

  /// Microfono scelto, null quando si usa quello predefinito.
  String? get selectedDeviceId {
    final String? id = _selectedDeviceId;
    if (id == null) return null;
    if (_inputDevices.isEmpty) return null;
    for (final InputDevice device in _inputDevices) {
      if (device.id == id) return id;
    }
    return null;
  }

  /// True mentre l'elenco dei microfoni e' in caricamento.
  bool get loadingDevices => _loadingDevices;

  /// Il riconoscimento Vosk funziona su Linux, Windows e Android. Su macOS
  /// il plugin non espone l'interfaccia nativa.
  bool get isPlatformSupported {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isWindows || Platform.isAndroid;
  }

  /// Percorso della libreria nativa di Vosk, se il runner l'ha impostata.
  String? get _nativeLibraryPath => Platform.environment['LIBVOSK_PATH'];

  /// Carica le impostazioni e la lingua scelta.
  Future<void> init() async {
    await settingsService.init();
    _language = VoiceLanguage.fromCode(settingsService.voiceLanguage);
    notifyListeners();
  }

  /// Prepara il motore: scarica il modello se serve e crea il riconoscitore.
  Future<void> prepare() async {
    if (!isPlatformSupported) {
      _fail(VoiceError.unsupportedPlatform);
      return;
    }

    final String? nativeLibraryError = _checkNativeLibrary();
    if (nativeLibraryError != null) {
      _fail(VoiceError.nativeLibraryMissing, details: nativeLibraryError);
      return;
    }

    if (_status == VoiceStatus.preparing) return;

    _status = VoiceStatus.preparing;
    _error = VoiceError.none;
    _errorDetails = null;
    notifyListeners();

    try {
      final loader = ModelLoader(modelStorage: await _modelStoragePath());
      final modelPath = await loader.loadFromNetwork(_language.modelUrl);

      _model = await VoskFlutterPlugin.instance().createModel(modelPath);
      _recognizer = await VoskFlutterPlugin.instance().createRecognizer(
        model: _model!,
        sampleRate: sampleRate,
      );

      _status = VoiceStatus.ready;
      AppLogger.i(_tag, 'Modello vocale pronto: ${_language.modelName}');
    } on Object catch (e) {
      AppLogger.e(_tag, 'Preparazione del modello vocale fallita', e);
      _fail(
        e is UnsupportedError
            ? VoiceError.unsupportedPlatform
            : VoiceError.modelLoadFailed,
        details: e.toString(),
      );
      return;
    }

    notifyListeners();
  }

  /// Prepara il motore solo se il modello e' gia' presente in locale.
  ///
  /// Non avvia alcun download: se il modello non e' ancora stato scaricato
  /// l'operazione viene saltata e resta al pulsante di download. Serve per
  /// non lasciare il microfono disattivato quando il modello c'e' gia' ma il
  /// motore non e' stato ancora avviato.
  Future<void> prepareIfModelPresent() async {
    if (_status == VoiceStatus.ready ||
        _status == VoiceStatus.preparing ||
        _status == VoiceStatus.listening) {
      return;
    }

    try {
      final loader = ModelLoader(modelStorage: await _modelStoragePath());
      if (!await loader.isModelAlreadyLoaded(_language.modelName)) return;
    } on Object catch (e) {
      AppLogger.w(_tag, 'Modello locale non verificabile', e);
      return;
    }

    await prepare();
  }

  /// Verifica che la libreria nativa di Vosk sia raggiungibile.
  ///
  /// Su Linux il plugin la cerca tramite la variabile d'ambiente
  /// LIBVOSK_PATH, impostata dal runner prima dell'avvio della VM Dart.
  String? _checkNativeLibrary() {
    if (!Platform.isLinux) return null;

    final String? libraryPath = _nativeLibraryPath;
    if (libraryPath == null || libraryPath.isEmpty) {
      return 'La variabile LIBVOSK_PATH non e\' definita.';
    }

    if (!File(libraryPath).existsSync()) {
      return 'La libreria nativa Vosk non esiste: $libraryPath';
    }

    return null;
  }

  /// Cartella in cui vengono conservati i modelli Vosk scaricati.
  ///
  /// Uso la cartella dati dell'applicazione e non quella dei documenti,
  /// cosi' i modelli (oltre 100 MiB) non finiscono tra i file dell'utente.
  Future<String> _modelStoragePath() async {
    final Directory supportDirectory = await getApplicationSupportDirectory();
    final String storagePath = p.join(supportDirectory.path, 'models');
    await Directory(storagePath).create(recursive: true);
    return storagePath;
  }

  /// Cambia la lingua del riconoscimento e ricarica il modello.
  Future<void> setLanguage(VoiceLanguage language) async {
    if (language == _language && _status == VoiceStatus.ready) return;
    _language = language;
    await settingsService.setVoiceLanguage(language.code);
    await _releaseRecognizer();
    _status = VoiceStatus.idle;
    notifyListeners();
    await prepare();
  }

  /// Avvia l'acquisizione dell'audio e il riconoscimento.
  Future<void> startListening() async {
    if (_status == VoiceStatus.listening) return;

    AppLogger.i(
      _tag,
      'Avvio ascolto: stato=${_status.name} '
      'modelloPronto=${_recognizer != null} '
      'microfono=${selectedDeviceId ?? 'predefinito'}',
    );

    if (_recognizer == null) {
      await prepare();
      if (_status != VoiceStatus.ready) return;
    }

    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission(request: true)) {
        await recorder.dispose();
        _fail(VoiceError.microphoneDenied);
        return;
      }

      final stream = await recorder.startStream(_buildRecordConfig());
      _recorder = recorder;
      _audioSubscription = stream.listen(
        _onAudioChunk,
        onError: (Object e) {
          AppLogger.w(_tag, 'Errore nella cattura audio', e);
        },
      );
      _startLevelMeter(recorder);

      _partialTranscript = '';
      _status = VoiceStatus.listening;
      _error = VoiceError.none;
      AppLogger.i(_tag, 'Ascolto avviato');
      notifyListeners();
    } on ProcessException catch (e) {
      await recorder.dispose();
      AppLogger.e(_tag, 'Avvio ascolto fallito', e);
      _fail(VoiceError.recorderUnavailable, details: e.message);
    } on Object catch (e) {
      await recorder.dispose();
      AppLogger.e(_tag, 'Avvio ascolto fallito', e);
      _fail(VoiceError.recorderUnavailable, details: e.toString());
    }
  }

  /// Ferma l'acquisizione e recupera l'ultimo risultato.
  Future<void> stopListening() async {
    if (_status != VoiceStatus.listening) return;

    _stopLevelMeter();
    await _audioSubscription?.cancel();
    _audioSubscription = null;

    AppLogger.i(
      _tag,
      'Livello massimo del microfono durante l\'ascolto: '
      '${_peakLevelDb.toStringAsFixed(0)} dB',
    );

    await _recorder?.dispose();
    _recorder = null;

    _status = VoiceStatus.ready;
    notifyListeners();
  }

  /// Svuota la cronologia dei comandi.
  void clearHistory() {
    _history.clear();
    notifyListeners();
  }

  /// Carica l'elenco dei microfoni disponibili.
  Future<void> loadInputDevices() async {
    _loadingDevices = true;
    notifyListeners();

    try {
      final AudioRecorder recorder = AudioRecorder();
      try {
        final List<InputDevice> devices = await recorder.listInputDevices();
        _inputDevices
          ..clear()
          ..addAll(
            devices.map(
              (InputDevice device) => InputDevice(
                id: normalizeDeviceId(device.id),
                label: device.label,
              ),
            ),
          );

        final String? stored = settingsService.voiceInputDevice;
        final String? normalizedStored = stored == null
            ? null
            : normalizeDeviceId(stored);
        final bool stillAvailable =
            normalizedStored != null &&
            _inputDevices.any((device) => device.id == normalizedStored);
        if (normalizedStored != null && !stillAvailable) {
          // Il microfono salvato non c'e' piu': si torna al predefinito.
          AppLogger.i(
            _tag,
            'Microfono salvato non piu\' disponibile: $normalizedStored',
          );
          await settingsService.setVoiceInputDevice(null);
          _selectedDeviceId = null;
        } else {
          _selectedDeviceId = normalizedStored;
        }
      } finally {
        await recorder.dispose();
      }
    } on Object catch (e) {
      AppLogger.w(_tag, 'Elenco dei microfoni non disponibile', e);
      _inputDevices.clear();
      _selectedDeviceId = null;
    }

    _loadingDevices = false;
    notifyListeners();
  }

  /// Sceglie il microfono da usare, null per quello predefinito.
  Future<void> setInputDevice(String? deviceId) async {
    final String? normalized = deviceId == null
        ? null
        : normalizeDeviceId(deviceId);
    if (_selectedDeviceId == normalized) return;

    _selectedDeviceId = normalized;
    await settingsService.setVoiceInputDevice(normalized);
    notifyListeners();

    // Se l'ascolto e' in corso si riparte con il nuovo microfono.
    if (_status == VoiceStatus.listening) {
      await stopListening();
      await startListening();
    }
  }

  /// Toglie le virgolette dagli id dei microfoni.
  ///
  /// Il backend PulseAudio restituisce i valori tra virgolette
  /// (node.name = "alsa_input..."): senza pulirli l'id non combacia con
  /// quello salvato e la scelta del microfono viene persa.
  static String normalizeDeviceId(String id) {
    final String value = id.trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  RecordConfig _buildRecordConfig() {
    final String? deviceId = selectedDeviceId;
    if (deviceId == null) return _recordConfig;

    for (final InputDevice device in _inputDevices) {
      if (device.id == deviceId) {
        return RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
          device: device,
        );
      }
    }
    return _recordConfig;
  }

  /// Avvia il monitoraggio del livello del microfono.
  void _startLevelMeter(AudioRecorder recorder) {
    _levelTimer?.cancel();
    _peakLevelDb = -160;
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (_disposed) return;
      try {
        final Amplitude amplitude = await recorder.getAmplitude();
        if (_disposed) return;
        inputLevel.value = amplitude.current;
        if (amplitude.current > _peakLevelDb) {
          _peakLevelDb = amplitude.current;
        }
      } on Object catch (e) {
        AppLogger.w(_tag, 'Errore nella lettura del livello audio', e);
      }
    });
  }

  /// Ferma il monitoraggio del livello del microfono.
  void _stopLevelMeter() {
    _levelTimer?.cancel();
    _levelTimer = null;
    inputLevel.value = -160;
  }

  void _onAudioChunk(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _audioChain = _audioChain.then((_) => _processChunk(bytes)).catchError((
      Object e,
    ) {
      AppLogger.w(_tag, 'Errore nel riconoscimento vocale', e);
    });
  }

  Future<void> _processChunk(Uint8List bytes) async {
    final recognizer = _recognizer;
    if (recognizer == null) return;

    final bool isFinal = await recognizer.acceptWaveformBytes(bytes);
    if (isFinal) {
      final text = _extractText(await recognizer.getResult());
      if (text.isNotEmpty) await _handleTranscript(text);
      if (_partialTranscript.isNotEmpty) {
        _partialTranscript = '';
        notifyListeners();
      }
      return;
    }

    final partial = _extractText(await recognizer.getPartialResult());
    if (partial != _partialTranscript) {
      _partialTranscript = partial;
      notifyListeners();
    }
  }

  String _extractText(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final text = decoded['text'] ?? decoded['partial'];
        if (text is String) return text.trim();
      }
    } on Object catch (_) {
      // Risposta non interpretabile: la si ignora.
    }
    return '';
  }

  /// Analizza una frase e la esegue.
  ///
  /// Esposto per i test: il percorso normale arriva dalla trascrizione del
  /// riconoscitore, che e' difficile da riprodurre senza il motore nativo.
  @visibleForTesting
  Future<void> handleTranscript(String text) => _handleTranscript(text);

  Future<void> _handleTranscript(String text) async {
    final command = VoiceCommandParser.parse(text, language: _language);

    final entry = VoiceLogEntry(
      transcript: text,
      feedback: command == null
          ? VoiceFeedback.notRecognized
          : _feedbackFor(command.type),
      timestamp: DateTime.now(),
      command: command,
      number: command?.number,
    );

    _history.insert(0, entry);
    if (_history.length > maxHistory) _history.removeLast();
    notifyListeners();

    if (command == null) return;
    await _execute(command, entry);
    notifyListeners();
  }

  Future<void> _execute(VoiceCommand command, VoiceLogEntry entry) async {
    final bool succeeded = await executor.execute(command);
    if (succeeded) return;

    entry.succeeded = false;
    entry.feedback = VoiceFeedback.notExecuted;
  }

  VoiceFeedback _feedbackFor(VoiceCommandType type) {
    switch (type) {
      case VoiceCommandType.playlistRandom:
        return VoiceFeedback.playlistRandom;
      case VoiceCommandType.playlistRecent:
        return VoiceFeedback.playlistRecent;
      case VoiceCommandType.playlistPlay:
        return VoiceFeedback.playlistPlay;
      case VoiceCommandType.playerStop:
        return VoiceFeedback.stopped;
      case VoiceCommandType.vlcPause:
        return VoiceFeedback.paused;
      case VoiceCommandType.vlcResume:
        return VoiceFeedback.resumed;
      case VoiceCommandType.vlcNext:
        return VoiceFeedback.next;
      case VoiceCommandType.vlcPrevious:
        return VoiceFeedback.previous;
      case VoiceCommandType.vlcVolumeUp:
        return VoiceFeedback.volumeUp;
      case VoiceCommandType.vlcVolumeDown:
        return VoiceFeedback.volumeDown;
      case VoiceCommandType.vlcVolumeSet:
        return VoiceFeedback.volumeSet;
      case VoiceCommandType.vlcSeekForward:
        return VoiceFeedback.seekForward;
      case VoiceCommandType.vlcSeekBackward:
        return VoiceFeedback.seekBackward;
    }
  }

  void _fail(VoiceError error, {String? details}) {
    _status = VoiceStatus.error;
    _error = error;
    _errorDetails = details;
    notifyListeners();
  }

  Future<void> _releaseRecognizer() async {
    final recognizer = _recognizer;
    _recognizer = null;
    if (recognizer != null) {
      try {
        await recognizer.dispose();
      } on Object catch (e) {
        AppLogger.w(_tag, 'Errore nella chiusura del riconoscitore', e);
      }
    }

    final model = _model;
    _model = null;
    model?.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopLevelMeter();
    inputLevel.dispose();
    _audioSubscription?.cancel();
    _recorder?.dispose();
    _releaseRecognizer();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
