import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpaSchermata(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = VlcProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<VlcProvider>.value(
        value: provider,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('il corpo della schermata non finisce sotto i bordi', (
    tester,
  ) async {
    // Su un telefono con barra dei gesti o notch, il corpo del Scaffold arriva
    // fino in fondo allo schermo. Senza SafeArea l'ultimo pannello, quello con
    // i comandi, finisce sotto la barra e i suoi pulsanti restano premibili a
    // meta'.
    //
    // Si simula uno schermo con 34 pixel di inset in basso, come un telefono
    // con barra dei gesti.
    tester.view.physicalSize = const Size(1080, 2160);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: 102, top: 78);
    addTearDown(tester.view.reset);

    await pumpaSchermata(tester);

    final altezza =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;

    // Non si misura `HomeScreen`, che per costruzione occupa tutto lo
    // schermo: si misura il contenuto, che e' quello che finirebbe sotto la
    // barra. Il `Column` del corpo e' il primo discendente della `SafeArea`.
    final contenuto = tester.getRect(
      find
          .descendant(
            of: find.byType(SafeArea).first,
            matching: find.byType(Column),
          )
          .first,
    );

    // Il rettangolo della SafeArea arriva fino in fondo: e' lei che sposta
    // dentro il figlio. A fermarsi prima della barra deve essere il contenuto.
    expect(
      contenuto.bottom,
      lessThanOrEqualTo(altezza - 34),
      reason:
          'il contenuto deve fermarsi prima della barra dei gesti: '
          'arriva a ${contenuto.bottom} su $altezza',
    );
  });

  testWidgets('i pulsanti delle icone hanno un tooltip', (tester) async {
    // Un pulsante solo icona non dice niente a chi non lo conosce, e senza
    // tooltip non e' nemmeno raggiungibile con il lettore di schermo.
    await pumpaSchermata(tester);

    final senzaTooltip = <String>[];
    for (final bottone in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      if (bottone.tooltip == null) {
        senzaTooltip.add(bottone.icon.toString());
      }
    }
    expect(senzaTooltip, isEmpty, reason: 'IconButton senza tooltip');
  });

  testWidgets('il dialogo di connessione ha i tooltip', (tester) async {
    // Il dialogo ha due icone senza testo: chiudi e l'occhio della chiave.
    await pumpaSchermata(tester);

    await tester.tap(find.byTooltip('Non connesso'));
    await tester.pumpAndSettle();

    for (final bottone in tester.widgetList<IconButton>(
      find.byType(IconButton),
    )) {
      expect(
        bottone.tooltip,
        isNotNull,
        reason: 'IconButton senza tooltip nel dialogo',
      );
    }
  });
}
