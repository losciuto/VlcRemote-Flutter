import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vlc_connection.dart';
import 'secure_storage_service.dart';

/// Servizio per gestire le connessioni VLC salvate
class ConnectionService {
  static const String _connectionsKey = 'vlc_connections';
  static const String _lastConnectionKey = 'last_connection_id';

  SharedPreferences? _prefs;
  final SecretStore _secrets;

  /// I campi che non devono mai finire in SharedPreferences: su Android quel
  /// file finisce in chiaro nella sandbox dell'app e nel backup automatico.
  static const List<String> _secretFields = [
    'vlcPassword',
    'myPlaylistSecretKey',
  ];

  ConnectionService({SecretStore? secrets})
    : _secrets = secrets ?? SecureStorageService();

  /// Inizializza il servizio
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Salva una nuova connessione
  Future<bool> saveConnection(VlcConnection connection) async {
    try {
      final connections = await getConnections();

      // Rimuovi la connessione esistente con lo stesso ID se presente
      connections.removeWhere((c) => c.id == connection.id);

      // Aggiungi la nuova connessione
      connections.add(connection);

      // Salva tutte le connessioni: i segreti vanno nello store sicuro
      return _persist(connections);
    } catch (e) {
      print('Errore durante il salvataggio della connessione: $e');
      return false;
    }
  }

