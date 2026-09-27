import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/models/filter_settings.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/widgets/smart_filter_dialog.dart';

void main() {
  late VlcProvider provider;

  setUp(() {
    // Il provider, appena costruito, va a leggere le preferenze: senza il
    // mock il canale del plugin non esiste e il test muore subito.
    SharedPreferences.setMockInitialValues({});
    provider = VlcProvider();
  });

  tearDown(() => provider.dispose());

  /// Pumpa l'app con un pulsante che apre il dialogo dei filtri.
  Future<void> apriDialogo(
    WidgetTester tester, {
    FilterSettings? last,
    bool previewMode = true,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<VlcProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) =>
                        SmartFilterDialog(last: last, previewMode: previewMode),
                  ),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  /// Il controller del campo con la data etichetta.
  ///
  /// I campi non sono nell'ordine in cui si leggono: nell'albero vengono
  /// prima quelli da includere e poi quelli da escludere, quindi conviene
  /// rivolgersi a loro per nome invece che per posizione.
  TextEditingController campo(WidgetTester tester, String etichetta) {
    final trovato = find.ancestor(
      of: find.text(etichetta),
      matching: find.byType(TextField),
    );
    return tester
        .widget<EditableText>(
          find.descendant(of: trovato, matching: find.byType(EditableText)),
        )
        .controller;
  }

  group('vita dei campi di testo', () {
    testWidgets('i controller vengono distrutti alla chiusura', (tester) async {
      // Nella versione precedente i nove TextEditingController nascevano nel
      // metodo che apriva il dialogo e non venivano mai distrutti: ogni
      // apertura ne lasciava nove in giro.
      //
      // Un controller distrutto si riconosce: aggiungere un listener su un
      // ChangeNotifier gia' distrutto lancia.
      await apriDialogo(tester);

      final campi = tester.widgetList<EditableText>(find.byType(EditableText));
      expect(campi.length, 9, reason: 'il dialogo ha nove campi');
      final controller = campi.first.controller;

      // Chiude il dialogo e lascia che venga smontato.
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();

      expect(
        () => controller.addListener(() {}),
        throwsA(isA<Error>()),
        reason: 'il controller doveva essere distrutto col dialogo',
      );
    });

    testWidgets('i campi ripartono dagli ultimi filtri', (tester) async {
      await apriDialogo(
        tester,
        last: FilterSettings(
          genres: ['Azione', 'Commedia'],
          excludedGenres: ['Horror'],
          limit: 25,
          ratingMin: 7.5,
        ),
      );

      expect(campo(tester, 'Generi').text, 'Azione, Commedia');
      expect(campo(tester, 'Escludi Generi').text, 'Horror');
      expect(campo(tester, 'Limite Risultati').text, '25');

      // La soglia non e' un campo di testo ma uno slider. L'etichetta non
      // serve: Flutter la mostra solo mentre si trascina, quindi si verifica
      // il valore dello slider.
      expect(tester.widget<Slider>(find.byType(Slider)).value, 7.5);
    });
  });

  group('applicazione dei filtri', () {
    testWidgets('"Genera" salva i filtri letti dai campi', (tester) async {
      await apriDialogo(tester);

      // Compila i campi come farebbe l'utente, con spazi attorno e una voce
      // vuota in coda: il risultato deve essere pulito.
      campo(tester, 'Generi').text = ' Azione , Commedia ,';
      campo(tester, 'Anni').text = '2023, 2024';
      campo(tester, 'Limite Risultati').text = '7';

      await tester.tap(find.text('Genera'));
      await tester.pumpAndSettle();

      final salvati = provider.lastFilterSettings;
      expect(salvati, isNotNull, reason: 'i filtri devono essere salvati');
      // Gli spazi attorno alle voci spariscono e le voci vuote vengono via:
      // e' il comportamento che aveva la funzione `split` di prima.
      expect(salvati!.genres, ['Azione', 'Commedia']);
      expect(salvati.years, ['2023', '2024']);
      expect(salvati.limit, 7);
    });

    testWidgets('"Azzera" svuota i campi e i filtri salvati', (tester) async {
      await apriDialogo(
        tester,
        last: FilterSettings(genres: ['Azione'], limit: 25),
      );

      await tester.tap(find.text('Azzera'));
      await tester.pumpAndSettle();

      expect(campo(tester, 'Generi').text, isEmpty);
      expect(campo(tester, 'Escludi Generi').text, isEmpty);
      expect(
        campo(tester, 'Limite Risultati').text,
        '10',
        reason: 'il limite torna al valore di default',
      );
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
      expect(provider.lastFilterSettings, isNull);
    });
  });
}
