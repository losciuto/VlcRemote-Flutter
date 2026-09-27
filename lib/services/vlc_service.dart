import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../constants/app_constants.dart';
import '../exceptions/vlc_exceptions.dart';
import '../models/vlc_status.dart';
import '../models/playlist_item.dart';
import '../utils/app_logger.dart';

/// Servizio per comunicare con VLC tramite interfaccia RC (Remote Control) via socket TCP
///
/// Questo servizio gestisce la connessione socket TCP con VLC e permette di:
/// - Connettersi e disconnettersi dal server VLC
/// - Inviare comandi di controllo (play, pause, stop, seek, volume, etc.)
/// - Ricevere e parsare lo stato corrente di VLC
/// - Gestire la playlist
class VlcService {
  Socket? _socket;
  StreamSubscription? _socketSubscription;
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  final StringBuffer _incomingBuffer = StringBuffer();
  DateTime? _lastChunkTime;

  /// Vero se nel flusso ricevuto e' comparso il marcatore di fine playlist.
  ///
  /// Il controllo lo fa il listener del socket, che vede i dati appena arrivati:
  /// cosi' l'attesa in [_getPlaylist] non deve ricostruire il buffer a ogni
  /// giro per cercarci dentro il marcatore.
  bool _endMarkerSeen = false;

  /// Tag usato nei log di questo servizio.
  static const String _tag = 'VlcService';

  final Duration _playlistQuietPeriod = Duration(milliseconds: 500);

  // VLC può spezzare una risposta su più chunk TCP. Consideriamo la risposta
  // completa solo dopo un breve silenzio, così non leggiamo mezza riga.
  final Duration _chunkQuietPeriod = Duration(milliseconds: 100);

  // Simple mutex to synchronize command execution
  Future<void>? _activeCommand;

  String? _currentHost;
  int? _currentPort;
  bool _isConnected = false;

  final int _timeout = 2000; // timeout in millisecondi

  /// Stream delle risposte ricevute da VLC
  Stream<String> get responseStream => _responseController.stream;

  /// Verifica se è connesso a VLC
  bool get isConnected => _isConnected;

  /// Host corrente
  String? get currentHost => _currentHost;

  /// Porta corrente
  int? get currentPort => _currentPort;

  /// Connette al server VLC
  Future<bool> connect(String host, int port) async {
    try {
      // Disconnetti se già connesso
      await disconnect();

      // Crea la connessione socket
      _socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: _timeout),
      );
      _currentHost = host;
      _currentPort = port;
      _isConnected = true;

      // Ascolta le risposte dal socket
      _socketSubscription = _socket!.listen(
        (data) {
          try {
            final response = utf8.decode(data);
            final now = DateTime.now();
            _lastChunkTime ??= now;

            // Append raw incoming data to internal buffer for commands that
            // need the entire multi-chunk response (eg. playlist)
            _incomingBuffer.write(response);

            // Il marcatore di fine playlist viene notato qui, sul chunk: farlo
            // in attesa richiederebbe di copiare il buffer a ogni giro.
            if (response.contains('End of playlist')) {
              _endMarkerSeen = true;
            }

            // Traccia del chunk, a scopo diagnostico.
            //
            // Questo e' un percorso caldo: il listener scrive a ogni chunk
            // ricevuto, e la trasformazione del testo qui sotto (tre replaceAll
            // sul contenuto) costa piu' della lettura dal socket. Per questo
            // sta dietro a un controllo esplicito: con il solo controllo interno
            // al logger la stringa verrebbe comunque costruita a ogni chunk.
            if (AppLogger.isDebugEnabled) {
              final display = response
                  .replaceAll('\r', '<CR>')
                  .replaceAll('\n', '<LF>')
                  .replaceAll('\t', '<TAB>');
              AppLogger.d(
                _tag,
                '[${now.toIso8601String()}] Chunk(${data.length} bytes): $display',
              );
            }

            final trimmed = response.trim();
            if (trimmed.isNotEmpty) {
              _responseController.add(response);
            }
          } catch (e) {
            AppLogger.w(_tag, 'Errore decodifica dati socket', e);
          }
        },
        onError: (error) {
          AppLogger.w(_tag, 'Errore socket', error);
          _isConnected = false;
        },
        onDone: () {
          AppLogger.i(_tag, 'Connessione chiusa');
          _isConnected = false;
        },
      );

