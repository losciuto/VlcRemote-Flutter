import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/models/vlc_status.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/widgets/control_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Monta il pannello dei comandi con uno stato noto, cosi' l'icona di
  /// play/pausa e' determinata e il suo nome puo' essere verificato.
  Future<void> pumpaPannello(
    WidgetTester tester, {
    bool inRiproduzione = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final provider = VlcProvider();
    addTearDown(provider.dispose);
    provider.testStatus = VlcStatus(
      isPlaying: inRiproduzione,
      currentTime: 0,
      totalTime: 0,
      volume: 50,
      nowPlaying: 'Brano',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<VlcProvider>.value(
        value: provider,
        child: const MaterialApp(home: Scaffold(body: ControlPanel())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('i quattro pulsanti di trasporto hanno un nome', (tester) async {
    // Sono le icone piu' premute dell'app e gli unici controlli che non avevano
    // nessuna etichetta: `label` passava la stringa vuota e nessuno se ne
    // accorgeva, perche' la firma del metodo accettava gia' il nome.
    final gestore = tester.ensureSemantics();
    await pumpaPannello(tester);

    expect(find.bySemanticsLabel('Traccia precedente'), findsOneWidget);
    expect(find.bySemanticsLabel('Riproduci'), findsOneWidget);
    expect(find.bySemanticsLabel('Ferma la riproduzione'), findsOneWidget);
    expect(find.bySemanticsLabel('Traccia successiva'), findsOneWidget);

    gestore.dispose();
  });

  testWidgets('in riproduzione il pulsante si chiama pausa', (tester) async {
    // Se il nome restasse "riproduci" mentre l'icona e' quella di pausa, il
    // lettore di schermo annuncerebbe l'operazione contraria a quella che il
    // toco avvia.
    final gestore = tester.ensureSemantics();
    await pumpaPannello(tester, inRiproduzione: true);

    expect(find.bySemanticsLabel('Pausa'), findsOneWidget);
    expect(find.bySemanticsLabel('Riproduci'), findsNothing);

    gestore.dispose();
  });

  testWidgets('il volume si annuncia con la sua percentuale', (tester) async {
    final gestore = tester.ensureSemantics();
    await pumpaPannello(tester);

    // Nel pannello ci sono due cursori, quello di posizione e quello del
    // volume: si prende quello che sa dire quanto si alza il volume.
    final cursori = tester
        .widgetList<Slider>(find.byType(Slider))
        .where((c) => c.semanticFormatterCallback != null);
    expect(cursori, hasLength(1));
    expect(cursori.single.semanticFormatterCallback!(50), 'Volume 50%');

    gestore.dispose();
  });

  testWidgets('i pulsanti di trasporto hanno anche il tooltip', (tester) async {
    // Il tooltip serve a chi non usa il lettore di schermo e ci arriva col
    // dito: le due cose non si sostituiscono.
    await pumpaPannello(tester);

    for (final nome in [
      'Traccia precedente',
      'Riproduci',
      'Ferma la riproduzione',
      'Traccia successiva',
    ]) {
      expect(find.byTooltip(nome), findsOneWidget, reason: nome);
    }
  });

  testWidgets('l\'icona non viene annunciata due volte', (tester) async {
    // Con `Semantics` e `Icon` insieme, il lettore di schermo legge prima
    // "pulsante" e poi "precedente, traccia" come due cose diverse. Il nome
    // del pulsante basta.
    final gestore = tester.ensureSemantics();
    await pumpaPannello(tester);

    final nodo = tester.getSemantics(find.bySemanticsLabel('Riproduci'));
    expect(nodo.label, 'Riproduci');

    gestore.dispose();
  });
}
