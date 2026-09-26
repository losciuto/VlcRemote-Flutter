import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
      // Su alcune piattaforme (Linux senza keyring, Web senza HTTPS) la
      // lettura può fallire. Non è un caso da interrompere: si prosegue
      // senza segreto e l'utente dovrà reinserirlo.
      print('[SecureStorage] Lettura di "$key" non riuscita: $e');
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    _cache[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      print('[SecureStorage] Scrittura di "$key" non riuscita: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    _cache.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (e) {
      print('[SecureStorage] Cancellazione di "$key" non riuscita: $e');
    }
  }
}

/// Store in memoria, per i test.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Chiave dello store sicuro per un dato segreto di una connessione.
///
/// Il prefisso mantiene gli spazi dei nomi separati e rende evidente, leggendo
/// le chiavi, che cosa è un segreto e che cosa è un dato normale.
String secretKeyFor(String connectionId, String secretName) =>
    'vlcremote_${connectionId}_$secretName';
