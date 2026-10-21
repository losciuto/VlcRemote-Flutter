import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/services/settings_service.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command_executor.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command_service.dart';
import 'package:vlc_remote_flutter/widgets/voice_panel.dart';

/// Esecutore finto: il pannello non deve parlare con VLC.
class _FakeExecutor implements VoiceCommandExecutor {
  @override
  Future<bool> execute(VoiceCommand command) async => true;
}

Future<VoiceCommandService> _buildService() async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  final voice = VoiceCommandService(
    executor: _FakeExecutor(),
    settingsService: settings,
  );
  await voice.init();
  return voice;
}

Future<void> _apriPannello(WidgetTester tester) async {
  final voice = await _buildService();

  await tester.pumpWidget(
    ChangeNotifierProvider<VoiceCommandService>.value(
      value: voice,
      child: const MaterialApp(home: Scaffold(body: VoicePanel())),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('Il pannello dei comandi vocali si renderizza', (
    WidgetTester tester,
  ) async {
    await _apriPannello(tester);

    expect(find.text('Comandi vocali'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.text('Livello del microfono'), findsNothing);
  });

  testWidgets('Il bottone del microfono e\' attivo anche senza modello', (
    WidgetTester tester,
  ) async {
    await _apriPannello(tester);

    final IconButton button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.mic),
        matching: find.byType(IconButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('Il tap sul microfono avvia la preparazione del motore', (
    WidgetTester tester,
  ) async {
    final voice = await _buildService();

    await tester.pumpWidget(
      ChangeNotifierProvider<VoiceCommandService>.value(
        value: voice,
        child: const MaterialApp(home: Scaffold(body: VoicePanel())),
      ),
    );
    await tester.pump();

    expect(voice.status.name, 'idle');

    await tester.tap(find.byIcon(Icons.mic));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Il tap deve raggiungere il servizio: la preparazione parte anche se il
    // modello non e' ancora pronto.
    expect(voice.status.name, isNot('idle'));
  });

  testWidgets('Il livello del microfono viene mostrato', (
    WidgetTester tester,
  ) async {
    final voice = await _buildService();

    await tester.pumpWidget(
      ChangeNotifierProvider<VoiceCommandService>.value(
        value: voice,
        child: const MaterialApp(home: Scaffold(body: VoicePanel())),
      ),
    );
    await tester.pump();

    expect(find.text('-- dB'), findsOneWidget);

    voice.inputLevel.value = -18;
    await tester.pump();

    expect(find.text('-18 dB'), findsOneWidget);
  });
}
