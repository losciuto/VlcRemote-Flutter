import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/widgets/disconnected_view.dart';

Widget _schermata({String? errore, VoidCallback? onManageServers}) {
  return MaterialApp(
    home: Scaffold(
      body: DisconnectedView(
        onManageServers: onManageServers ?? () {},
        errorMessage: errore,
      ),
    ),
  );
}

void main() {
  testWidgets('dice che non e\' collegata e come fare', (tester) async {
    await tester.pumpWidget(_schermata());

    expect(find.text('Non connesso a VLC'), findsOneWidget);
    expect(find.textContaining('icona di connessione'), findsOneWidget);
  });

  testWidgets('il pulsante per gestire i server chiama la sua azione', (
    tester,
  ) async {
    // E' l'unica via d'uscita da questa schermata: se il pulsante sparisce
    // quando la lista dei server e' vuota, l'app non si puo' neanche
    // configurare.
    var premuti = 0;
    await tester.pumpWidget(_schermata(onManageServers: () => premuti++));

    await tester.tap(find.text('Gestione Server VLC'));
    expect(premuti, 1);
  });

  testWidgets('senza errore non c\'e\' il banner', (tester) async {
    await tester.pumpWidget(_schermata());

    expect(find.text('Errore di connessione'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('con errore il banner lo ripete', (tester) async {
    // Senza collegamento la schermata vuota non spiega il fallimento, quindi
    // il messaggio del provider e' l'unica cosa che dice perche' non e' andata.
    await tester.pumpWidget(_schermata(errore: 'Connection refused'));

    expect(find.text('Connection refused'), findsOneWidget);
  });

  testWidgets('l\'errore non sposta il pulsante fuori dallo schermo', (
    tester,
  ) async {
    // Su uno schermo piccolo il banner e' quello che fa crescere la colonna:
    // se il contenuto non scorre, il pulsante sparisce sotto.
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_schermata(errore: 'x' * 400));

    expect(tester.takeException(), isNull);
    expect(find.text('Gestione Server VLC'), findsOneWidget);
  });
}