      return true;
    } catch (e) {
      AppLogger.w(_tag, 'Errore connessione a VLC', e);
      _isConnected = false;
      return false;
    }
  }

  /// Disconnette dal server VLC
  Future<void> disconnect() async {
    try {
      _isConnected = false;

      // Cancella la sottoscrizione allo stream del socket
      if (_socketSubscription != null) {
        try {
          await _socketSubscription!.cancel();
        } catch (e) {
          AppLogger.w(
            _tag,
            'Errore durante la cancellazione della sottoscrizione',
            e,
          );
        }
        _socketSubscription = null;
      }

      // Chiudi e distruggi il socket
      if (_socket != null) {
        try {
          // destroy() è più aggressivo di close() e assicura la chiusura immediata
          _socket!.destroy();
        } catch (e) {
          AppLogger.w(_tag, 'Errore durante la distruzione del socket', e);
        }
        _socket = null;
      }

      _currentHost = null;
      _currentPort = null;
      AppLogger.i(_tag, 'Disconnesso con successo.');
    } catch (e) {
      AppLogger.w(_tag, 'Errore critico durante la disconnessione', e);
    }
  }

  /// Invia un comando a VLC in modo sincronizzato
  Future<bool> sendCommand(String command) async {
    return _enqueueCommand(() async {
      if (!_isConnected || _socket == null) {
        AppLogger.i(_tag, 'Non connesso a VLC');
        return false;
      }

      try {
        _socket!.write('$command\n');
        await _socket!.flush();
        return true;
      } catch (e) {
        AppLogger.w(_tag, 'Errore invio comando', e);
        return false;
      }
    });
  }

  /// Esegue un'azione in modo mutuo-esclusivo
  ///
  /// Nota: le azioni in coda non devono mai fallire. Se il precedente comando
  /// è stato completato con errore, l'attesa non deve propagarlo: ogni
  /// implementazione gestisce già i propri errori e restituisce un fallback.
  Future<T> _enqueueCommand<T>(Future<T> Function() action) async {
    final previous = _activeCommand;
    final completer = Completer<void>();
    _activeCommand = completer.future;

    if (previous != null) {
      try {
        await previous;
      } catch (e) {
        AppLogger.w(_tag, 'Comando in coda terminato con errore', e);
      }
    }

    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  /// Vero se la riga ricevuta è un eco del comando, il prompt '>' o un vuoto
  bool _isEchoOrPrompt(String line, String command) {
    final cmd = command.trim();
    return line.isEmpty ||
        line == '>' ||
        line == cmd ||
        line == '> $cmd' ||
        line == 'Unknown command `$cmd\'. Type `help\' for help.';
  }

  /// Rimuove dalla risposta le righe iniziali che sono solo eco del comando
  String _stripCommandEcho(String response, String command) {
    final lines = response.split('\n');
    final cmd = command.trim();
    var start = 0;
    while (start < lines.length) {
      final line = lines[start].trim();
      if (line.isEmpty || line == '>' || line == cmd || line == '> $cmd') {
        start++;
      } else {
        break;
      }
    }
    return lines.sublist(start).join('\n').trim();
  }

  /// Invia un comando e attende la risposta completa
  ///
  /// I chunk arrivati vengono accumulati e la risposta viene considerata
  /// completa solo dopo [_chunkQuietPeriod] di silenzio, così una risposta
  /// spezzata su più chunk non viene letta a metà.
  Future<String?> sendCommandAndRead(
    String command, {
    int timeoutMs = 1500,
  }) async {
    return _enqueueCommand(() async {
      if (!_isConnected || _socket == null) {
        return null;
      }

      StreamSubscription<String>? subscription;
      Timer? quietTimer;

      try {
        final completer = Completer<String?>();
        final responseBuffer = StringBuffer();

        // Puliamo il buffer prima di iniziare per evitare rimasugli
        // (Nota: cautela con la playlist, ma per i meta-comandi è necessario)
        if (!command.contains('playlist')) {
          _incomingBuffer.clear();
        }

        subscription = responseStream.listen((chunk) {
          final trimmed = chunk.trim();
          // Ignoriamo l'echo del comando, il prompt '>' o le risposte di errore
          if (_isEchoOrPrompt(trimmed, command)) {
            return;
          }

          responseBuffer.write(chunk);

          // Riazzera il silenzio: la risposta è completa solo quando i chunk
          // smettono di arrivare.
          quietTimer?.cancel();
          quietTimer = Timer(_chunkQuietPeriod, () {
            if (!completer.isCompleted) {
              completer.complete(responseBuffer.toString());
            }
          });
        });

        _socket!.write('$command\n');
        await _socket!.flush();

        final result = await completer.future.timeout(
          Duration(milliseconds: timeoutMs),
          onTimeout: () {
            AppLogger.w(_tag, 'Timeout per comando: $command');
            return null;
          },
        );

        return result == null ? null : _stripCommandEcho(result, command);
      } catch (e) {
        AppLogger.w(_tag, 'Errore durante sendCommandAndRead ($command)', e);
        return null;
      } finally {
        quietTimer?.cancel();
        await subscription?.cancel();
      }
    });
  }

  // ==================== COMANDI DI CONTROLLO ====================

  /// Play
  Future<bool> play() => sendCommand('play');

  /// Pause
  Future<bool> pause() => sendCommand('pause');

  /// Stop
  Future<bool> stop() => sendCommand('stop');

  /// Traccia precedente
  Future<bool> previous() => sendCommand('prev');

  /// Traccia successiva
  Future<bool> next() => sendCommand('next');

  /// Aumenta volume
  Future<bool> volumeUp([int amount = AppConstants.volumeStepSize]) =>
      sendCommand('volup ${amount < 1 ? 1 : amount}');

  /// Diminuisci volume
  Future<bool> volumeDown([int amount = AppConstants.volumeStepSize]) =>
      sendCommand('voldown ${amount < 1 ? 1 : amount}');

  /// Imposta volume assoluto (0-256)
  Future<bool> setVolume(int volume) =>
      sendCommand('volume ${volume.clamp(0, AppConstants.vlcVolumeMax)}');

  /// Toggle fullscreen
  Future<bool> fullscreen() => sendCommand('fullscreen');

  /// Vai a una posizione specifica nella playlist (1-based index)
  Future<bool> goto(int index) => sendCommand('goto ${index < 1 ? 1 : index}');

  /// Vai a una posizione specifica (in secondi)
  Future<bool> seek(int seconds) =>
      sendCommand('seek ${seconds < 0 ? 0 : seconds}');

  // ==================== QUERY STATO ====================

  /// Ottiene il titolo corrente
  Future<String?> getTitle() async {
    final response = await sendCommandAndRead('get_title');
    return response?.trim();
  }

  /// Ottiene il tempo corrente (in secondi)
  Future<int?> getTime() async {
    final response = await sendCommandAndRead('get_time');
    if (response == null) return null;
    return _parseFirstInteger(response);
  }

  /// Ottiene la lunghezza totale (in secondi)
  Future<int?> getLength() async {
    final response = await sendCommandAndRead('get_length');
    if (response == null) return null;
    return _parseFirstInteger(response);
  }

  int? _parseFirstInteger(String content) {
    final match = RegExp(r'(\d+)').firstMatch(content);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Ottiene lo stato completo di VLC combinando più fonti per massimizzare l'accuratezza
  ///
  /// **Propaga l'errore** quando VLC non risponde: prima l'eccezione veniva
  /// stampata e sostituita con uno stato vuoto, quindi il retry e la
  /// riconnessione automatica del provider non scattavano mai.
  Future<VlcStatus?> getStatus() async {
    if (!_isConnected) {
      throw VlcConnectionException(
        _currentHost ?? '?',
        _currentPort ?? 0,
        'non connesso',
      );
    }

    // Nota: getTitle, getTime, etc. usano già sendCommandAndRead che è sincronizzato.
    // Invocandoli in sequenza qui, garantiamo che ogni risposta sia quella giusta.

    final title = await getTitle();

    // Fallback robusto per il tempo: proviamo prima 'status', poi 'get_time'
    int? time;
    int? length;
    int? rawVolume;
    String? parsedState;

    final statusResp = await sendCommandAndRead('status');
    if (statusResp != null) {
      final itemRegex = RegExp(r'\( ([^:]+): (.*?) \)');
      for (final match in itemRegex.allMatches(statusResp)) {
        final key = match.group(1)?.trim();
        final value = match.group(2)?.trim();
        if (key == 'time') time = int.tryParse(value ?? '');
        if (key == 'length') length = int.tryParse(value ?? '');
        if (key == 'state') parsedState = value;
        if (key == 'audio volume' || key == 'volume') {
          rawVolume = int.tryParse(value ?? '');
        }
      }
    }

    // Se mancano dati critici, usiamo i comandi diretti (più affidabili in alcune build di VLC)
    if (time == null || time == 0) {
      time = await getTime();
    }
    length ??= await getLength();
    rawVolume ??= await _getVolumeRaw();

    // VLC non ha risposto a nessun comando: il collegamento non è più valido.
    if (title == null && time == null && length == null && rawVolume == null) {
      throw VlcTimeoutException(
        Duration(milliseconds: AppConstants.commandTimeoutMs),
        'nessuna risposta da VLC',
      );
    }

    int? volumePercent;
    if (rawVolume != null) {
      volumePercent = (rawVolume * 100.0 / 256.0).round().clamp(0, 100);
    }

    // 'status' riporta lo stato solo se un media e' caricato. Quando la riga
    // c'e' e' fonte autorevole: usarla evita di dichiarare 'in riproduzione'
    // un video in pausa (che ha time > 0). Solo se manca ricadiamo sul tempo.
    final isPlaying = parsedState != null
        ? parsedState == 'playing'
        : (time ?? 0) > 0;

    return VlcStatus(
      nowPlaying: (title == null || title.isEmpty)
          ? 'Nessun video in riproduzione'
          : title,
      currentTime: time ?? 0,
      totalTime: length ?? 0,
      volume: volumePercent,
      isPlaying: isPlaying,
    );
  }

  /// Helper per ottenere il valore grezzo del volume (0-256+)
  Future<int?> _getVolumeRaw() async {
    final response = await sendCommandAndRead('volume');
    if (response == null) return null;
    return _parseFirstInteger(response);
  }

  /// Ottiene la playlist corrente
  ///
  /// Va eseguita in mutua esclusione come gli altri comandi: scrive sulla stessa
  /// socket e usa lo stesso buffer di `sendCommandAndRead`, quindi lanciarla in
  /// parallelo al polling dello stato faceva sovrascrivere le risposte.
  ///
  /// Lancia [VlcConnectionException] se non c'è la socket: una playlist
  /// realmente vuota e un collegamento perso restituivano entrambe `[]`,
  /// rendendo impossibile distinguere i due casi.
  Future<List<PlaylistItem>> getPlaylist() async {
    return _enqueueCommand(() => _getPlaylist());
  }

  Future<List<PlaylistItem>> _getPlaylist() async {
    try {
      final playlistItems = <PlaylistItem>[];

      if (!_isConnected || _socket == null) {
        throw VlcConnectionException(
          _currentHost ?? '?',
          _currentPort ?? 0,
          'nessuna socket attiva',
        );
      }

      // Clear internal buffer and send command to collect full multi-chunk
      // response from VLC. We use the internal `_incomingBuffer` which is
      // appended by the socket listener.
      _incomingBuffer.clear();
      _lastChunkTime = null;
      _endMarkerSeen = false;

      _socket!.write('playlist\n');
      await _socket!.flush();

      // Attende la fine della risposta: marcatore esplicito, oppure silenzio
      // dopo l'ultimo chunk. Questo riduce le gare in cui i chunk arrivano poco
      // dopo che abbiamo guardato il buffer.
      //
      // Il ciclo confronta solo orari e un booleano, e non ricostruisce il
      // buffer: farlo a ogni giro copiava l'intera playlist una volta al
      // secondo per cinque secondi, sul main isolate, e con una playlist
      // grande il costo cresceva con il quadrato della dimensione.
      final timeout = Duration(milliseconds: 5000);
      final start = DateTime.now();
      String responseText = '';
      while (DateTime.now().difference(start) < timeout) {
        final now = DateTime.now();
        final quiet =
            _lastChunkTime != null &&
            now.difference(_lastChunkTime!) >= _playlistQuietPeriod;

        // Marcatore di fine esplicito e silenzio: la risposta e' completa.
        if (_endMarkerSeen && quiet) break;

        // Silenzio con buffer non vuoto: il server ha finito di inviare.
        if (quiet && _incomingBuffer.isNotEmpty) break;

        // Se non e' arrivato ancora nulla, si aspetta fino al timeout.
        await Future.delayed(Duration(milliseconds: 100));
      }

      // Il buffer viene materializzato una volta sola, alla fine.
      responseText = _incomingBuffer.toString();

      AppLogger.d(_tag, 'RAW_BUFFER_LEN: ${_incomingBuffer.length}');
      AppLogger.d(
        _tag,
        'RAW: ${responseText.isEmpty ? _incomingBuffer.toString() : responseText}',
      );

      // Splitta per newline
      final lines = responseText.split('\n');

      // ID gia' presi nella playlist, per scartare i duplicati.
      final seenIds = <int>{};

      int index = 0;
      for (final line in lines) {
        final trimmed = line.trim();

        // Salta linee vuote, prompt, intestazioni
        if (trimmed.isEmpty ||
            trimmed == '>' ||
            trimmed.startsWith('>') ||
            trimmed.startsWith('+') ||
            trimmed.contains('Playlist') ||
            trimmed.contains('Scaletta') ||
            trimmed.contains('Raccolta multimediale') ||
            trimmed.contains('index')) {
          continue;
        }

        // Salta righe con solo numeri (ID VLC)
        if (RegExp(r'^\d+$').hasMatch(trimmed)) {
          continue;
        }

        // Estrai l'ID
        // Formato tipico: "| 4 - Titolo" oppure "4 - Titolo"
        int? vlcId;
        String title = trimmed;
        bool isPlaying = false;

        // Rimuovi caratteri struttura albero se presenti
        if (title.startsWith('|')) {
          title = title.replaceAll('|', '').trim();
        }

        // Rimuovi indicatore di riproduzione corrente (*)
        if (title.startsWith('*')) {
          title = title.replaceFirst('*', '').trim();
          isPlaying = true;
        }

        // Cerca pattern "ID - Titolo"
        // Esempio: "4 - Titolo del video"
        final idMatch = RegExp(r'^(\d+)\s*-\s*(.+)').firstMatch(title);
        if (idMatch != null) {
          vlcId = int.tryParse(idMatch.group(1)!);
          title = idMatch.group(2)!.trim();
        }
        // Fallback: cerca solo ID all'inizio se seguito da spazio
        else {
          final simpleIdMatch = RegExp(r'^(\d+)\s+(.+)').firstMatch(title);
          if (simpleIdMatch != null) {
            vlcId = int.tryParse(simpleIdMatch.group(1)!);
            title = simpleIdMatch.group(2)!.trim();
          }
        }

        // Se non abbiamo trovato ID, proviamo a vedere se la riga inizia con un numero
        // ma attenzione a non prendere l'anno "(2025)" come ID se è all'inizio per sbaglio
        if (vlcId == null) {
          final startNumMatch = RegExp(r'^(\d+)').firstMatch(title);
          if (startNumMatch != null) {
            vlcId = int.tryParse(startNumMatch.group(1)!);
            // Rimuoviamo l'ID dalla stringa
            title = title.substring(startNumMatch.end).trim();
            // Rimuoviamo eventuali trattini o punti rimasti
            title = title.replaceFirst(RegExp(r'^[\.\-]\s*'), '').trim();
          }
        }

        // Rimuovi solo l'anno tra parentesi in fondo al titolo.
        // Le altre parentesi fanno parte del nome del file
        // (es. "Movie (Director's Cut)") e vanno conservate.
        title = title
            .replaceFirst(RegExp(r'\s*\((?:19|20)\d{2}\)\s*$'), '')
            .trim();

        // Normalizza spazi
        title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Aggiungi solo se ha un ID valido e non è vuoto
        if (vlcId != null && title.isNotEmpty && !seenIds.contains(vlcId)) {
          // L'unicita' e' per ID: `_seenIds` risponde in tempo costante, mentre
          // un `any` sulla lista rileggerebbe tutti gli elementi gia' raccolti
          // a ogni riga, e il costo cresceva con il quadrato della dimensione.
          seenIds.add(vlcId);

          playlistItems.add(
            PlaylistItem(
              id: vlcId,
              index: index,
              title: title,
              duration: null,
              isPlaying: isPlaying,
            ),
          );
          // Una riga per voce: su una playlist grande il costo di queste
          // righe supera di gran lunga il lavoro di lettura che le genera.
          if (AppLogger.isDebugEnabled) {
            AppLogger.d(_tag, 'Item[$index] ID:$vlcId Title:$title');
          }
          index++;
        }
      }

      AppLogger.i(_tag, 'Playlist: ${playlistItems.length} items');
      return playlistItems;
    } on VlcRemoteException {
      // Le eccezioni tipizzate servono a distinguere 'collegamento perso' da
      // 'playlist vuota': le propaghiamo invece di trasformarle in [].
      rethrow;
    } catch (e) {
      AppLogger.w(_tag, 'Errore getPlaylist', e);
      return [];
    }
  }

  /// Pulisce le risorse
  void dispose() {
    _socketSubscription?.cancel();
    _socket?.close();
    _responseController.close();
    _isConnected = false;
  }
}
