import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../models/vlc_status.dart';
import '../models/playlist_item.dart';

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
  final Duration _playlistQuietPeriod = Duration(milliseconds: 500);

  // Simple mutex to synchronize command execution
  Future<void>? _activeCommand;

  // Cache for durations to avoid flickering
  final Map<String, int> _durationCache = {};

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
            _lastChunkTime = now;

            // Append raw incoming data to internal buffer for commands that
            // need the entire multi-chunk response (eg. playlist)
            _incomingBuffer.write(response);

            // Debug: print a concise representation of the chunk with timestamp
            final display = response
                .replaceAll('\r', '<CR>')
                .replaceAll('\n', '<LF>')
                .replaceAll('\t', '<TAB>');
            print(
              '[VlcService] [${now.toIso8601String()}] Chunk(${data.length} bytes): $display',
            );

            final trimmed = response.trim();
            if (trimmed.isNotEmpty) {
              _responseController.add(response);
            }
          } catch (e) {
            print('[VlcService] Errore decodifica dati socket: $e');
          }
        },
        onError: (error) {
          print('Errore socket: $error');
          _isConnected = false;
        },
        onDone: () {
          print('Connessione chiusa');
          _isConnected = false;
        },
      );

      return true;
    } catch (e) {
      print('Errore connessione a VLC: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Disconnette dal server VLC
  Future<void> disconnect() async {
    try {
      _isConnected = false;

      // Cancella subscription
      try {
        await _socketSubscription?.cancel();
      } catch (e) {
        print('[VlcService] Errore cancellazione subscription: $e');
      }
      _socketSubscription = null;

      // Chiudi socket
      try {
        await _socket?.close();
      } catch (e) {
        print('[VlcService] Errore chiusura socket: $e');
      }
      _socket = null;

      _currentHost = null;
      _currentPort = null;
    } catch (e) {
      print('[VlcService] Errore durante la disconnessione: $e');
    }
  }

  /// Invia un comando a VLC in modo sincronizzato
  Future<bool> sendCommand(String command) async {
    return _enqueueCommand(() async {
      if (!_isConnected || _socket == null) {
        print('Non connesso a VLC');
        return false;
      }

      try {
        _socket!.write('$command\n');
        await _socket!.flush();
        return true;
      } catch (e) {
        print('Errore invio comando: $e');
        return false;
      }
    });
  }

  /// Esegue un'azione in modo mutuo-esclusivo
  Future<T> _enqueueCommand<T>(Future<T> Function() action) async {
    final previous = _activeCommand;
    final completer = Completer<void>();
    _activeCommand = completer.future;

    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }

    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  /// Invia un comando e attende una risposta
  /// Invia un comando e attende una risposta in modo sincronizzato, filtrando echi e prompt
  Future<String?> sendCommandAndRead(
    String command, {
    int timeoutMs = 1500,
  }) async {
    return _enqueueCommand(() async {
      if (!_isConnected || _socket == null) {
        return null;
      }

      try {
        final completer = Completer<String?>();
        StreamSubscription? subscription;

        // Puliamo il buffer prima di iniziare per evitare rimasugli
        // (Nota: cautela con la playlist, ma per i meta-comandi è necessario)
        if (!command.contains('playlist')) {
          _incomingBuffer.clear();
        }

        subscription = responseStream.listen((line) {
          final trimmed = line.trim();
          // Ignoriamo l'echo del comando, il prompt '>', o righe vuote
          if (trimmed == command.trim() || 
              trimmed == '>' || 
              trimmed.startsWith('> $command') ||
              trimmed == 'Unknown command `$command\'. Type `help\' for help.') {
            return;
          }
          
          if (!completer.isCompleted) {
            completer.complete(line);
            subscription?.cancel();
          }
        });

        _socket!.write('$command\n');
        await _socket!.flush();

        final result = await completer.future.timeout(
          Duration(milliseconds: timeoutMs),
          onTimeout: () {
            subscription?.cancel();
            print('[VlcService] Timeout per comando: $command');
            return null;
          },
        );

        return result;
      } catch (e) {
        print('Errore durante sendCommandAndRead ($command): $e');
        return null;
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
  Future<bool> volumeUp([int amount = 3]) => sendCommand('volup $amount');

  /// Diminuisci volume
  Future<bool> volumeDown([int amount = 3]) => sendCommand('voldown $amount');

  /// Imposta volume assoluto (0-256)
  Future<bool> setVolume(int volume) => sendCommand('volume $volume');

  /// Toggle fullscreen
  Future<bool> fullscreen() => sendCommand('fullscreen');

  /// Vai a una posizione specifica nella playlist (1-based index)
  Future<bool> goto(int index) => sendCommand('goto $index');

  /// Vai a una posizione specifica (in secondi)
  Future<bool> seek(int seconds) => sendCommand('seek $seconds');

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

  /// Ottiene il volume corrente (0-256, ma VLC usa tipicamente 0-100)
  Future<int?> getVolume() async {
    final response = await sendCommandAndRead('volume');
    if (response == null) return null;
    final vol = _parseFirstInteger(response);
    if (vol != null) {
      // VLC RC 'volume' command returns the 0-512 (0-200%) or 0-256 (0-100%) value.
      // 256 is exactly 100% in VLC.
      return (vol * 100 / 256).round();
    }
    return null;
  }

  int? _parseFirstInteger(String content) {
    final match = RegExp(r'(\d+)').firstMatch(content);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  /// Ottiene lo stato completo di VLC combinando più fonti per massimizzare l'accuratezza
  Future<VlcStatus> getStatus() async {
    try {
      // Nota: getTitle, getTime, etc. usano già sendCommandAndRead che è sincronizzato.
      // Invocandoli in sequenza qui, garantiamo che ogni risposta sia quella giusta.
      
      final title = await getTitle();
      
      // Fallback robusto per il tempo: proviamo prima 'status', poi 'get_time'
      int? time;
      int? length;
      int? rawVolume;
      String state = 'stopped';
      
      final statusResp = await sendCommandAndRead('status');
      if (statusResp != null) {
        final itemRegex = RegExp(r'\( ([^:]+): (.*?) \)');
        for (final match in itemRegex.allMatches(statusResp)) {
          final key = match.group(1)?.trim();
          final value = match.group(2)?.trim();
          if (key == 'time') time = int.tryParse(value ?? '');
          if (key == 'length') length = int.tryParse(value ?? '');
          if (key == 'state') state = value ?? 'stopped';
          if (key == 'audio volume' || key == 'volume') rawVolume = int.tryParse(value ?? '');
        }
      }
      
      // Se mancano dati critici, usiamo i comandi diretti (più affidabili in alcune build di VLC)
      if (time == null || time == 0) {
        time = await getTime();
      }
      if (length == null || length == 0) {
        length = await getLength();
      }
      if (rawVolume == null) {
        rawVolume = await _getVolumeRaw();
      }
      
      int? volumePercent;
      if (rawVolume != null) {
        volumePercent = (rawVolume * 100.0 / 256.0).round().clamp(0, 100);
      }

      return VlcStatus(
        nowPlaying: title ?? 'Nessun video in riproduzione',
        currentTime: time ?? 0,
        totalTime: length ?? 0,
        volume: volumePercent,
        isPlaying: state == 'playing' || (time != null && time > 0),
      );
    } catch (e) {
      print('[VlcService] Errore critico in getStatus: $e');
      return VlcStatus();
    }
  }

  /// Helper per ottenere il valore grezzo del volume (0-256+)
  Future<int?> _getVolumeRaw() async {
    final response = await sendCommandAndRead('volume');
    if (response == null) return null;
    return _parseFirstInteger(response);
  }

  /// Ottiene la playlist corrente
  Future<List<PlaylistItem>> getPlaylist() async {
    try {
      final playlistItems = <PlaylistItem>[];

      if (!_isConnected || _socket == null) {
        return [];
      }

      // Clear internal buffer and send command to collect full multi-chunk
      // response from VLC. We use the internal `_incomingBuffer` which is
      // appended by the socket listener.
      _incomingBuffer.clear();
      _lastChunkTime = null;

      _socket!.write('playlist\n');
      await _socket!.flush();

      // Wait until buffer contains end marker or a quiet period after the
      // last received chunk. This reduces races where chunks arrive shortly
      // after we inspect the buffer.
      final timeout = Duration(milliseconds: 5000);
      final start = DateTime.now();
      String responseText = '';
      while (DateTime.now().difference(start) < timeout) {
        final buffer = _incomingBuffer.toString();
        final now = DateTime.now();
        final hasEnd =
            buffer.contains('+----[ End of playlist ]') ||
            buffer.contains('End of playlist');

        // If we have an explicit end marker and we've had no new chunks for
        // the quiet period, consider the response complete.
        if (hasEnd &&
            _lastChunkTime != null &&
            now.difference(_lastChunkTime!) >= _playlistQuietPeriod) {
          responseText = buffer;
          break;
        }

        // If there has been no incoming data for a quiet period and buffer is
        // not empty, assume the server finished sending.
        if (_lastChunkTime != null &&
            now.difference(_lastChunkTime!) >= _playlistQuietPeriod &&
            buffer.isNotEmpty) {
          responseText = buffer;
          break;
        }

        // If no chunks have arrived yet, keep waiting up to timeout.
        await Future.delayed(Duration(milliseconds: 100));
      }

      print('[VlcService] RAW_BUFFER_LEN: ${_incomingBuffer.length}');
      print(
        '[VlcService] RAW: ${responseText.isEmpty ? _incomingBuffer.toString() : responseText}',
      );

      // Splitta per newline
      final lines = responseText.split('\n');

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

        // Rimuovi anno/info tra parentesi "(2025)"
        title = title.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

        // Normalizza spazi
        title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

        // Aggiungi solo se ha un ID valido e non è vuoto
        if (vlcId != null && 
            title.isNotEmpty &&
            !playlistItems.any((item) => item.id == vlcId)) { // Usa ID per unicità
          
          playlistItems.add(
            PlaylistItem(
              id: vlcId,
              index: index, 
              title: title, 
              duration: null,
              isPlaying: isPlaying,
            ),
          );
          print('[VlcService] Item[$index] ID:$vlcId Title:$title');
          index++;
        }
      }

      print('[VlcService] Playlist: ${playlistItems.length} items');
      return playlistItems;
    } catch (e) {
      print('[VlcService] Errore getPlaylist: $e');
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
