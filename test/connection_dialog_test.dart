import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/widgets/connection_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<VlcProvider> apriPoiChiudi(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = VlcProvider();
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<VlcProvider>.value(
        value: provider,
        child: const MaterialApp(home: ConnectionDialog()),
      ),
    );
    await tester.pumpAndSettle();

    // Il dialogo parte dall'elenco delle connessioni salvate: i campi sono
    // nel form, che si apre da l i.
    await tester.tap(find.text('Nuovo Server VLC'));
    await tester.pumpAndSettle();

    final controller = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((c) => c.controller)
        .toList();
    expect(controller.length, 7, reason: 'il form ha sette campi');
    return provider;
  }

  testWidgets('tutti i campi vengono distrutti alla chiusura', (tester) async {
    // Nove righe di dispose ne mancavano tre, quelle dei campi di MyPlaylist:
    // ogni apertura del dialogo lasciava tre controllervivi, con i loro
    // listener, per tutta la sessione.
    //
    // Il controllo e' per tutti e sette e non solo per qualcuno: un controller
    // distrutto si riconosce, perche' aggiungere un listener su un
    // ChangeNotifier distrutto lancia.
    await apriPoiChiudi(tester);

    final campi = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .map((c) => c.controller)
        .toList();

    // Smonta il dialogo, cosi' dispose() viene chiamata.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    for (final controller in campi) {
      expect(
        () => controller.addListener(() {}),
        throwsA(isA<Error>()),
        reason: 'un controller non e\' stato distrutto',
      );
    }
  });
}
