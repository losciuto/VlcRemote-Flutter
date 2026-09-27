import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/constants/app_constants.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/services/connection_service.dart';
import 'package:vlc_remote_flutter/services/secure_storage_service.dart';
import 'package:vlc_remote_flutter/services/vlc_service.dart';

import 'support/fake_my_playlist_server.dart';
import 'support/fake_vlc_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notifyListeners dopo dispose non lancia', () {
    // Regressione: operazioni con attese asincrone (riconnessione, barra di
    // progresso MyPlaylist, debounce del volume) notificano anche dopo che il
    // provider è stato smontato, e ChangeNotifier in quel caso lancia.
    SharedPreferences.setMockInitialValues({});
    final provider = VlcProvider();

    provider.dispose();

    expect(provider.notifyListeners, returnsNormally);
  });

  test('dispose è idempotente rispetto alle notifiche in arrivo', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = VlcProvider();

    // Simula una notifica tardiva mentre il provider è già smontato.
    provider.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(provider.isConnected, isFalse);
    expect(provider.isMyPlaylistBusy, isFalse);
  });

  group('MyPlaylist indipendente da VLC', () {
    const secretKey = 'my_default_secret_key_32chars_long';

    test('la connessione resta registrata se VLC non risponde', () async {
      // MyPlaylist e' un server a se' stante: se VLC e' fermo, le sue funzioni
      // devono restare utilizzabili lo stesso. Registrando la connessione solo
      // dopo il successo di VLC, un VLC irraggiungibile rendeva MyPlaylist
      // irraggiungibile a cascata, e i due guasti si mascheravano a vicenda.
      SharedPreferences.setMockInitialValues({});
      final risposta = FakeMyPlaylistServer.defaultResponse;
      final mp = await FakeMyPlaylistServer.start(
        secretKey,
        responder: (command, args) => risposta(command: command),
      );
      addTearDown(mp.close);

      // Porta mai aperta: la connessione a VLC viene rifiutata.
      final chiusa = await ServerSocket.bind('127.0.0.1', 0);
      final portaChiusa = chiusa.port;
      await chiusa.close();

      final provider = VlcProvider(
        vlcService: VlcService(),
        connectionService: ConnectionService(secrets: InMemorySecretStore()),
      );
      addTearDown(provider.dispose);

      final ok = await provider.connect(
        VlcConnection(
          id: '1',
          name: 'Sala',
          ipAddress: '127.0.0.1',
          port: portaChiusa,
          myPlaylistIp: mp.host,
          myPlaylistPort: mp.port,
          myPlaylistSecretKey: secretKey,
          lastUsed: DateTime(2026, 9, 27),
        ),
      );

      expect(ok, isFalse, reason: 'VLC non risponde, il risultato lo dice');
      expect(provider.isConnected, isFalse);
      expect(
        provider.currentConnection,
        isNotNull,
        reason: 'la connessione scelta deve restare registrata',
      );
      expect(
        provider.isMyPlaylistConfigured,
        isTrue,
        reason: 'MyPlaylist deve restare utilizzabile anche senza VLC',
      );
    });
  });

  group('riconnessione dopo un comando MyPlaylist (4.7)', () {
    const secretKey = 'my_default_secret_key_32chars_long';

    test(
      "l'attesa per VLC non notifica una volta per tappa",
      () async {
        // La riconnessione dopo un comando MyPlaylist riuscito prevede una
        // pausa fissa perche' VLC si avvii. Quella pausa era spezzata in dieci
        // tappe, e ogni tappa notificava: dieci ricostruzioni dell'albero in
        // due secondi, a intervalli regolari, senza che nulla venisse
        // mostrato, perche' il valore del progresso non e' mai stato letto.
        //
        // Qui conta proprio la frequenza: la pausa deve restare, quindi il
        // tempo trascorso non puo' scendere. Le notifiche, quelle no.
        //
        // La soglia sta nel mezzo fra i due comportamenti, non è il numero
        // "dieci" della vecchia implementazione: durante l'attesa passano anche
        // le notifiche del polling, che gira una volta al secondo. Misurati
        // sul comando reale: 17 notifiche con le dieci tappe, 7 senza.
        SharedPreferences.setMockInitialValues({});
        final mp = await FakeMyPlaylistServer.start(
          secretKey,
          responder: (command, args) =>
              FakeMyPlaylistServer.defaultResponse(command: command),
        );
        final vlc = await FakeVlcServer.start((c) => []);
        addTearDown(() async {
          await mp.close();
          await vlc.close();
        });

        final provider = VlcProvider(
          vlcService: VlcService(),
          connectionService: ConnectionService(secrets: InMemorySecretStore()),
        );
        addTearDown(provider.dispose);

        final ok = await provider.connect(
          VlcConnection(
            id: '1',
            name: 'Sala',
            ipAddress: vlc.host,
            port: vlc.port,
            myPlaylistIp: mp.host,
            myPlaylistPort: mp.port,
            myPlaylistSecretKey: secretKey,
            lastUsed: DateTime(2026, 9, 27),
          ),
        );
        expect(ok, isTrue, reason: 'la connessione deve riuscire');

        var notifiche = 0;
        provider.addListener(() => notifiche++);

        final sw = Stopwatch()..start();
        await provider.mpGenerateRandom();
        sw.stop();

        expect(
          provider.lastMpStatus,
          'SUCCESS',
          reason: 'il comando deve andare a buon fine sul server finto',
        );
        expect(
          sw.elapsedMilliseconds,
          greaterThanOrEqualTo(AppConstants.myPlaylistReconnectDelayMs),
          reason: "l'attesa per l'avvio di VLC va mantenuta",
        );
        expect(
          notifiche,
          lessThanOrEqualTo(10),
          reason:
              'la pausa deve essere una sola attesa, non dieci passi che '
              'notificano: ne sono arrivate $notifiche',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('polling e ciclo di vita (4.2)', () {
    late FakeVlcServer server;

    List<String> responder(String command) => switch (command) {
      'status' => [
        '( state: playing )\n(time: 42)\n(length: 100)\n(audio volume: 128)\n',
      ],
      'get_title' => ['Il Film\n'],
      'get_time' => ['42\n'],
      'get_length' => ['100\n'],
      'volume' => ['128\n'],
      _ => [],
    };

    /// Provider connesso al server finto, costruito con i servizi iniettati.
    Future<VlcProvider> connectedProvider() async {
      server = await FakeVlcServer.start(responder);
      SharedPreferences.setMockInitialValues({});
      final provider = VlcProvider(
        vlcService: VlcService(),
        connectionService: ConnectionService(secrets: InMemorySecretStore()),
      );
      final ok = await provider.connect(
        VlcConnection(
          id: '1',
          name: 'Sala',
          ipAddress: server.host,
          port: server.port,
          lastUsed: DateTime(2026, 9, 27),
        ),
      );
      expect(
        ok,
        isTrue,
        reason: 'la connessione al server finto deve riuscire',
      );
      return provider;
    }

    void changeLifecycle(AppLifecycleState state) {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(state);
    }

    // `test` e non `testWidgets`: qui l'I/O e' reale (socket verso il server
    // finto) e dentro testWidgets il tempo e' finto, quindi le attese non
    // avanzerebbero.
    test('il polling si ferma quando l\'app va in pausa', () async {
      final provider = await connectedProvider();
      addTearDown(() async {
        provider.dispose();
        await server.close();
      });

      expect(server.receivedCommands, isNotEmpty);

      changeLifecycle(AppLifecycleState.paused);
      final inPausa = server.receivedCommands.length;

      // Due intervalli di refresh: senza la sospensione arriverebbero nuove
      // richieste, quindi il confronto dice qualcosa.
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      expect(
        server.receivedCommands.length,
        inPausa,
        reason: 'il polling deve essere sospeso in pausa',
      );
    });

    test('al ritorno in primo piano lo stato viene ricaricato', () async {
      final provider = await connectedProvider();
      addTearDown(() async {
        provider.dispose();
        await server.close();
      });

      changeLifecycle(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final inPausa = server.receivedCommands.length;

      changeLifecycle(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        server.receivedCommands.length,
        greaterThan(inPausa),
        reason: 'al ritorno lo stato deve essere ricaricato subito',
      );
    });

    test('dopo dispose nessun polling riparte', () async {
      final provider = await connectedProvider();
      addTearDown(() async {
        await server.close();
      });

      provider.dispose();
      final prima = server.receivedCommands.length;

      changeLifecycle(AppLifecycleState.paused);
      changeLifecycle(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(
        server.receivedCommands.length,
        prima,
        reason: 'l\'osservatore deve essere rimosso in dispose',
      );
    });
  });
}
