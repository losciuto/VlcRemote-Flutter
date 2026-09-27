import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../exceptions/vlc_exceptions.dart';
import '../models/vlc_connection.dart';
import 'secure_storage_service.dart';
import '../utils/app_logger.dart';

/// Servizio per gestire le connessioni VLC salvate
class ConnectionService {
  /// Tag usato nei log di questo servizio.
  static const String _tag = 'ConnectionService';
  static const String _connectionsKey = 'vlc_connections';
  static const String _lastConnectionKey = 'last_connection_id';

  SharedPreferences? _prefs;
  final SecretStore _secrets;

  /// Connessioni gia' lette, per non rileggere e riparseggiare il JSON a ogni
  /// chiamata: [getConnections] e' chiamato da dieci posti e ognuno, per ogni
  /// connessione, interrogava anche lo store sicuro.
  ///
  /// La copia restituita ai chiamanti e' sempre nuova: quasi tutti la
  /// modificano (sort, removeWhere, add), quindi restituire l'istanza in cache
  /// farebbe finire quelle modifiche dentro la cache.
  List<VlcConnection>? _cache;

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

      // Salva tutte le connessioni: i segreti vanno nello store sicuro.
      // L'await è obbligatorio: `return _persist(...)` dentro un try non
      // cattura l'errore asincrono, quindi il fallimento del negozio sicuro
      // sfuggirebbe e arriverebbe come eccezione non gestita.
      return await _persist(connections);
    } catch (e) {
      AppLogger.w(_tag, 'Errore durante il salvataggio della connessione', e);
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
    final cached = _cache;
    if (cached != null) return List.of(cached);

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
          AppLogger.w(_tag, 'Connessione scartata perché illeggibile', e);
        }
      }

      if (hasLegacySecrets) {
        // La migrazione è un tentativo, non un prerequisito: se lo store sicuro
        // non è disponibile i segreti restano nel JSON e l'app continua a
        // funzionare. Lasciare che l'eccezione arrivi al catch esterno
        // restituirebbe una lista vuota, cioè tutte le connessioni sparite.
        try {
          await _persist(connections);
          AppLogger.i(
            _tag,
            'Segreti migrati in storage sicuro '
            '(${connections.length} connessioni)',
          );
        } on SecretStoreException catch (e) {
          // Segnaliamo l'esito, ma l'errore non risale: la migrazione e' un
          // tentativo e l'app continua a funzionare anche in chiaro.
          AppLogger.w(
            _tag,
            'Migrazione dei segreti non riuscita, i segreti restano '
            'in chiaro nelle preferenze',
            e,
          );
        }
      }

      _cache = List.of(connections);
      return List.of(connections);
    } catch (e) {
      AppLogger.w(_tag, 'Errore durante il caricamento delle connessioni', e);
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
  ///
  /// L'ordine è deliberato e va mantenuto: i segreti si scrivono **prima** del
  /// JSON, quindi se lo store sicuro fallisce la [SecretStoreException]
  /// interrompe il metodo e il JSON non viene mai riscritto. Senza questo
  /// ordine, su una macchina senza keyring la migrazione cancellerebbe i
  /// segreti da SharedPreferences senza essere riuscita a spostarli: la
  /// password dell'utente sparirebbe senza lasciare traccia.
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

    final ok = await _prefs!.setString(_connectionsKey, jsonEncode(jsonList));
    // La cache vale solo per cio' che e' stato scritto davvero: se la scrittura
    // fallisce, la prossima lettura deve tornare ai dati su disco.
    if (ok) {
      _cache = List.of(connections);
    } else {
      _cache = null;
    }
    return ok;
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

      return await _persist(connections);
    } catch (e) {
      AppLogger.w(_tag, 'Errore durante l\'eliminazione della connessione', e);
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

      return await _persist(connections);
    } catch (e) {
      AppLogger.w(
        _tag,
        'Errore durante l\'aggiornamento della data di utilizzo',
        e,
      );
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

      return await _persist(connections);
    } catch (e) {
      AppLogger.w(_tag, 'Errore durante il toggle del preferito', e);
      return false;
    }
  }

  /// Salva l'ID dell'ultima connessione utilizzata
  Future<bool> saveLastConnectionId(String id) async {
    try {
      await updateLastUsed(id);
      return await _prefs!.setString(_lastConnectionKey, id);
    } catch (e) {
      AppLogger.w(
        _tag,
        'Errore durante il salvataggio dell\'ultima connessione',
        e,
      );
      return false;
    }
  }

  /// Ottiene l'ID dell'ultima connessione utilizzata
  Future<String?> getLastConnectionId() async {
    try {
      return _prefs!.getString(_lastConnectionKey);
    } catch (e) {
      AppLogger.w(
        _tag,
        'Errore durante il caricamento dell\'ultima connessione',
        e,
      );
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
      AppLogger.w(
        _tag,
        'Errore durante il caricamento dell\'ultima connessione',
        e,
      );
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
      // Le connessioni non sono piu' su disco: la cache va svuotata, o
      // `getConnections` continuerebbe a restituirle come se esistessero.
      _cache = null;
      return true;
    } catch (e) {
      AppLogger.w(_tag, 'Errore durante la pulizia delle connessioni', e);
      return false;
    }
  }
}
