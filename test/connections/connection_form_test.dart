import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/constants/app_constants.dart';
import 'package:vlc_remote_flutter/widgets/connections/connection_form.dart';

/// Monta il modulo con sette controller e restituisce sia l'albero sia i
/// controller, perche' i test hanno bisogno di scriverci dentro.
class _Modulo {
  _Modulo() {
    controller = ConnectionForm(
      formKey: formKey,
      nameController: nome,
      ipController: ip,
      portController: porta,
      vlcPasswordController: password,
      myPlaylistIpController: mpIp,
      myPlaylistPortController: mpPorta,
      myPlaylistSecretKeyController: mpChiave,
      isEditing: isEditing,
      onCancel: () => annullato = true,
      onSave: () async => salvato = true,
    );
  }

  final formKey = GlobalKey<FormState>();
  late final ConnectionForm controller;

  final nome = TextEditingController();
  final ip = TextEditingController();
  final porta = TextEditingController();
  final password = TextEditingController();
  final mpIp = TextEditingController();
  final mpPorta = TextEditingController();
  final mpChiave = TextEditingController();

  bool isEditing = false;
  bool salvato = false;
  bool annullato = false;

  void dispose() {
    nome.dispose();
    ip.dispose();
    porta.dispose();
    password.dispose();
    mpIp.dispose();
    mpPorta.dispose();
    mpChiave.dispose();
  }
}

