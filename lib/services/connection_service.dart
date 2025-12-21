import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vlc_connection.dart';

/// Servizio per gestire le connessioni VLC salvate
class ConnectionService {
  static const String _connectionsKey = 'vlc_connections';
  static const String _lastConnectionKey = 'last_connection_id';
  
  SharedPreferences? _prefs;

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
      
      // Salva tutte le connessioni
      final jsonList = connections.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_connectionsKey, jsonString);
    } catch (e) {
      print('Errore durante il salvataggio della connessione: $e');
      return false;
    }
  }

  /// Ottiene tutte le connessioni salvate
  Future<List<VlcConnection>> getConnections() async {
    try {
      final jsonString = _prefs!.getString(_connectionsKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => VlcConnection.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Errore durante il caricamento delle connessioni: $e');
      return [];
    }
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
      connections.removeWhere((c) => c.id == id);
      
      final jsonList = connections.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_connectionsKey, jsonString);
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
      
      connections[index] = connections[index].copyWith(lastUsed: DateTime.now());
      
      final jsonList = connections.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_connectionsKey, jsonString);
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
      
      final jsonList = connections.map((c) => c.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      return await _prefs!.setString(_connectionsKey, jsonString);
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
        orElse: () => connections.isNotEmpty ? connections.first : throw Exception('No connections'),
      );
    } catch (e) {
      print('Errore durante il caricamento dell\'ultima connessione: $e');
      return null;
    }
  }

  /// Pulisce tutte le connessioni salvate
  Future<bool> clearAllConnections() async {
    try {
      await _prefs!.remove(_connectionsKey);
      await _prefs!.remove(_lastConnectionKey);
      return true;
    } catch (e) {
      print('Errore durante la pulizia delle connessioni: $e');
      return false;
    }
  }
}
