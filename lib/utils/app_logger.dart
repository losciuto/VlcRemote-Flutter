import 'package:flutter/foundation.dart';

/// Livelli di log, dal piu' interno al piu' importante.
enum LogLevel {
  /// Dettagli interni: si accendono solo quando servono davvero.
  debug,

  /// Eventi normali del ciclo di vita.
  info,

  /// Situazioni anomale che l'app ha gestito.
  warning,

  /// Errori che propagano all'utente o lasciano l'app in uno stato strano.
  error,
}

/// Logger dell'app, con livelli.
///
/// Sostituisce i `print` sparsi nel codice. Il punto non e' la forma dei
/// messaggi: e' che in un ciclo (per esempio la lettura di una playlist) un
/// `print` per elemento costa piu' del lavoro che lo circonda, e su una
/// playlist da seimila voci faceva perdere quasi trecento millisecondi sul main
/// isolate.
///
/// I messaggi di livello `debug` sono spenti di default, anche in debug, per
///che non diventino un costo invisibile. Per accenderli durante
/// l'indagine su un problema:
///
/// ```dart
/// AppLogger.minLevel = LogLevel.debug;
/// ```
///
/// Nei rilasci parte da `warning`: informazioni e debug non servono a
/// nessuno e non devono crescere con la dimensione dei dati.
class AppLogger {
  AppLogger._();

  static const String _defaultTag = 'App';

  /// Soglia sotto la quale i messaggi vengono scartati.
  static LogLevel minLevel = kDebugMode ? LogLevel.info : LogLevel.warning;

  /// Vero se un messaggio di livello `debug` verrebbe scritto.
  ///
  /// Serve a evitare di costruire il testo di un messaggio che poi non
  /// verrebbe scritto: con un `print` l'interpolazione avviene comunque,
  /// anche quando il ramo dentro il ciclo non serve a nulla.
  static bool get isDebugEnabled => minLevel.index <= LogLevel.debug.index;

  /// Dettaglio interno, spento di default.
  static void d(String tag, String message, [Object? error]) =>
      _write(LogLevel.debug, tag, error == null ? message : '$message: $error');

  /// Evento normale del ciclo di vita.
  static void i(String tag, String message) =>
      _write(LogLevel.info, tag, message);

  /// Situazione anomala gestita.
  static void w(String tag, String message, [Object? error]) => _write(
    LogLevel.warning,
    tag,
    error == null ? message : '$message: $error',
  );

  /// Errore da propagare.
  static void e(String tag, String message, [Object? error]) =>
      _write(LogLevel.error, tag, error == null ? message : '$message: $error');

  /// Scrive se il livello supera la soglia.
  static void _write(LogLevel level, String tag, String message) {
    if (level.index < minLevel.index) return;
    // ignore: avoid_print
    print('[$level] [$tag] $message');
  }

  /// Log senza tag esplicito, per codice sparse.
  static void info(String message) => i(_defaultTag, message);

  static void warning(String message) => w(_defaultTag, message);

  static void error(String message, [Object? cause]) =>
      e(_defaultTag, message, cause);
}
