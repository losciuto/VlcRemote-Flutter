import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/services/connection_service.dart';
import 'package:vlc_remote_flutter/services/secure_storage_service.dart';
import 'package:vlc_remote_flutter/services/vlc_service.dart';
import 'package:vlc_remote_flutter/widgets/status_bar.dart';

import 'support/fake_vlc_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Risponde come VLC: senza questo, ogni comando del provider aspetterebbe
  /// il proprio timeout e la connessione non finirebbe.
  List<String> risposte(String comando) => switch (comando) {
    'status' => [
      '( state: playing )\n(time: 42)\n(length: 100)\n(audio volume: 128)\n',
    ],
    'get_title' => ['Il Film\n'],
    'get_time' => ['42\n'],
    'get_length' => ['100\n'],
    'volume' => ['128\n'],
    _ => [],
  };

  group('stato letto dal provider', () {
    // Qui si usa `test` e non `testWidgets`: la connessione al server finto e'
    // I/O vero, e dentro `testWidgets` il tempo e' finto, quindi la socket non
    // avanza e il test resta appeso. Non serve montare nessun widget per
    // verificare la traduzione dello stato, quindi non si paga quel prezzo.
    late FakeVlcServer server;
    late VlcProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      server = await FakeVlcServer.start(risposte);
      provider = VlcProvider(
        vlcService: VlcService(),
        connectionService: ConnectionService(secrets: InMemorySecretStore()),
      );
    });

    tearDown(() async {
      provider.dispose();
      await server.close();
    });

    Future<void> collega({String? myPlaylistIp}) async {
      final ok = await provider.connect(
        VlcConnection(
          id: '1',
          name: 'Sala',
          ipAddress: server.host,
          port: server.port,
          myPlaylistIp: myPlaylistIp,
          myPlaylistPort: 4242,
          myPlaylistSecretKey: myPlaylistIp == null ? null : 'chiave',
          lastUsed: DateTime(2026, 9, 27),
        ),
      );
      expect(
        ok,
        isTrue,
        reason: 'la connessione al server finto deve riuscire',
      );
    }

    test('senza connessione VLC e\' disconnesso, senza indirizzo', () {
      final barra = StatusBar.forProvider(provider);

      expect(barra.vlc.label, 'VLC');
      expect(barra.vlc.text, 'DISCONNESSO');
      expect(barra.vlc.ip, '---');
    });

    test('collegato riporta l\'indirizzo', () async {
      await collega();

      final barra = StatusBar.forProvider(provider);

      expect(barra.vlc.text, 'COLLEGATO');
      expect(barra.vlc.ip, server.host);
    });

    test('MyPlaylist non configurato', () async {
      await collega();

      expect(StatusBar.forProvider(provider).myPlaylist.text, 'NON CONFIG.');
    });

    test('MyPlaylist configurato ma mai provato', () async {
      // E' la distinzione che il refactoring ha reso esplicita: un server
      // appena configurato e uno spento non devono sembrare la stessa cosa.
      await collega(myPlaylistIp: '10.0.0.9');

      final barra = StatusBar.forProvider(provider);

      expect(barra.myPlaylist.text, 'NON TESTATO');
      expect(barra.myPlaylist.ip, '10.0.0.9');
    });

    test('MyPlaylist non configurato mostra l\'IP di VLC, non tre trattini', () {
      // Il campo IP di MyPlaylist resta "---" quando non e' configurato, anche
      // se la connessione VLC c'e': i due indirizzi non sono la stessa cosa.
      final barra = StatusBar.forProvider(provider);

      expect(barra.vlc.ip, '---');
      expect(barra.myPlaylist.ip, '---');
      expect(barra.myPlaylist.label, 'MP');
    });
  });

  group('disegno', () {
    // Qui non c'e' I/O: la barra riceve gia' i valori, e basta guardare come
    // vengono resi.
    const collegato = LinkStatus(
      label: 'VLC',
      text: 'COLLEGATO',
      color: Colors.green,
      icon: Icons.link,
      ip: '192.168.1.15',
    );
    const nonConfigurato = LinkStatus(
      label: 'MP',
      text: 'NON CONFIG.',
      color: Colors.grey,
      icon: Icons.playlist_add_check,
      ip: '---',
    );

    Future<void> mostra(
      WidgetTester tester, {
      LinkStatus? vlc,
      LinkStatus? myPlaylist,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusBar(
              vlc: vlc ?? collegato,
              myPlaylist: myPlaylist ?? nonConfigurato,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('mostra stato e indirizzo dei due collegamenti', (
      tester,
    ) async {
      await mostra(tester);

      expect(find.text('VLC: '), findsOneWidget);
      expect(find.text('COLLEGATO'), findsOneWidget);
      expect(find.text('192.168.1.15'), findsOneWidget);
      expect(find.text('MP: '), findsOneWidget);
      expect(find.text('NON CONFIG.'), findsOneWidget);
    });

    testWidgets('i due collegamenti non si confondono', (tester) async {
      // Il pericolo di una barra con due voci e' che una legga i dati
      // dell'altra: qui VLC e' collegato e MyPlaylist no, e devono restare
      // separati.
      await mostra(tester);

      expect(find.text('COLLEGATO'), findsOneWidget);
      expect(find.text('NON CONFIG.'), findsOneWidget);
    });

    testWidgets('su schermo stretto nessuno dei due esce dai bordi', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2160);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await mostra(tester);

      final barra = tester.getRect(find.byType(StatusBar));
      for (final testo in ['192.168.1.15', 'NON CONFIG.']) {
        final riquadro = tester.getRect(find.text(testo));
        expect(
          riquadro.left,
          greaterThanOrEqualTo(barra.left),
          reason: '"$testo" esce a sinistra',
        );
        expect(
          riquadro.right,
          lessThanOrEqualTo(barra.right),
          reason: '"$testo" esce a destra',
        );
      }
    });
  });
}
