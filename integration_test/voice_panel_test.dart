import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:vlc_remote_flutter/main.dart' as app;
import 'package:vlc_remote_flutter/services/voice/voice_command_service.dart';
import 'package:vlc_remote_flutter/widgets/voice_panel.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Il pannello dei comandi vocali si apre e il microfono parte', (
    WidgetTester tester,
  ) async {
    app.main();
    await tester.pumpAndSettle();

    // Il bottone del microfono sta nella barra in alto.
    final Finder micButton = find.byIcon(Icons.mic_none);
    expect(micButton, findsOneWidget);

    await tester.tap(micButton);
    await tester.pumpAndSettle();

    // Il pannello si apre.
    expect(find.byType(VoicePanel), findsOneWidget);
    expect(find.text('Comandi vocali'), findsOneWidget);

    // Il bottone del microfono dentro il pannello e' attivo e avvia il
    // motore: se il modello non e' pronto la preparazione parte comunque.
    final Finder panelMic = find.byIcon(Icons.mic);
    expect(panelMic, findsOneWidget);

    final VoiceCommandService voice = Provider.of<VoiceCommandService>(
      tester.element(find.byType(VoicePanel)),
      listen: false,
    );
    // Il modello e' gia' in locale: all'apertura del pannello il motore si
    // prepara da solo e il microfono diventa utilizzabile.
    expect(voice.status.name, 'ready');

    await tester.tap(panelMic);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Il tap ha raggiunto il servizio: l'ascolto e' partito.
    expect(voice.status.name, 'listening');

    // Il pulsante diventa quello di arresto.
    expect(find.byIcon(Icons.stop_circle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.stop_circle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(voice.status.name, 'ready');
  });
}
