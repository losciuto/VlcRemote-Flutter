import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Comando decifrato, così com'è stato inviato dal client.
class ReceivedCommand {
  const ReceivedCommand(this.command, this.args, this.rawPacket);

  final String command;
  final Map<String, dynamic> args;

  /// Pacchetto così ricevuto dalla socket: 4 byte di lunghezza + payload.
  final Uint8List rawPacket;

  /// Payload cifrato (senza l'header di lunghezza).
  Uint8List get payload => Uint8List.sublistView(rawPacket, 4);
}

/// Server MyPlaylist finto.
///
/// Replica il lato server di MyPlaylist (`lib/services/remote_control_service.dart`)
/// per verificare che il client di VlcRemote parli davvero il protocollo del
/// server: header di 4 byte big-endian, AES-GCM 256 con
/// `nonce(12) || mac(16) || ciphertext`, chiave derivata con zero-padding a
/// 32 byte, risposta JSON grezza e chiusura della socket.
class FakeMyPlaylistServer {
  FakeMyPlaylistServer._(this._server, this._secretKey, this._responder);

  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int minPayloadLength = nonceLength + macLength;

  final ServerSocket _server;
  final String _secretKey;
  final Map<String, dynamic> Function(
    String command,
    Map<String, dynamic> args,
  )?
  _responder;
  final AesGcm _algorithm = AesGcm.with256bits();
  final List<Socket> _sockets = [];

  /// Comandi decifrati, nell'ordine di arrivo.
  final List<ReceivedCommand> receivedCommands = [];

  /// Errori incontrati leggendo o decifrando un pacchetto.
  final List<String> protocolErrors = [];

  /// Se il server chiude la socket dopo aver risposto.
  ///
  /// Il server vero chiude sempre, e i test di protocollo devono continuare a
  /// farlo. Per provare il caso in cui non chiude, questa opzione lo tiene
  /// aperto: e' il caso in cui il client non deve dipendere dalla chiusura.
  bool chiudeDopoRisposta = true;

  /// Le socket rimaste aperte, per non perderle alla chiusura del server.
  final List<Socket> _connessioni = [];

  static Future<FakeMyPlaylistServer> start(
    String secretKey, {
    Map<String, dynamic> Function(String command, Map<String, dynamic> args)?
    responder,
    bool chiudeDopoRisposta = true,
  }) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeMyPlaylistServer._(server, secretKey, responder);
    fake.chiudeDopoRisposta = chiudeDopoRisposta;
    server.listen(fake._handleSocket);
    return fake;
  }

  String get host => '127.0.0.1';

  int get port => _server.port;

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    for (final socket in _connessioni) {
      socket.destroy();
    }
    await _server.close();
  }

  Future<void> _handleSocket(Socket socket) async {
    _sockets.add(socket);
    final pending = <int>[];

    await for (final data in socket) {
      pending.addAll(data);

      // Servono 4 byte di header, poi il payload della lunghezza indicata.
      if (pending.length < 4) continue;
      final declared = ByteData.view(
        Uint8List.fromList(pending).buffer,
      ).getUint32(0);
      if (pending.length < 4 + declared) continue;

      final packet = Uint8List.fromList(pending.sublist(0, 4 + declared));
      pending.removeRange(0, 4 + declared);

      final payload = Uint8List.sublistView(packet, 4);

      // Invariante del server: sotto 28 byte il pacchetto è invalido.
      if (payload.length < minPayloadLength) {
        protocolErrors.add('payload troppo corto: ${payload.length} byte');
        _respond(socket, {'status': 'error', 'message': 'Message too short'});
        continue;
      }

      final nonce = Uint8List.sublistView(payload, 0, nonceLength);
      final mac = Uint8List.sublistView(
        payload,
        nonceLength,
        nonceLength + macLength,
      );
      final cipherText = Uint8List.sublistView(
        payload,
        nonceLength + macLength,
      );

      try {
        // Chiave: 32 byte con zero-padding, come fa il server.
        final keyBytes = Uint8List(32);
        final encodedKey = utf8.encode(_secretKey);
        for (var i = 0; i < encodedKey.length && i < 32; i++) {
          keyBytes[i] = encodedKey[i];
        }

        final cleartext = await _algorithm.decrypt(
          SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
          secretKey: SecretKey(keyBytes),
        );

        final decoded =
            jsonDecode(utf8.decode(cleartext)) as Map<String, dynamic>;
        final command = (decoded['command'] ?? '') as String;
        final args =
            (decoded['args'] ?? <String, dynamic>{}) as Map<String, dynamic>;

        receivedCommands.add(ReceivedCommand(command, args, packet));
        _respond(socket, _responder?.call(command, args) ?? defaultResponse());
      } catch (e) {
        protocolErrors.add('decifratura fallita: $e');
        _respond(socket, {'status': 'error', 'message': '$e'});
      }
    }
  }

  void _respond(Socket socket, Map<String, dynamic> body) {
    // Il server scrive il JSON e chiude la socket: niente header di lunghezza.
    socket.write(jsonEncode(body));
    if (chiudeDopoRisposta) {
      socket.close();
    } else {
      // Tiene la socket aperta, come se il server non chiudesse. Va tenuta
      // traccia, altrimenti verrebbe persa alla fine del test.
      _connessioni.add(socket);
    }
  }

  /// Risposta del server in caso di successo, con la forma prevista dal client.
  static Map<String, dynamic> defaultResponse({
    String command = 'generate_random',
    List<Map<String, dynamic>>? playlist,
  }) => {
    'status': 'success',
    'message': 'Playlist generata',
    'command': command,
    'playlist': playlist ?? <Map<String, dynamic>>[],
  };
}
