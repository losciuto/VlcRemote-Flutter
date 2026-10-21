import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vlc_remote_flutter/services/settings_service.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command_executor.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command_service.dart';

/// Esecutore finto: registra i comandi e restituisce un esito deciso dal
/// test, cosi' il motore si puo' provare senza toccare VLC.
class _FakeExecutor implements VoiceCommandExecutor {
  final List<VoiceCommand> commands = <VoiceCommand>[];
  bool result = true;

  @override
  Future<bool> execute(VoiceCommand command) async {
    commands.add(command);
    return result;
  }
}

Future<VoiceCommandService> _buildService(_FakeExecutor executor) async {
  SharedPreferences.setMockInitialValues({});
  final settings = SettingsService();
  final voice = VoiceCommandService(
    executor: executor,
    settingsService: settings,
  );
  await voice.init();
  return voice;
}

void main() {
  group('Normalizzazione degli id dei microfoni', () {
    test('toglie le virgolette che mette PulseAudio', () {
      expect(
        VoiceCommandService.normalizeDeviceId(
          '"alsa_input.usb-Trust_GXT.mono-fallback"',
        ),
        'alsa_input.usb-Trust_GXT.mono-fallback',
      );
    });

    test('lascia intatti gli id senza virgolette', () {
      expect(VoiceCommandService.normalizeDeviceId('default'), 'default');
    });

    test('toglie anche gli spazi attorno', () {
      expect(VoiceCommandService.normalizeDeviceId('  "abc"  '), 'abc');
    });

    test('non taglia le virgolette interne', () {
      expect(VoiceCommandService.normalizeDeviceId('a"b'), 'a"b');
    });
  });

  group('Esecuzione dei comandi', () {
    test('una frase riconosciuta arriva all\'esecutore', () async {
      final executor = _FakeExecutor();
      final voice = await _buildService(executor);

      await voice.handleTranscript('pausa');

      expect(executor.commands, hasLength(1));
      expect(executor.commands.first.type, VoiceCommandType.vlcPause);
      expect(voice.history, hasLength(1));
      expect(voice.history.first.succeeded, isTrue);
    });

    test('il numero arriva con il comando', () async {
      final executor = _FakeExecutor();
      final voice = await _buildService(executor);

      await voice.handleTranscript('volume 40');

      expect(executor.commands.first.type, VoiceCommandType.vlcVolumeSet);
      expect(executor.commands.first.number, 40);
    });

    test('una frase non riconosciuta non esegue nulla', () async {
      final executor = _FakeExecutor();
      final voice = await _buildService(executor);

      await voice.handleTranscript('che tempo fa');

      expect(executor.commands, isEmpty);
      expect(voice.history.first.feedback, VoiceFeedback.notRecognized);
    });

    test('un comando non eseguibile viene segnalato', () async {
      final executor = _FakeExecutor()..result = false;
      final voice = await _buildService(executor);

      await voice.handleTranscript('traccia successiva');

      expect(voice.history.first.succeeded, isFalse);
      expect(voice.history.first.feedback, VoiceFeedback.notExecuted);
    });

    test('la cronologia tiene gli ultimi comandi', () async {
      final executor = _FakeExecutor();
      final voice = await _buildService(executor);

      for (int i = 0; i < VoiceCommandService.maxHistory + 5; i++) {
        await voice.handleTranscript('pausa');
      }

      expect(voice.history, hasLength(VoiceCommandService.maxHistory));
    });

    test('la cronologia si svuota', () async {
      final executor = _FakeExecutor();
      final voice = await _buildService(executor);

      await voice.handleTranscript('pausa');
      expect(voice.history, isNotEmpty);

      voice.clearHistory();
      expect(voice.history, isEmpty);
    });
  });
}
