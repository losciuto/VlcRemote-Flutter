import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<VlcProvider> apriSchermata(WidgetTester tester) async {
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
    return provider;
  }

  /// Apre la schermata e il dialogo delle informazioni.
  Future<void> apriInfo(WidgetTester tester) async {
    await apriSchermata(tester);
    await tester.tap(find.byTooltip('Informazioni'));
    await tester.pumpAndSettle();
  }

  /// Apre la schermata, il dialogo delle informazioni e arriva fino alla
  /// richiesta di conferma.
  ///
  /// Il percorso si fa a mano, schermata compresa, perche' la cosa da provare
  /// e' proprio il percorso: il pulsante chiude il dialogo delle informazioni
  /// e ne chiede un altro, e se il secondo riusasse il contesto del primo si
  /// romperebbe nel mezzo, a meta' della sequenza. Un test che costruisse solo
  /// i due dialogi non passerebbe da quel ramo.
  Future<void> apriFinoAllaConferma(WidgetTester tester) async {
    await apriInfo(tester);
    await tester.tap(find.text('Killa tutte le istanze VLC'));
    await tester.pumpAndSettle();
  }

  testWidgets('il dialogo delle informazioni si apre', (tester) async {
    await apriInfo(tester);

    expect(find.text('VLC Remote Flutter'), findsOneWidget);
  });

  testWidgets('il dialogo delle informazioni non trabocca', (tester) async {
    // Il pulsante che ferma VLC e' l'ultima riga: senza contenuto che scorre,
    // su uno schermo basso finiva sotto il bordo e l'azione che interrompe la
    // riproduzione era proprio quella che non si vedeva.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await apriInfo(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Killa tutte le istanze VLC'), findsOneWidget);
  });

  testWidgets('fermare VLC chiede la conferma e non la esegue subito', (
    tester,
  ) async {
    // Due passaggi: il primo per arrivarci, il secondo per confermare.
    await apriFinoAllaConferma(tester);

    expect(find.text('Conferma Azione'), findsOneWidget);
    expect(find.textContaining('terminerà forzatamente'), findsOneWidget);
    expect(find.text('Comando Kill VLC inviato'), findsNothing);
  });

  testWidgets('annullando non parte nessun comando', (tester) async {
    await apriFinoAllaConferma(tester);

    await tester.tap(find.text('ANNULLA'));
    await tester.pumpAndSettle();

    expect(find.text('Conferma Azione'), findsNothing);
    expect(find.text('Comando Kill VLC inviato'), findsNothing);
  });

  testWidgets('procedendo parte il comando e si avvisa', (tester) async {
    await apriFinoAllaConferma(tester);

    await tester.tap(find.text('PROCEDI'));
    await tester.pump();

    // Il comando arriva al provider anche se il server non risponde: qui si
    // controlla che il percorso arrivi in fondo, non che VLC si fermi.
    expect(find.text('Comando Kill VLC inviato'), findsOneWidget);
  });

  testWidgets('chiudendo il dialogo non parte nessun comando', (tester) async {
    await apriInfo(tester);

    await tester.tap(find.text('CHIUDI'));
    await tester.pumpAndSettle();

    expect(find.text('Conferma Azione'), findsNothing);
    expect(find.text('Comando Kill VLC inviato'), findsNothing);
  });
}
