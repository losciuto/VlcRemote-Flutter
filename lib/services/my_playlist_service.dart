import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class MyPlaylistService {
  final AesGcm algorithm = AesGcm.with256bits();

  /// Invia un comando cifrato al server MyPlaylist e restituisce la risposta JSON
  Future<Map<String, dynamic>> sendCommand({
    required String host,
    required int port,
    required String secretKey,
    required String command,
    Map<String, dynamic>? args,
  }) async {
    Socket? socket;
    try {
      // 1. Preparazione della chiave (32 byte, padding con zero se necessario)
      final Uint8List keyBytes = Uint8List(32);
      final encodedKey = utf8.encode(secretKey);
      for (int i = 0; i < encodedKey.length && i < 32; i++) {
        keyBytes[i] = encodedKey[i];
      }
      final secretKeyHandle = SecretKey(keyBytes);

      // 2. Preparazione del messaggio JSON
      final payload = jsonEncode({
        'command': command,
        'args': args ?? {},
      });
      final cleartext = utf8.encode(payload);

      // 3. Generazione Nonce (12 byte)
      final nonce = algorithm.newNonce();

      // 4. Crittografia AES-GCM
      final secretBox = await algorithm.encrypt(
        cleartext,
        secretKey: secretKeyHandle,
        nonce: nonce,
      );

      // 5. Costruzione del pacchetto binario
      final packet = BytesBuilder();
      packet.add(secretBox.nonce);
      packet.add(secretBox.mac.bytes);
      packet.add(secretBox.cipherText);

      final buffer = packet.takeBytes();

      // 6. Invio tramite Socket TCP
      socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      
      // Invio della lunghezza del messaggio (4 byte) + il messaggio stesso
      final lengthHeader = Uint8List(4);
      ByteData.view(lengthHeader.buffer).setUint32(0, buffer.length);
      
      socket.add(lengthHeader);
      socket.add(buffer);
      await socket.flush();

      // 7. Lettura risposta (formato JSON)
      final responseCompleter = Completer<String>();
      socket.listen(
        (data) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(utf8.decode(data).trim());
          }
        },
        onError: (e) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(e);
          }
        },
        onDone: () {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError('Connection closed');
          }
        },
      );

      final rawResult = await responseCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      return jsonDecode(rawResult) as Map<String, dynamic>;
    } catch (e) {
      return {
        'status': 'error',
        'message': e.toString(),
      };
    } finally {
      socket?.destroy();
    }
  }

  // Comandi specifici con nuovi tipi di ritorno
  Future<Map<String, dynamic>> play(String host, int port, String key) =>
      sendCommand(host: host, port: port, secretKey: key, command: 'play');

  Future<Map<String, dynamic>> stop(String host, int port, String key) =>
      sendCommand(host: host, port: port, secretKey: key, command: 'stop');

  Future<Map<String, dynamic>> generateRandom(String host, int port, String key, {int? count, bool preview = false}) =>
      sendCommand(
        host: host,
        port: port,
        secretKey: key,
        command: 'generate_random',
        args: {'count': count, 'preview': preview},
      );

  Future<Map<String, dynamic>> generateRecent(String host, int port, String key, {int? count, bool preview = false}) =>
      sendCommand(
        host: host,
        port: port,
        secretKey: key,
        command: 'generate_recent',
        args: {'count': count, 'preview': preview},
      );

  Future<Map<String, dynamic>> generateFiltered(
    String host,
    int port,
    String key, {
    List<String>? genres,
    List<String>? years,
    double? minRating,
    List<String>? actors,
    List<String>? directors,
    int? limit,
    bool preview = false,
  }) =>
      sendCommand(
        host: host,
        port: port,
        secretKey: key,
        command: 'generate_filtered',
        args: {
          'genres': genres,
          'years': years,
          'min_rating': minRating,
          'actors': actors,
          'directors': directors,
          'limit': limit,
          'preview': preview,
        },
      );
}
