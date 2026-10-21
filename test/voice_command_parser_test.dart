import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command_parser.dart';
import 'package:vlc_remote_flutter/services/voice/voice_language.dart';

VoiceCommand? parseIt(String text) =>
    VoiceCommandParser.parse(text, language: VoiceLanguage.italian);

VoiceCommand? parseEn(String text) =>
    VoiceCommandParser.parse(text, language: VoiceLanguage.english);

void main() {
  group('Normalizzazione', () {
    test('togli accenti, maiuscole e punteggiatura', () {
      expect(
        VoiceCommandParser.normalize('Pausa, per favore!'),
        'pausa per favore',
      );
      expect(VoiceCommandParser.normalize('  AVANTI  '), 'avanti');
      expect(VoiceCommandParser.normalize("l'anno"), 'l anno');
    });
  });

  group('Comandi in italiano', () {
    test('playlist casuale, con e senza numero', () {
      expect(parseIt('casuale')?.type, VoiceCommandType.playlistRandom);
      expect(parseIt('casuale 10')?.number, 10);
      expect(parseIt('casuale dieci')?.number, 10);
    });

    test('playlist recenti', () {
      expect(
        parseIt('recenti')?.type,
        VoiceCommandType.playlistRecent,
      );
    });

    test('avvia la playlist e\' distinta da riprendi', () {
      expect(
        parseIt('avvia la playlist')?.type,
        VoiceCommandType.playlistPlay,
      );
      expect(parseIt('riproduci'), isNull);
      expect(parseIt('continua')?.type, VoiceCommandType.vlcResume);
      expect(parseIt('riprendi')?.type, VoiceCommandType.vlcResume);
    });

    test('controllo del player esterno', () {
      expect(parseIt('pausa')?.type, VoiceCommandType.vlcPause);
      expect(parseIt('successiva')?.type, VoiceCommandType.vlcNext);
      expect(parseIt('precedente')?.type, VoiceCommandType.vlcPrevious);
      expect(parseIt('stop')?.type, VoiceCommandType.playerStop);
    });

    test('volume', () {
      expect(parseIt('alza')?.type, VoiceCommandType.vlcVolumeUp);
      expect(
        parseIt('abbassa')?.type,
        VoiceCommandType.vlcVolumeDown,
      );
      expect(parseIt('volume 50')?.number, 50);
      expect(parseIt('volume 50')?.type, VoiceCommandType.vlcVolumeSet);
    });

    test('alza con numero resta un aumento', () {
      final command = parseIt('alza di 10');
      expect(command?.type, VoiceCommandType.vlcVolumeUp);
    });

    test('seek avanti e indietro', () {
      expect(
        parseIt('avanti 30 secondi')?.type,
        VoiceCommandType.vlcSeekForward,
      );
      expect(parseIt('avanti 30 secondi')?.number, 30);
      expect(
        parseIt('indietro 15 secondi')?.type,
        VoiceCommandType.vlcSeekBackward,
      );
      expect(parseIt('avanti')?.number, 30);
    });
  });

  group('Comandi in inglese', () {
    test('playlist', () {
      expect(parseEn('random')?.type, VoiceCommandType.playlistRandom);
      expect(parseEn('random 5')?.number, 5);
      expect(parseEn('recent')?.type, VoiceCommandType.playlistRecent);
      expect(parseEn('start playlist')?.type, VoiceCommandType.playlistPlay);
    });

    test('controllo del player esterno', () {
      expect(parseEn('pause')?.type, VoiceCommandType.vlcPause);
      expect(parseEn('resume')?.type, VoiceCommandType.vlcResume);
      expect(parseEn('play')?.type, VoiceCommandType.vlcResume);
      expect(parseEn('next')?.type, VoiceCommandType.vlcNext);
      expect(parseEn('previous')?.type, VoiceCommandType.vlcPrevious);
      expect(parseEn('stop')?.type, VoiceCommandType.playerStop);
    });

    test('volume', () {
      expect(parseEn('up')?.type, VoiceCommandType.vlcVolumeUp);
      expect(parseEn('down')?.type, VoiceCommandType.vlcVolumeDown);
      expect(parseEn('volume 80')?.number, 80);
      expect(parseEn('volume 80')?.type, VoiceCommandType.vlcVolumeSet);
    });

    test('seek', () {
      expect(
        parseEn('forward 20 seconds')?.type,
        VoiceCommandType.vlcSeekForward,
      );
      expect(parseEn('forward 20 seconds')?.number, 20);
      expect(
        parseEn('backward 10 seconds')?.type,
        VoiceCommandType.vlcSeekBackward,
      );
    });

    test('numeri scritti per esteso', () {
      expect(parseEn('volume seventy five')?.number, 75);
    });
  });

  group('Frasi non riconosciute', () {
    test('restituiscono null', () {
      expect(parseIt('che tempo fa'), isNull);
      expect(parseEn('what is the weather like'), isNull);
      expect(parseIt(''), isNull);
    });
  });
}
