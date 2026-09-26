import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Risposta del server finto: una lista di chunk inviati in sequenza, con un
/// piccolo ritardo, per riprodurre le risposte spezzate su più chunk TCP.
typedef FakeVlcResponder = List<String> Function(String command);

/// Server RC finto che replica il comportamento della socket di VLC:
/// fa eco del comando ricevuto, poi invia i chunk della risposta.
///
/// Espone anche i comandi ricevuti, così i test possono verificare sia le
/// risposte lette dal client sia i valori effettivamente inviati a VLC.
class FakeVlcServer {
  FakeVlcServer._(this._server, this._responder);

  final ServerSocket _server;
  final FakeVlcResponder _responder;
  final List<Socket> _sockets = [];

  /// Comandi ricevuti dal client, nell'ordine in cui sono arrivati.
  final List<String> receivedCommands = [];

  static Future<FakeVlcServer> start(FakeVlcResponder responder) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeVlcServer._(server, responder);
    server.listen(fake._handleSocket);
    return fake;
  }

  String get host => '127.0.0.1';

  int get port => _server.port;

  /// Attende che il client invii [command], senza fallire se non arriva.
  Future<bool> waitForCommand(
    String command, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (receivedCommands.contains(command)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return false;
  }

  Future<void> close() async {
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close();
  }

  void _handleSocket(Socket socket) {
    _sockets.add(socket);
    final pending = StringBuffer();

    socket.listen(
      (data) {
        pending.write(utf8.decode(data));
        var text = pending.toString();

        while (text.contains('\n')) {
          final index = text.indexOf('\n');
          final line = text.substring(0, index).trim();
          text = text.substring(index + 1);
          pending
            ..clear()
            ..write(text);

          if (line.isEmpty) continue;

          receivedCommands.add(line);
          // VLC RC fa eco del comando ricevuto prima della risposta.
          socket.write('$line\n');
          unawaited(_sendChunks(socket, _responder(line)));
        }
      },
      onError: (Object _) {},
      cancelOnError: true,
    );
  }

  Future<void> _sendChunks(Socket socket, List<String> chunks) async {
    for (final chunk in chunks) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      socket.write(chunk);
    }
  }
}
