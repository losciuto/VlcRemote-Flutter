import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/exceptions/vlc_exceptions.dart';
import 'package:vlc_remote_flutter/services/vlc_service.dart';

import 'support/fake_vlc_server.dart';

void main() {
  late FakeVlcServer server;
  late VlcService service;

  /// Risposte standard per una connessione funzionante.
  List<String> defaultResponder(String command) {
    switch (command) {
      case 'get_title':
        return ['Il Film\n'];
      case 'status':
        return [
          '( state: playing )\n(time: 42)\n(length: 100)\n(audio volume: 128)\n',
        ];
      case 'get_time':
        return ['42\n'];
      case 'get_length':
        return ['100\n'];
      case 'volume':
        return ['128\n'];
      default:
        return [];
    }
  }

  Future<void> startServer(FakeVlcResponder responder) async {
    server = await FakeVlcServer.start(responder);
    service = VlcService();
    final connected = await service.connect(server.host, server.port);
    expect(
      connected,
      isTrue,
      reason: 'la connessione al server finto deve riuscire',
    );
  }

  tearDown(() async {
    service.dispose();
    await server.close();
  });

  group('getStatus - isPlaying', () {
    test('non dichiara in riproduzione un video in pausa', () async {
      await startServer((command) {
        if (command == 'status') {
          return ['( state: paused )\n(time: 42)\n'];
        }
        return defaultResponder(command);
      });

      final status = await service.getStatus();

      // Regressione: la condizione era "state == 'playing' || time > 0",
      // quindi un video in pausa risultava in riproduzione.
      expect(status, isNotNull);
      expect(status!.isPlaying, isFalse);
      expect(status.currentTime, 42);
    });

    test('dichiara in riproduzione quando lo stato è playing', () async {
      await startServer(defaultResponder);

      final status = await service.getStatus();

      expect(status!.isPlaying, isTrue);
    });

    test('ricade sul tempo quando lo stato non è disponibile', () async {
      await startServer((command) {
        if (command == 'status') {
          // 'status' senza media non riporta lo state: solo il tempo.
          return ['( time: 42 )\n'];
        }
        return defaultResponder(command);
      });

      final status = await service.getStatus();

      expect(status!.isPlaying, isTrue);
    });

    test('non è in riproduzione quando è fermo', () async {
      await startServer((command) {
        if (command == 'status') return ['( state: stopped )\n'];
        if (command == 'get_time') return ['0\n'];
        return defaultResponder(command);
      });

      final status = await service.getStatus();

      expect(status!.isPlaying, isFalse);
    });
  });

  group('sendCommandAndRead', () {
    test('ricompone una risposta spezzata su più chunk', () async {
      await startServer((command) {
        if (command == 'get_title') {
          // VLC spezza la risposta: il vecchio codice leggeva solo il primo chunk.
          return ['Un Titolo ', 'Molto ', 'Lungo\n'];
        }
        return defaultResponder(command);
      });

      final title = await service.getTitle();

      expect(title, 'Un Titolo Molto Lungo');
    });

    test('ignora l\'eco del comando e il prompt', () async {
      await startServer((command) {
        if (command == 'get_time') return ['77\n'];
        return defaultResponder(command);
      });

      // Il server finto fa eco di ogni comando: se l'eco non fosse filtrato,
      // la risposta conterrebbe anche 'get_time'.
      final time = await service.getTime();

      expect(time, 77);
    });

    test('restituisce null se il comando non riceve risposta', () async {
      await startServer((command) {
        // 'get_time' resta senza risposta: deve scadere il timeout.
        if (command == 'get_time') return [];
        return defaultResponder(command);
      });

      final result = await service.sendCommandAndRead(
        'get_time',
        timeoutMs: 300,
      );

      expect(result, isNull);
    });
  });

  group('getPlaylist', () {
    const playlistBody = [
      '+----[ Start of playlist ]-----+\n',
      '| 4 - Movie (Director\'s Cut)\n',
      '| 5 - Film (2025)\n',
      '+----[ End of playlist ]-----+\n',
    ];

    test('conserva le parentesi che fanno parte del titolo', () async {
      await startServer((command) {
        if (command == 'playlist') return playlistBody;
        return defaultResponder(command);
      });

      final items = await service.getPlaylist();

      expect(items.length, 2);
      // Regressione: la regex precedente cancellava qualsiasi testo tra
      // parentesi, quindi "Director's Cut" spariva dal titolo.
      expect(items[0].title, "Movie (Director's Cut)");
      // L'anno in coda viene invece rimosso, come prima.
      expect(items[1].title, 'Film');
    });

    test('non si sovrascrive con il polling dello stato', () async {
      await startServer((command) {
        if (command == 'playlist') {
          return [
            '+----[ Start of playlist ]-----+\n',
            for (var i = 0; i < 12; i++) '| ${i + 1} - Traccia numero $i\n',
            '+----[ End of playlist ]-----+\n',
          ];
        }
        return defaultResponder(command);
      });

      // Lanciati insieme: prima del mutex la risposta di get_time finiva
      // dentro il buffer della playlist (o viceversa).
      final playlistFuture = service.getPlaylist();
      final timeFuture = service.sendCommandAndRead('get_time');
      final items = await playlistFuture;
      final time = await timeFuture;

      expect(items.length, 12);
      expect(time, '42');
    });
  });

  group('scenari di errore', () {
    test('getStatus senza connessione lancia VlcConnectionException', () async {
      service = VlcService();
      server = await FakeVlcServer.start(defaultResponder);

      // Regressione: prima restituiva uno stato vuoto, quindi il provider non
      // poteva contare il fallimento e non riconnette mai.
      expect(service.getStatus, throwsA(isA<VlcConnectionException>()));
    });

    test('getStatus senza risposta lancia VlcTimeoutException', () async {
      await startServer((command) => []); // il server non risponde a nulla

      expect(service.getStatus, throwsA(isA<VlcTimeoutException>()));
    });

    test(
      'getStatus con la socket muta spara un comando solo, non cinque',
      () async {
        // Con VLC collegato ma morto, `getStatus` mandava cinque comandi in
        // sequenza, ciascuno con un timeout da 1,5 secondi, e il provider ne
        // ritenta tre volte: 22 secondi e mezzo per accorgersi che il
        // telecomando non risponde piu'.
        //
        // Ora il primo comando e' `status`, che su una socket viva risponde
        // sempre: se non risponde, la socket non consegna, e gli altri quattro
        // avrebbero usato la stessa socket per un errore identico.
        //
        // Il conteggio dei comandi ricevuti e' la prova, non il tempo: qui il
        // timeout e' troppo corto per misurare 22 secondi in un test.
        await startServer((command) => []); // il server non risponde a nulla

        await expectLater(
          service.getStatus(),
          throwsA(isA<VlcTimeoutException>()),
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(
          server.receivedCommands,
          ['status'],
          reason:
              'la socket non consegna: gli altri quattro avrebbero '
              'speso altri sei secondi per lo stesso errore',
        );
      },
    );

    test(
      'getStatus con niente in riproduzione non lo scambia con una socket morta',
      () async {
        // Il caso da non rompere, ed e' la ragione per cui la sonda e'
        // `status` e non `get_title`.
        //
        // Con niente in riproduzione VLC risponde a `get_title` con una riga
        // vuota, e il filtro che scarta l'eco e il prompt butta via anche
        // quella: la risposta non arma il timer di silenzio e il comando va
        // in timeout su un VLC perfettamente vivo. Se la sonda fosse stata
        // `get_title`, questo stato sembrerebbe quello di un collegamento
        // perso, e l'app chiuderebbe la connessione a chi sta solo guardando
        // la schermata di attesa.
        //
        // Qui il server dice `status` con time 0 e length 0, che e' esattamente
        // quello che risponde VLC a macchina ferma, e `get_title` tace.
        await startServer((command) {
          if (command == 'status') {
            return ['( state: stopped )', '( time: 0 )', '( length: 0 )'];
          }
          if (command == 'get_time') return ['0'];
          return [];
        });

        final status = await service.getStatus();

        expect(status, isNotNull);
        expect(status!.nowPlaying, 'Nessun video in riproduzione');
        expect(status.isPlaying, isFalse);
        expect(status.currentTime, 0);
        expect(server.receivedCommands, contains('status'));
      },
    );

    test(
      'getStatus usa ancora i comandi singoli per quello che status non dice',
      () async {
        // `status` non riporta il titolo, e in alcune build non riporta il
        // volume: quando mancano, vanno cercati nei comandi dedicati. La
        // sonda sta all'inizio, non al posto dei fallback.
        await startServer((command) {
          if (command == 'status') return ['( state: playing )'];
          if (command == 'get_title') return ['Un film'];
          if (command == 'get_time') return ['42'];
          if (command == 'get_length') return ['300'];
          return [];
        });

        final status = await service.getStatus();

        expect(status!.nowPlaying, 'Un film');
        expect(status.currentTime, 42);
        expect(status.totalTime, 300);
        expect(status.isPlaying, isTrue);
      },
    );

    test(
      'getPlaylist senza connessione lancia, non restituisce lista vuota',
      () async {
        service = VlcService();
        server = await FakeVlcServer.start(defaultResponder);

        // Una playlist vuota e una connessione persa restituivano entrambe [].
        expect(service.getPlaylist, throwsA(isA<VlcConnectionException>()));
      },
    );

    test('getPlaylist con playlist vuota restituisce lista vuota', () async {
      await startServer((command) {
        if (command == 'playlist') {
          return [
            '+----[ Start of playlist ]-----+\n',
            '+----[ End of playlist ]-----+\n',
          ];
        }
        return defaultResponder(command);
      });

      expect(await service.getPlaylist(), isEmpty);
    });

    test('getPlaylist dopo la disconnessione lancia', () async {
      await startServer(defaultResponder);
      await service.disconnect();

      expect(service.getPlaylist, throwsA(isA<VlcConnectionException>()));
    });
  });

  group('clamp dei valori inviati a VLC', () {
    setUp(() async {
      await startServer(defaultResponder);
    });

    test('limita il volume al massimo di VLC', () async {
      await service.setVolume(999);
      expect(await server.waitForCommand('volume 256'), isTrue);
    });

    test('non invia un volume negativo', () async {
      await service.setVolume(-50);
      expect(await server.waitForCommand('volume 0'), isTrue);
    });

    test('non invia un seek negativo', () async {
      await service.seek(-10);
      expect(await server.waitForCommand('seek 0'), isTrue);
    });

    test('non invia un indice playlist sotto 1', () async {
      await service.goto(0);
      expect(await server.waitForCommand('goto 1'), isTrue);
    });

    test('forza un passo di volume almeno 1', () async {
      await service.volumeUp(0);
      expect(await server.waitForCommand('volup 1'), isTrue);
    });
  });

  group('dispose', () {
    test("non lancia se il collegamento e' gia' stato chiuso", () async {
      // Se VLC chiude la socket (o se la connessione cade), la socket locale
      // resta riferita dal servizio ma non e' piu' apribile, e l'errore
      // uscirebbe da dispose: non e' il posto giusto per far fallire lo
      // smontaggio.
      //
      // Nota: da solo questo test non copre il caso peggiore. Chiudendo il
      // server la socket locale resta infatti ancora apribile, quindi il
      // test passa anche senza la protezione. Lo stato che fa davvero
      // fallire `close()` e' quello della riconnessione dopo un comando
      // MyPlaylist, ed e' coperto dal test corrispondente in
      // vlc_provider_test.dart.
      server = await FakeVlcServer.start(defaultResponder);
      service = VlcService();
      await service.connect(server.host, server.port);

      // Il server chiude sotto il client, come fa VLC quando esce.
      await server.close();

      expect(service.dispose, returnsNormally);
    });

    test(
      'dopo dispose non si ricontatta, anche se il server risponde',
      () async {
        // Rientrare su un servizio smontato fallirebbe piu' avanti, dentro il
        // listener, perche' lo stream delle risposte e' chiuso. Qui la
        // connessione riuscirebbe, quindi il test distingue davvero la guardia
        // da una connessione semplicemente fallita.
        server = await FakeVlcServer.start(defaultResponder);
        service = VlcService();
        service.dispose();

        final ok = await service.connect(server.host, server.port);

        expect(ok, isFalse);
        expect(service.isConnected, isFalse);
        await server.close();
      },
    );
  });
}
