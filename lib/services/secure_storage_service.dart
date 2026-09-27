import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../exceptions/vlc_exceptions.dart';

/// Archivio chiave-valore per i segreti.
///
/// Espone un'interfaccia minimale [SecretStore] così i test possono usare
/// un'implementazione in memoria senza dipendere dalla piattaforma.
///
/// I valori sono messi in cache: la chiave hardware del dispositivo non va
/// interrogata a ogni lettura, e `ConnectionService.getConnections()` legge più
/// segreti per ogni connessione.
abstract class SecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Implementazione su storage sicuro del sistema operativo.
///
/// - Android / iOS: Keychain / Android Keystore
/// - Linux: libsecret (GNOME Keyring) — richiede `libsecret-1-dev`
/// - Windows / macOS: credential store del sistema
class SecureStorageService implements SecretStore {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  final Map<String, String> _cache = {};

  @override
  Future<String?> read(String key) async {
    if (_cache.containsKey(key)) return _cache[key];

    try {
      final value = await _storage.read(key: key);
      if (value != null) _cache[key] = value;
      return value;
    } catch (e) {
      // Qui l'errore non viene propagato, e la scelta e' deliberata: una
      // lettura impossibile e' indistinguibile, per l'utente, da un segreto
      // assente, e in entrambi i casi la conseguenza e' la stessa (chiedere
      // la password). Propagare l'eccezione qui farebbe fallire il caricamento
      // di tutte le connessioni su una macchina senza keyring, invece di
      // lasciare usare quelle che non hanno segreti.
      //
      // Il rovescio e' che un errore di lettura non viene distinto da un
      // segreto mancante: per questo _cache non viene toccata, cosi' un valore
      // gia' letto nella sessione resta disponibile anche se il keyring si
      // blocca a meta' esecuzione.
      print('[SecureStorage] Lettura di "$key" non riuscita: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      // La cache viene aggiornata solo dopo il successo: aggornarla prima
      // farebbe leggere come salvato un segreto che sul disco non c'e', e la
      // sessione apparentemente funzionante finirebbe al primo riavvio.
      throw SecretStoreException(
        key: key,
        operation: 'write',
        message: 'scrittura non riuscita, il segreto NON e\' stato salvato',
        originalError: e,
      );
    }
    _cache[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw SecretStoreException(
        key: key,
        operation: 'delete',
        message: 'cancellazione non riuscita, il segreto e\' ancora presente',
        originalError: e,
      );
    }
    _cache.remove(key);
  }
}

/// Store in memoria, per i test.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  /// Se è vero, [write] fallisce come farebbe uno store sicuro non
  /// raggiungibile. Serve a provare che i chiamanti gestiscono il fallimento.
  bool failWrites = false;

  /// Come [failWrites], per [delete].
  bool failDeletes = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw SecretStoreException(
        key: key,
        operation: 'write',
        message: 'scrittura non riuscita, il segreto NON e\' stato salvato',
      );
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDeletes) {
      throw SecretStoreException(
        key: key,
        operation: 'delete',
        message: 'cancellazione non riuscita, il segreto e\' ancora presente',
      );
    }
    values.remove(key);
  }
}

/// Chiave dello store sicuro per un dato segreto di una connessione.
///
/// Il prefisso mantiene gli spazi dei nomi separati e rende evidente, leggendo
/// le chiavi, che cosa è un segreto e che cosa è un dato normale.
String secretKeyFor(String connectionId, String secretName) =>
    'vlcremote_${connectionId}_$secretName';
