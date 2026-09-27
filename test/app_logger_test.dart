import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/utils/app_logger.dart';

/// Esegue [corpo] in una zona che trattiene i `print` invece di
/// mostrarli.
///
/// Non si puo' intercettare passando per `debugPrint`: in un test il `print`
/// viene gia' raccolto dalla zona di flutter_test, quindi il logger scrive a
/// schermo e `debugPrint` non vede nulla.
List<String> cattura(void Function() corpo) {
  final righe = <String>[];
  runZoned(
    corpo,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => righe.add(line),
    ),
  );
  return righe;
}

void main() {
  late LogLevel minLevelOriginale;

  setUp(() => minLevelOriginale = AppLogger.minLevel);
  tearDown(() => AppLogger.minLevel = minLevelOriginale);

  group('soglia', () {
    test('di default i messaggi debug non vengono scritti', () {
      // Il default in debug e' `info`: i messaggi da diagnostica restano
      // spenti, altrimenti tornano a essere un costo invisibile in ogni
      // percorso caldo che li usa.
      AppLogger.minLevel = LogLevel.info;

      final righe = cattura(() {
        AppLogger.d('VlcService', 'riga per voce');
        AppLogger.i('VlcService', 'evento normale');
      });

      expect(righe.where((l) => l.contains('riga per voce')), isEmpty);
      expect(righe.where((l) => l.contains('evento normale')), hasLength(1));
    });

    test(
      'isDebugEnabled segue la soglia, cosi il testo non viene costruito',
      () {
        // E' il punto di tutto: con il solo controllo dentro il logger
        // l'interpolazione avverrebbe comunque a ogni iterazione del ciclo.
        AppLogger.minLevel = LogLevel.info;
        expect(AppLogger.isDebugEnabled, isFalse);

        AppLogger.minLevel = LogLevel.debug;
        expect(AppLogger.isDebugEnabled, isTrue);
      },
    );

    test('warning passa, error passa sempre', () {
      AppLogger.minLevel = LogLevel.error;

      final righe = cattura(() {
        AppLogger.w('VlcService', 'anomalia gestita');
        AppLogger.e('VlcService', 'errore vero');
      });

      expect(righe.where((l) => l.contains('anomalia gestita')), isEmpty);
      expect(righe.where((l) => l.contains('errore vero')), hasLength(1));
    });

    test('il livello disattivato silenzia anche i messaggi successivi', () {
      AppLogger.minLevel = LogLevel.debug;

      final righe = cattura(() => AppLogger.d('VlcService', 'dettaglio'));

      expect(righe, hasLength(1));
      expect(righe.single, contains('dettaglio'));
      expect(righe.single, contains('VlcService'));
    });
  });

  test("l'eccezione viene riportata nel messaggio", () {
    AppLogger.minLevel = LogLevel.warning;

    final righe = cattura(
      () => AppLogger.w(
        'VlcService',
        'timeout in attesa',
        TimeoutException('5 s'),
      ),
    );

    expect(righe, hasLength(1));
    expect(righe.single, contains('timeout in attesa'));
    expect(righe.single, contains('5 s'));
  });

  test('senza eccezione il messaggio resta come e', () {
    AppLogger.minLevel = LogLevel.warning;

    final righe = cattura(() => AppLogger.warning('disconnesso'));

    expect(righe, hasLength(1));
    expect(righe.single, contains('disconnesso'));
  });
}
