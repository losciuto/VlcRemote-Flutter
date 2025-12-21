/// Eccezioni personalizzate per l'applicazione VLC Remote
library;

/// Eccezione generica per errori di VLC Remote
class VlcRemoteException implements Exception {
  final String message;
  final dynamic originalError;

  VlcRemoteException(this.message, [this.originalError]);

  @override
  String toString() =>
      'VlcRemoteException: $message${originalError != null ? '\nOriginal: $originalError' : ''}';
}

/// Eccezione di connessione
class VlcConnectionException extends VlcRemoteException {
  final String host;
  final int port;

  VlcConnectionException(
    this.host,
    this.port,
    String message, [
    dynamic originalError,
  ]) : super('Connessione a $host:$port non riuscita: $message', originalError);
}

/// Eccezione di timeout
class VlcTimeoutException extends VlcRemoteException {
  final Duration timeout;

  VlcTimeoutException(this.timeout, String message, [dynamic originalError])
    : super('Timeout ($timeout): $message', originalError);
}

/// Eccezione di comando non valido
class VlcInvalidCommandException extends VlcRemoteException {
  final String command;

  VlcInvalidCommandException(
    this.command,
    String message, [
    dynamic originalError,
  ]) : super('Comando non valido "$command": $message', originalError);
}

/// Eccezione di parsing della risposta
class VlcParsingException extends VlcRemoteException {
  final String response;

  VlcParsingException(this.response, String message, [dynamic originalError])
    : super(
        'Errore nel parsing della risposta: $message\nRisposta: $response',
        originalError,
      );
}
