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

/// Lo storage sicuro di sistema non ha potuto salvare o cancellare un segreto.
///
/// Va propagata invece che essere stampata: se la scrittura fallisce e il chiamante
/// non lo viene a sapere, la connessione risulta salvata mentre il segreto non
/// esiste da nessuna parte, e al rilancio l'app chiede la password come se
/// l'utente non l'avesse mai inserita.
class SecretStoreException extends VlcRemoteException {
  final String key;
  final String operation;

  SecretStoreException({
    required this.key,
    required this.operation,
    String message = 'operazione di storage sicuro non riuscita',
    dynamic originalError,
  }) : super('Segreto "$key": $message ($operation)', originalError);
}
