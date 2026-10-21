import 'voice_command.dart';
import 'voice_language.dart';

/// Traduce la frase trascritta dal motore vocale in un comando.
///
/// Il riconoscimento non usa una grammatica vincolata: le frasi arrivano
/// approssimate, quindi il lavoro e' svolto su parole chiave e sinonimi.
/// L'ordine delle regole conta, dalla piu' specifica alla piu' generica.
class VoiceCommandParser {
  VoiceCommandParser._();

  /// Analizza [transcript] e restituisce il comando riconosciuto, se
  /// esiste. Con [language] si sceglie il dizionario dei comandi.
  static VoiceCommand? parse(
    String transcript, {
    required VoiceLanguage language,
  }) {
    final text = normalize(transcript);
    if (text.isEmpty) return null;

    final tokens = text.split(' ');
    final rules = language == VoiceLanguage.italian
        ? _italianRules
        : _englishRules;

    for (final rule in rules) {
      if (_isExcluded(tokens, rule)) continue;
      if (!_matchesTrigger(tokens, rule)) continue;

      final int? number = switch (rule.numberMode) {
        _NumberMode.none => null,
        _NumberMode.optional || _NumberMode.required =>
          extractNumber(text, language: language) ?? rule.defaultNumber,
      };

      if (rule.numberMode == _NumberMode.required && number == null) continue;

      return VoiceCommand(type: rule.type, number: number);
    }

    return null;
  }

  /// Ripulisce la frase: minuscole, niente accenti, niente punteggiatura.
  static String normalize(String text) {
    const accents = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'å': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };

    final buffer = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final mapped = accents[char] ?? char;
      final isAllowed =
          (mapped.codeUnitAt(0) >= 0x61 && mapped.codeUnitAt(0) <= 0x7a) ||
          (mapped.codeUnitAt(0) >= 0x30 && mapped.codeUnitAt(0) <= 0x39) ||
          mapped == ' ';
      buffer.write(isAllowed ? mapped : ' ');
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Cerca un numero nella frase normalizzata: prima le cifre, poi le
  /// parole scritte per esteso.
  static int? extractNumber(
    String normalizedText, {
    required VoiceLanguage language,
  }) {
    final digits = RegExp(r'\d+').firstMatch(normalizedText);
    if (digits != null) {
      final value = int.tryParse(digits.group(0)!);
      if (value != null) return value;
    }

    return _extractWordNumber(
      normalizedText.split(' '),
      _wordNumbers(language),
    );
  }

  static int? _extractWordNumber(List<String> tokens, Map<String, int> words) {
    for (var i = 0; i < tokens.length; i++) {
      final value = words[tokens[i]];
      if (value == null) continue;

      // In inglese "twenty five" vale 25: la decina e' seguita da un'unita'.
      if (value >= 20 && value % 10 == 0 && i + 1 < tokens.length) {
        final unit = words[tokens[i + 1]];
        if (unit != null && unit >= 1 && unit <= 9) return value + unit;
      }

      return value;
    }
    return null;
  }

  static Map<String, int> _wordNumbers(VoiceLanguage language) {
    if (language == VoiceLanguage.english) return _englishNumbers;
    return _italianNumbers;
  }

  /// Numeri in italiano. Sono esclusi i termini ambigui ("uno", "una", "sei",
  /// "sette", "otto", "nove"), che compaiono troppo spesso nel parlato.
  static const Map<String, int> _italianNumbers = <String, int>{
    'due': 2,
    'tre': 3,
    'quattro': 4,
    'cinque': 5,
    'dieci': 10,
    'quindici': 15,
    'venti': 20,
    'trenta': 30,
    'quaranta': 40,
    'cinquanta': 50,
    'sessanta': 60,
    'settanta': 70,
    'ottanta': 80,
    'novanta': 90,
    'cento': 100,
  };

  static const Map<String, int> _englishNumbers = <String, int>{
    'zero': 0,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'thirteen': 13,
    'fourteen': 14,
    'fifteen': 15,
    'sixteen': 16,
    'seventeen': 17,
    'eighteen': 18,
    'nineteen': 19,
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
    'hundred': 100,
  };

  static bool _matchesTrigger(List<String> tokens, _Rule rule) {
    for (final trigger in rule.triggers) {
      final parts = trigger.split(' ');
      if (_containsSequence(tokens, parts)) return true;
    }
    return false;
  }

  static bool _isExcluded(List<String> tokens, _Rule rule) {
    for (final exclude in rule.excludes) {
      if (_containsSequence(tokens, exclude.split(' '))) return true;
    }
    return false;
  }

  static bool _containsSequence(List<String> tokens, List<String> sequence) {
    if (sequence.isEmpty || sequence.length > tokens.length) return false;
    for (var i = 0; i + sequence.length <= tokens.length; i++) {
      var matched = true;
      for (var j = 0; j < sequence.length; j++) {
        if (tokens[i + j] != sequence[j]) {
          matched = false;
          break;
        }
      }
      if (matched) return true;
    }
    return false;
  }