void main() {
  late _Modulo modulo;

  Future<void> apri(WidgetTester tester) async {
    modulo = _Modulo();
    addTearDown(modulo.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: modulo.controller)),
    );
    await tester.pumpAndSettle();
  }

  group('campi', () {
    testWidgets('ci sono sette campi', (tester) async {
      await apri(tester);

      expect(find.byType(TextFormField), findsNWidgets(7));
    });

    testWidgets('il pulsante cambia scritta fra nuovo e modifica', (
      tester,
    ) async {
      await apri(tester);
      expect(find.text('Salva e Connetti'), findsOneWidget);
      expect(find.text('Salva Modifiche'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionForm(
              formKey: modulo.formKey,
              nameController: modulo.nome,
              ipController: modulo.ip,
              portController: modulo.porta,
              vlcPasswordController: modulo.password,
              myPlaylistIpController: modulo.mpIp,
              myPlaylistPortController: modulo.mpPorta,
              myPlaylistSecretKeyController: modulo.mpChiave,
              isEditing: true,
              onCancel: modulo.controller.onCancel,
              onSave: modulo.controller.onSave,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salva Modifiche'), findsOneWidget);
      expect(find.text('Salva e Connetti'), findsNothing);
    });
  });

  group('validazione dei campi obbligatori', () {
    testWidgets('il nome vuoto e\' obbligatorio', (tester) async {
      await apri(tester);
      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(find.text('Inserisci un nome'), findsOneWidget);
      expect(modulo.salvato, isFalse);
    });

    testWidgets('l\'indirizzo vuoto ha un messaggio suo, non "non valido"', (
      tester,
    ) async {
      // Dire "Indirizzo IP non valido" a chi non ha ancora scritto niente
      // descrive un problema che non si e' ancora verificato, e non dice
      // cosa manca.
      await apri(tester);
      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(find.text('Inserisci un indirizzo IP'), findsOneWidget);
      expect(find.text('Indirizzo IP non valido'), findsNothing);
    });

    testWidgets('l\'indirizzo scritto male viene rifiutato', (tester) async {
      await apri(tester);
      modulo.nome.text = 'Casa';
      modulo.ip.text = '999.1.1.1';
      modulo.porta.text = '8080';

      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(find.text('Indirizzo IP non valido'), findsOneWidget);
      expect(modulo.salvato, isFalse);
    });

    testWidgets('la porta fuori intervallo viene rifiutata', (tester) async {
      await apri(tester);
      modulo.nome.text = 'Casa';
      modulo.ip.text = '192.168.1.15';
      modulo.porta.text = '70000';

      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(find.text('Porta non valida (1-65535)'), findsOneWidget);
      expect(modulo.salvato, isFalse);
    });

    testWidgets('un form completo passa senza errori', (tester) async {
      await apri(tester);
      modulo.nome.text = 'Casa';
      modulo.ip.text = '192.168.1.15';
      modulo.porta.text = '8080';

      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(modulo.salvato, isTrue);
    });
  });

  group('campi facoltativi di MyPlaylist', () {
    testWidgets('restano vuoti senza bloccare il salvataggio', (tester) async {
      // MyPlaylist non e' sempre sulla stessa macchina: vuoto vuol dire
      // "non configurato", non "dimenticato di compilare".
      await apri(tester);
      modulo.nome.text = 'Casa';
      modulo.ip.text = '192.168.1.15';
      modulo.porta.text = '8080';

      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(modulo.salvato, isTrue);
      expect(find.text('Indirizzo IP MyPlaylist non valido'), findsNothing);
    });

    testWidgets('se scritti male vengono rifiutati lo stesso', (tester) async {
      await apri(tester);
      modulo.nome.text = 'Casa';
      modulo.ip.text = '192.168.1.15';
      modulo.porta.text = '8080';
      modulo.mpIp.text = 'non-e-un-indirizzo';

      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(find.text('Indirizzo IP MyPlaylist non valido'), findsOneWidget);
      expect(modulo.salvato, isFalse);
    });
  });

  group('secret key', () {
    testWidgets('una chiave oltre i 32 caratteri viene rifiutata', (
      tester,
    ) async {
      // Oltre i 32 caratteri i byte in eccesso verrebbero persi in
      // silenzio nel troncamento a 32, producendo una chiave diversa da
      // quella pensata e un errore di decifratura che non spiega niente.
      await apri(tester);
      modulo.nome.text = 'Casa';
      modulo.ip.text = '192.168.1.15';
      modulo.porta.text = '8080';
      modulo.mpChiave.text = 'a' * 33;

      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(
        find.text('La chiave non puo\' superare 32 caratteri'),
        findsOneWidget,
      );
      expect(modulo.salvato, isFalse);
    });

    testWidgets('una chiave piu\' corta di 32 caratteri passa', (tester) async {
      // Sotto i 32 caratteri la chiave viene completata con zeri, e
      // MyPlaylist fa lo stesso: i due lati restano d'accordo, quindi non
      // c'e' motivo di rifiutarla.
      await apri(tester);
      modulo.nome.text = 'Casa';
      modulo.ip.text = '192.168.1.15';
      modulo.porta.text = '8080';
      modulo.mpChiave.text = 'chiave_corta';

      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(modulo.salvato, isTrue);
    });

    testWidgets('una chiave di 32 caratteri passa', (tester) async {
      await apri(tester);
      modulo.nome.text = 'Casa';
      modulo.ip.text = '192.168.1.15';
      modulo.porta.text = '8080';
      modulo.mpChiave.text = 'a' * 32;

      await tester.tap(find.text('Salva e Connetti'));
      await tester.pumpAndSettle();

      expect(modulo.salvato, isTrue);
    });

    testWidgets('resta nascosta finche\' non si preme l\'occhio', (
      tester,
    ) async {
      await apri(tester);
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);

      // Il campo della chiave e' l'ultimo dei sette, ed e' l'unico che
      // cambia: `obscureText` sta sul `EditableText` che `TextFormField`
      // costruisce, non sul form field stesso.
      final campo = tester
          .widgetList<EditableText>(find.byType(EditableText))
          .last;
      expect(campo.obscureText, isFalse);
    });
  });

  testWidgets('annulla chiama l\'azione di annullare', (tester) async {
    await apri(tester);

    await tester.tap(find.text('Annulla'));
    expect(modulo.annullato, isTrue);
  });

  testWidgets('i valori di default restano quelli dichiarati', (tester) async {
    // Non serve a niente da solo: serve a far notare che i default del modulo
    // sono scelti, non casuali.
    await apri(tester);
    modulo.porta.text = '${AppConstants.defaultVlcHttpPort}';
    await tester.pumpAndSettle();

    expect(modulo.porta.text, '8000');
    expect(modulo.porta.text, '${AppConstants.defaultVlcHttpPort}');
  });
}
