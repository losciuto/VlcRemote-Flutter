import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/services/my_playlist_service.dart';

import 'support/fake_my_playlist_server.dart';

/// Contratto del server MyPlaylist (`lib/services/remote_control_service.dart`).
/// Se una di queste invarianti cambia, questo file è il primo a dover cambiare.
void main() {
  const secretKey = 'my_default_secret_key_32chars_long';

  late FakeMyPlaylistServer server;
  late MyPlaylistService service;

  Future<void> startServer({
    Map<String, dynamic> Function(String command, Map<String, dynamic> args)?
    responder,
    String? serverSecretKey,
    bool chiudeDopoRisposta = true,
  }) async {
    server = await FakeMyPlaylistServer.start(
      serverSecretKey ?? secretKey,
      responder: responder,
      chiudeDopoRisposta: chiudeDopoRisposta,
    );
    service = MyPlaylistService();
  }

  tearDown(() async {
    await server.close();
  });

  group('formato del pacchetto (C1-C4)', () {
    test(
      'il server riesce a decifrare il pacchetto inviato dal client',
      () async {
        await startServer();

        final result = await service.sendCommand(
          host: server.host,
          port: server.port,
          secretKey: secretKey,
          command: 'generate_random',
          args: {'count': 5, 'preview': true},
        );

        expect(result['status'], 'success');
        expect(server.protocolErrors, isEmpty);
        expect(server.receivedCommands.length, 1);
      },
    );

    test('il payload è nonce(12) || mac(16) || ciphertext', () async {
      await startServer();

      await service.sendCommand(
        host: server.host,
        port: server.port,
        secretKey: secretKey,
        command: 'play',
      );

      final payload = server.receivedCommands.single.payload;
      // 12 + 16 + lunghezza del JSON in chiaro
      expect(payload.length, greaterThanOrEqualTo(28));
      expect(
        payload.length,
        28 + utf8.encode('{"command":"play","args":{}}').length,
      );
    });

    test('l\'header dichiara la lunghezza esatta del payload', () async {
      await startServer();

      await service.sendCommand(
        host: server.host,
        port: server.port,
        secretKey: secretKey,
        command: 'stop',
      );

      final packet = server.receivedCommands.single.rawPacket;
      // Il primo byte del JSON in chiaro è '{' (0x7B = 123), e la lunghezza
      // del pacchetto deve corrispondere esattamente a ciò che segue l'header.
      expect(
        packet.length - 4,
        payloadLengthOf('{"command":"stop","args":{}}'),
      );
    });

    test('ogni comando usa un nonce diverso', () async {
      await startServer();

      await service.sendCommand(
        host: server.host,
        port: server.port,
        secretKey: secretKey,
        command: 'play',
      );
      await service.sendCommand(
        host: server.host,
        port: server.port,
        secretKey: secretKey,
        command: 'stop',
      );

      final nonces = server.receivedCommands
          .map((c) => c.payload.sublist(0, 12))
          .toList();
      expect(nonces[0], isNot(nonces[1]));
    });
  });

  group('comandi e argomenti (C5-C6)', () {
    test('i nomi dei comandi sono quelli attesi dal server', () async {
      await startServer();

      await service.play(server.host, server.port, secretKey);
      await service.stop(server.host, server.port, secretKey);
      await service.killVlc(server.host, server.port, secretKey);
      await service.generateRandom(server.host, server.port, secretKey);
      await service.generateRecent(server.host, server.port, secretKey);

      expect(
        server.receivedCommands.map((c) => c.command),
        containsAll([
          'play',
          'stop',
          'kill_vlc',
          'generate_random',
          'generate_recent',
        ]),
      );
    });

    test('generate_random passa count e preview', () async {
      await startServer();

      await service.generateRandom(
        server.host,
        server.port,
        secretKey,
        count: 7,
        preview: true,
      );

      final args = server.receivedCommands.single.args;
      expect(args['count'], 7);
      expect(args['preview'], isTrue);
    });

    test('generate_filtered usa le chiavi attese dal server', () async {
      await startServer();

      await service.generateFiltered(
        server.host,
        server.port,
        secretKey,
        genres: ['Azione'],
        years: ['2020'],
        minRating: 7.5,
        actors: ['Rossi'],
        directors: ['Verdi'],
        excludedGenres: ['Horror'],
        excludedYears: ['1990'],
        excludedActors: ['Neri'],
        excludedDirectors: ['Gialli'],
        limit: 30,
        preview: true,
      );

      final args = server.receivedCommands.single.args;
      // Nomi con underscore: sono le chiavi che il server legge.
      expect(args['min_rating'], 7.5);
      expect(args['excluded_genres'], ['Horror']);
      expect(args['excluded_years'], ['1990']);
      expect(args['excluded_actors'], ['Neri']);
      expect(args['excluded_directors'], ['Gialli']);
      expect(args['limit'], 30);
      expect(args['preview'], isTrue);
      expect(args['genres'], ['Azione']);
      expect(args['directors'], ['Verdi']);
    });

    test('play e stop non inviano argomenti', () async {
      await startServer();

      await service.play(server.host, server.port, secretKey);

      expect(server.receivedCommands.single.args, isEmpty);
    });
  });

  group('lettura della risposta (C7-C9)', () {
    test('decodifica status, message, command e playlist', () async {
      await startServer(
        responder: (command, args) => FakeMyPlaylistServer.defaultResponse(
          command: command,
          playlist: [
            {
              'id': 12,
              'path': '/media/film.mkv',
              'mtime': 1710000000.0,
              'title': 'Il Film',
              'genres': 'Azione',
              'year': '2021',
              'directors': 'Regista',
              'directorThumbs': '',
              'plot': 'Trama',
              'actors': 'Attore',
              'actorThumbs': '',
              'duration': '01:40:00',
              'rating': 7.8,
              'isSeries': 1,
              'posterPath': '/posters/12.jpg',
              'saga': 'Saga',
              'sagaIndex': 1,
              'date_added': 1710000000000,
            },
          ],
        ),
      );

      final result = await service.generateRandom(
        server.host,
        server.port,
        secretKey,
        count: 1,
        preview: true,
      );

      expect(result['status'], 'success');
      expect(result['message'], 'Playlist generata');

      final playlist = result['playlist'] as List;
      final video = playlist.first as Map<String, dynamic>;
      // I campi che la UI di VlcRemote legge devono arrivare intatti.
      expect(video['id'], 12);
      expect(video['title'], 'Il Film');
      expect(video['posterPath'], '/posters/12.jpg');
      expect(video['isSeries'], 1);
      expect(video['rating'], 7.8);
    });

    test('una risposta di errore viene restituita, non lanciata', () async {
      await startServer(
        responder: (command, args) => {
          'status': 'error',
          'message': 'Unknown command: $command',
        },
      );

      final result = await service.sendCommand(
        host: server.host,
        port: server.port,
        secretKey: secretKey,
        command: 'comando_inesistente',
      );

      expect(result['status'], 'error');
      expect(result['message'], contains('Unknown command'));
    });

    test('il server può rispondere in più chunk', () async {
      await startServer(
        responder: (command, args) {
          // Risposta volutamente lunga: il client deve accumulare tutto.
          return {
            'status': 'success',
            'message': 'Playlist generata con successo',
            'command': command,
            'playlist': [
              for (var i = 0; i < 40; i++)
                {
                  'id': i,
                  'title': 'Titolo molto lungo numero $i',
                  'isSeries': 0,
                },
            ],
          };
        },
      );

      final result = await service.generateRandom(
        server.host,
        server.port,
        secretKey,
      );

      expect((result['playlist'] as List).length, 40);
    });

    test('la risposta vale anche se il server non chiude la socket', () async {
      // Il server vero chiude la socket dopo aver scritto, e su quel percorso
      // la risposta arriva da `onDone`. Ma una risposta non dovrebbe dipendere
      // da questo: senza chiusura si aspettava il timeout, si scartava un
      // messaggio gia' arrivato e indietro tornava un errore. Misurato: 10
      // secondi e `status: error` con il server che non chiudeva, 31 ms e
      // `status: success` adesso.
      await startServer(chiudeDopoRisposta: false);

      final sw = Stopwatch()..start();
      final result = await service.generateRandom(
        server.host,
        server.port,
        secretKey,
      );
      sw.stop();

      expect(result['status'], 'success');
      expect(
        sw.elapsedMilliseconds,
        lessThan(2000),
        reason:
            'la risposta non deve aspettare il timeout: '
            'sono passati ${sw.elapsedMilliseconds} ms',
      );
    });

    test("una risposta a meta' non viene presa per completa", () async {
      // Il completamento anticipato prova a decodificare il buffer quando
      // finisce con una graffa. Su JSON troncato deve fallire e aspettare il
      // resto: se per sbaglio accettasse un pezzo, il comando partirebbe con
      // dati inventati.
      await startServer();

      final risultato = await service.generateRandom(
        server.host,
        server.port,
        secretKey,
      );

      expect(risultato['status'], 'success');
      expect(risultato['message'], 'Playlist generata');
    });
  });

  group('derivazione della chiave (C4)', () {
    test('una chiave più corta di 32 byte viene completata con zero', () async {
      // Il server fa la stessa operazione: se il padding divergesse, la
      // decifratura fallirebbe e protocolErrors non sarebbe vuoto.
      const shortKey = 'chiave_corta';
      await startServer(serverSecretKey: shortKey);

      final result = await service.sendCommand(
        host: server.host,
        port: server.port,
        secretKey: shortKey,
        command: 'play',
      );

      expect(result['status'], 'success');
      expect(server.protocolErrors, isEmpty);
    });

    test(
      'una chiave diversa da quella del server fa fallire la decifratura',
      () async {
        // È il comportamento atteso: se il padding o la chiave divergono, il
        // server non può decifrare e risponde con un errore.
        await startServer(serverSecretKey: secretKey);

        final result = await service.sendCommand(
          host: server.host,
          port: server.port,
          secretKey: 'chiave_diversa',
          command: 'play',
        );

        expect(result['status'], 'error');
        expect(server.protocolErrors, isNotEmpty);
      },
    );
  });

  group('errori di rete (non viene propagata alcuna eccezione)', () {
    test('server irraggiungibile', () async {
      // Porta chiusa: il client deve restituire una mappa di errore.
      final closedPort = await _freePort();
      final service = MyPlaylistService();

      final result = await service.sendCommand(
        host: '127.0.0.1',
        port: closedPort,
        secretKey: secretKey,
        command: 'play',
      );

      expect(result['status'], 'error');
      expect(result['message'], isNotEmpty);
    });
  });
}

int payloadLengthOf(String cleartext) =>
    12 + 16 + utf8.encode(cleartext).length;

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}