  /// Ottiene tutte le connessioni salvate
  ///
  /// I record illeggibili vengono scartati uno a uno, con un avviso: prima un
  /// singolo cast errato faceva fallire l'intera lista e il `catch` restituiva
  /// un array vuoto, facendo perdere tutte le connessioni all'utente senza
  /// alcun avviso.
  Future<List<VlcConnection>> getConnections() async {
    try {
      final jsonString = _prefs!.getString(_connectionsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      final connections = <VlcConnection>[];
      var hasLegacySecrets = false;

      for (final entry in jsonList) {
        try {
          final json = entry as Map<String, dynamic>;
          final connection = VlcConnection.fromJson(json);

          // I segreti salvati da una versione precedente sono ancora nel JSON:
          // li spostiamo nello store sicuro e li togliamo da SharedPreferences.
          if (_secretFields.any(
            (field) =>
                json[field] is String && (json[field] as String).isNotEmpty,
          )) {
            hasLegacySecrets = true;
          }

          connections.add(await _withSecrets(connection, fromJson: json));
        } catch (e) {
          print('Connessione scartata perché illeggibile: $e');
        }
      }

      if (hasLegacySecrets) {
        await _persist(connections);
        print(
          '[ConnectionService] Segreti migrati in storage sicuro '
          '(${connections.length} connessioni)',
        );
      }

      return connections;
    } catch (e) {
      print('Errore durante il caricamento delle connessioni: $e');
      return [];
    }
  }

  /// Ricostruisce una connessione con i segreti letti dallo store sicuro.
  ///
  /// [fromJson] è il record originale: se contiene ancora i segreti in chiaro,
  /// viene usato come fallback, così la configurazione non si perde se lo store
  /// sicuro non è disponibile su quella piattaforma.
  Future<VlcConnection> _withSecrets(
    VlcConnection connection, {
    Map<String, dynamic>? fromJson,
  }) async {
    final legacy = <String, String>{};
    for (final field in _secretFields) {
      final value = fromJson?[field];
      if (value is String && value.isNotEmpty) legacy[field] = value;
    }

    final vlcPassword =
        await _secrets.read(secretKeyFor(connection.id, 'vlc_password')) ??
        legacy['vlcPassword'];
    final myPlaylistSecretKey =
        await _secrets.read(
          secretKeyFor(connection.id, 'my_playlist_secret'),
        ) ??
        legacy['myPlaylistSecretKey'];

    if (connection.vlcPassword == vlcPassword &&
        connection.myPlaylistSecretKey == myPlaylistSecretKey) {
      return connection;
    }
    return connection.copyWith(
      vlcPassword: vlcPassword,
      myPlaylistSecretKey: myPlaylistSecretKey,
    );
  }

  /// Scrive i segreti nello store sicuro e persiste il resto in chiaro.
  Future<bool> _persist(List<VlcConnection> connections) async {
    for (final connection in connections) {
      for (final entry in _secretEntries(connection)) {
        if (entry.value.isEmpty) {
          await _secrets.delete(entry.key);
        } else {
          await _secrets.write(entry.key, entry.value);
        }
      }
    }

    final jsonList = connections
        .map(
          (c) =>
              c.toJson()..removeWhere((key, _) => _secretFields.contains(key)),
        )
        .toList();
    return _prefs!.setString(_connectionsKey, jsonEncode(jsonList));
  }

  /// Coppie chiave-valore dei segreti di una connessione.
  static Iterable<MapEntry<String, String>> _secretEntries(
    VlcConnection connection,
  ) sync* {
    yield MapEntry(
      secretKeyFor(connection.id, 'vlc_password'),
      connection.vlcPassword ?? '',
    );
    yield MapEntry(
      secretKeyFor(connection.id, 'my_playlist_secret'),
      connection.myPlaylistSecretKey ?? '',
    );
  }

  /// Ottiene le connessioni ordinate per ultima utilizzo
  Future<List<VlcConnection>> getConnectionsSortedByLastUsed() async {
    final connections = await getConnections();
    connections.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return connections;
  }

  /// Ottiene le connessioni preferite
  Future<List<VlcConnection>> getFavoriteConnections() async {
    final connections = await getConnections();
    return connections.where((c) => c.isFavorite).toList();
  }

  /// Elimina una connessione
  Future<bool> deleteConnection(String id) async {
    try {
      final connections = await getConnections();
      final removed = connections.where((c) => c.id == id).toList();
      connections.removeWhere((c) => c.id == id);

      // I segreti della connessione eliminata non devono restare orfani.
      for (final connection in removed) {
        for (final entry in _secretEntries(connection)) {
          await _secrets.delete(entry.key);
        }
      }

      return _persist(connections);
    } catch (e) {
      print('Errore durante l\'eliminazione della connessione: $e');
      return false;
    }
  }

  /// Aggiorna l'ultima data di utilizzo di una connessione
  Future<bool> updateLastUsed(String id) async {
    try {
      final connections = await getConnections();
      final index = connections.indexWhere((c) => c.id == id);

      if (index == -1) return false;

      connections[index] = connections[index].copyWith(
        lastUsed: DateTime.now(),
      );

      return _persist(connections);
    } catch (e) {
      print('Errore durante l\'aggiornamento della data di utilizzo: $e');
      return false;
    }
  }

  /// Toggle dello stato preferito di una connessione
  Future<bool> toggleFavorite(String id) async {
    try {
      final connections = await getConnections();
      final index = connections.indexWhere((c) => c.id == id);

      if (index == -1) return false;

      connections[index] = connections[index].copyWith(
        isFavorite: !connections[index].isFavorite,
      );

      return _persist(connections);
    } catch (e) {
      print('Errore durante il toggle del preferito: $e');
      return false;
    }
  }

  /// Salva l'ID dell'ultima connessione utilizzata
  Future<bool> saveLastConnectionId(String id) async {
    try {
      await updateLastUsed(id);
      return await _prefs!.setString(_lastConnectionKey, id);
    } catch (e) {
      print('Errore durante il salvataggio dell\'ultima connessione: $e');
      return false;
    }
  }

  /// Ottiene l'ID dell'ultima connessione utilizzata
  Future<String?> getLastConnectionId() async {
    try {
      return _prefs!.getString(_lastConnectionKey);
    } catch (e) {
      print('Errore durante il caricamento dell\'ultima connessione: $e');
      return null;
    }
  }

  /// Ottiene l'ultima connessione utilizzata
  Future<VlcConnection?> getLastConnection() async {
    try {
      final lastId = await getLastConnectionId();
      if (lastId == null) return null;

      final connections = await getConnections();
      return connections.firstWhere(
        (c) => c.id == lastId,
        orElse: () => connections.isNotEmpty
            ? connections.first
            : throw Exception('No connections'),
      );
    } catch (e) {
      print('Errore durante il caricamento dell\'ultima connessione: $e');
      return null;
    }
  }

  /// Pulisce tutte le connessioni salvate
  Future<bool> clearAllConnections() async {
    try {
      for (final connection in await getConnections()) {
        for (final entry in _secretEntries(connection)) {
          await _secrets.delete(entry.key);
        }
      }
      await _prefs!.remove(_connectionsKey);
      await _prefs!.remove(_lastConnectionKey);
      return true;
    } catch (e) {
      print('Errore durante la pulizia delle connessioni: $e');
      return false;
    }
  }
}