  static const List<_Rule> _italianRules = <_Rule>[
    _Rule(
      type: VoiceCommandType.vlcVolumeSet,
      triggers: <String>['volume'],
      numberMode: _NumberMode.required,
      excludes: <String>[
        'su',
        'giu',
        'giù',
        'alza',
        'abbassa',
        'aumenta',
        'diminuisci',
      ],
    ),
    _Rule(
      type: VoiceCommandType.vlcVolumeUp,
      triggers: <String>['alza'],
    ),
    _Rule(
      type: VoiceCommandType.vlcVolumeDown,
      triggers: <String>['abbassa'],
    ),
    _Rule(
      type: VoiceCommandType.playlistRandom,
      triggers: <String>['casuale'],
      numberMode: _NumberMode.optional,
    ),
    _Rule(
      type: VoiceCommandType.playlistRecent,
      triggers: <String>['recenti'],
      numberMode: _NumberMode.optional,
    ),
    _Rule(
      type: VoiceCommandType.playlistPlay,
      triggers: <String>['avvia'],
    ),
    _Rule(
      type: VoiceCommandType.vlcNext,
      triggers: <String>['successiva'],
    ),
    _Rule(
      type: VoiceCommandType.vlcPrevious,
      triggers: <String>['precedente'],
    ),
    _Rule(
      type: VoiceCommandType.vlcSeekForward,
      triggers: <String>['avanti'],
      numberMode: _NumberMode.optional,
      defaultNumber: 30,
    ),
    _Rule(
      type: VoiceCommandType.vlcSeekBackward,
      triggers: <String>['indietro'],
      numberMode: _NumberMode.optional,
      defaultNumber: 30,
    ),
    _Rule(
      type: VoiceCommandType.vlcPause,
      triggers: <String>['pausa'],
    ),
    _Rule(
      type: VoiceCommandType.vlcResume,
      triggers: <String>['continua', 'riprendi'],
    ),
    _Rule(
      type: VoiceCommandType.playerStop,
      triggers: <String>['stop'],
    ),
  ];

  static const List<_Rule> _englishRules = <_Rule>[
    _Rule(
      type: VoiceCommandType.vlcVolumeSet,
      triggers: <String>['volume'],
      numberMode: _NumberMode.required,
      excludes: <String>[
        'up',
        'down',
        'raise',
        'lower',
        'increase',
        'decrease',
        'louder',
        'quieter',
      ],
    ),
    _Rule(
      type: VoiceCommandType.vlcVolumeUp,
      triggers: <String>['up'],
    ),
    _Rule(
      type: VoiceCommandType.vlcVolumeDown,
      triggers: <String>['down'],
    ),
    _Rule(
      type: VoiceCommandType.playlistRandom,
      triggers: <String>['random', 'shuffle'],
      numberMode: _NumberMode.optional,
    ),
    _Rule(
      type: VoiceCommandType.playlistRecent,
      triggers: <String>['recent', 'latest'],
      numberMode: _NumberMode.optional,
    ),
    _Rule(
      type: VoiceCommandType.playlistPlay,
      triggers: <String>['start'],
    ),
    _Rule(
      type: VoiceCommandType.vlcNext,
      triggers: <String>['next'],
    ),
    _Rule(
      type: VoiceCommandType.vlcPrevious,
      triggers: <String>['previous'],
    ),
    _Rule(
      type: VoiceCommandType.vlcSeekForward,
      triggers: <String>['forward'],
      numberMode: _NumberMode.optional,
      defaultNumber: 30,
    ),
    _Rule(
      type: VoiceCommandType.vlcSeekBackward,
      triggers: <String>['backward'],
      numberMode: _NumberMode.optional,
      defaultNumber: 30,
    ),
    _Rule(type: VoiceCommandType.vlcPause, triggers: <String>['pause']),
    _Rule(
      type: VoiceCommandType.vlcResume,
      triggers: <String>['resume', 'continue', 'play', 'unpause'],
    ),
    _Rule(type: VoiceCommandType.playerStop, triggers: <String>['stop']),
  ];
}

/// Come la regola deve comportarsi con i numeri presenti nella frase.
enum _NumberMode {
  /// Il comando non usa numeri.
  none,

  /// Il numero e' facoltativo: se manca si usa quello predefinito.
  optional,

  /// Il numero e' necessario: senza, la regola non scatta.
  required,
}

class _Rule {
  const _Rule({
    required this.type,
    required this.triggers,
    this.numberMode = _NumberMode.none,
    this.defaultNumber,
    this.excludes = const <String>[],
  });

  final VoiceCommandType type;

  /// Frasi che fanno scattare la regola.
  final List<String> triggers;

  final _NumberMode numberMode;

  /// Numero usato quando la regola e' facoltativa e la frase non ne contiene.
  final int? defaultNumber;

  /// Frasi che annullano la regola.
  final List<String> excludes;
}
