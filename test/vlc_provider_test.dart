import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/services/connection_service.dart';
import 'package:vlc_remote_flutter/services/secure_storage_service.dart';
import 'package:vlc_remote_flutter/services/vlc_service.dart';

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
