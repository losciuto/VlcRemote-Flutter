import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/vlc_connection.dart';
import '../models/vlc_status.dart';
import '../models/playlist_item.dart';
import '../services/vlc_service.dart';
import '../services/connection_service.dart';
import '../services/my_playlist_service.dart';

/// Provider per gestire lo stato dell'applicazione VLC Remote
class VlcProvider with ChangeNotifier {
  final VlcService _vlcService = VlcService();
  final ConnectionService _connectionService = ConnectionService();
  final MyPlaylistService _myPlaylistService = MyPlaylistService();

  VlcConnection? _currentConnection;
  VlcStatus _status = VlcStatus();
  List<PlaylistItem> _playlist = [];
  bool _isConnecting = false;
  String? _errorMessage;

  // MyPlaylist state
  bool _isMyPlaylistBusy = false;
  String _myPlaylistMessage = '';
  List<Map<String, dynamic>> _proposedPlaylist = [];
  List<String> _pendingPlaylist = [];

  Timer? _statusUpdateTimer;

  // Getters
  VlcConnection? get currentConnection => _currentConnection;
  VlcStatus get status => _status;
  List<PlaylistItem> get playlist => _playlist;
  bool get isConnected => _vlcService.isConnected;
  bool get isConnecting => _isConnecting;
  String? get errorMessage => _errorMessage;

  bool get isMyPlaylistBusy => _isMyPlaylistBusy;
  String get myPlaylistMessage => _myPlaylistMessage; // Changed to non-nullable
  List<Map<String, dynamic>> get proposedPlaylist => _proposedPlaylist;
  List<String> get pendingPlaylist => _pendingPlaylist; // New getter
  bool get isMyPlaylistConfigured => 
      _currentConnection?.myPlaylistIp != null && 
      _currentConnection?.myPlaylistSecretKey != null;

  VlcProvider() {
    _init();
  }

  /// Inizializza il provider
  Future<void> _init() async {
    await _connectionService.init();

    // Prova a connettersi all'ultima connessione utilizzata
    final lastConnection = await _connectionService.getLastConnection();
    if (lastConnection != null) {
      await connect(lastConnection);
    }
  }

  /// Connette a un server VLC
  Future<bool> connect(VlcConnection connection) async {
    _isConnecting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _vlcService.connect(
        connection.ipAddress,
        connection.port,
      );

      if (success) {
        _currentConnection = connection;
        await _connectionService.saveLastConnectionId(connection.id);

        // Avvia l'aggiornamento periodico dello stato
        _startStatusUpdates();

        // Carica la playlist
        await refreshPlaylist();

        _isConnecting = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            'Impossibile connettersi a ${connection.ipAddress}:${connection.port}';
        _isConnecting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Errore di connessione: $e';
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  /// Disconnette dal server VLC
  Future<void> disconnect() async {
    _stopStatusUpdates();
    await _vlcService.disconnect();
    _currentConnection = null;
    _status = VlcStatus();
    _playlist = [];
    _errorMessage = null;
    notifyListeners();
  }

  /// Avvia gli aggiornamenti periodici dello stato
  void _startStatusUpdates() {
    _stopStatusUpdates();

    // Aggiorna lo stato ogni 500ms
    _statusUpdateTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (!_vlcService.isConnected) {
        timer.cancel();
        _statusUpdateTimer = null;
        return;
      }
      try {
        await _updateStatus();
      } catch (e) {
        print('[VlcProvider] Errore aggiornamento stato: $e');
        timer.cancel();
        _statusUpdateTimer = null;
      }
    });
  }

  /// Ferma gli aggiornamenti periodici dello stato
  void _stopStatusUpdates() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = null;
  }

  /// Aggiorna lo stato corrente di VLC
  Future<void> _updateStatus() async {
    // Evitiamo sovrapposizioni di _updateStatus stesso se il mutex del service è occupato
    if (_isConnecting) return; // Non aggiornare mentre connettiamo
    
    try {
      final newStatus = await _vlcService.getStatus();
      
      // Se non siamo connessi o il risultato è vuoto (fallback), ignora
      if (!_vlcService.isConnected) return;

      // LOGICA DI EREDITÀ DELLO STATO (State Guarding)
      // Preveniamo che errori temporanei di comunicazione o parsing resettino la UI
      
      int? mergedVolume = newStatus.volume ?? _status.volume;
      
      int mergedTotalTime = newStatus.totalTime;
      // Se la nuova durata è 0 o sospetta, manteniamo la vecchia se ragionevole
      if (mergedTotalTime <= 0 && _status.totalTime > 0) {
        mergedTotalTime = _status.totalTime;
      }

      int mergedCurrentTime = newStatus.currentTime;
      // Se il tempo corrente scatta a 0 ma siamo sicuri di stare ancora riproducendo lo stesso video
      // e non abbiamo appena chiesto uno stop, manteniamo l'ultimo tempo noto.
      if (mergedCurrentTime == 0 && _status.currentTime > 0 && 
          newStatus.isPlaying && newStatus.nowPlaying == _status.nowPlaying) {
        mergedCurrentTime = _status.currentTime;
      }

      _status = newStatus.copyWith(
        volume: mergedVolume,
        totalTime: mergedTotalTime,
        currentTime: mergedCurrentTime,
      );
      
      notifyListeners();
    } catch (e) {
      print('[VlcProvider] Errore durante l\'aggiornamento dello stato: $e');
    }
  }

  /// Aggiorna manualmente lo stato
  Future<void> refreshStatus() async {
    await _updateStatus();
  }

  /// Aggiorna la playlist
  Future<void> refreshPlaylist() async {
    try {
      print('[VlcProvider] Aggiornamento playlist in corso...');
      final newPlaylist = await _vlcService.getPlaylist();
      _playlist = newPlaylist;
      print(
        '[VlcProvider] Playlist aggiornata: ${newPlaylist.length} elementi',
      );
      notifyListeners();
    } catch (e) {
      print('Errore durante l\'aggiornamento della playlist: $e');
    }
  }

  // ==================== COMANDI DI CONTROLLO ====================

  Future<void> play() async {
    await _vlcService.play();
    await Future.delayed(Duration(milliseconds: 200));
    await _updateStatus();
  }

  Future<void> pause() async {
    await _vlcService.pause();
    await Future.delayed(Duration(milliseconds: 200));
    await _updateStatus();
  }

  Future<void> stop() async {
    await _vlcService.stop();
    await Future.delayed(Duration(milliseconds: 200));
    await _updateStatus();
  }

  Future<void> previous() async {
    await _vlcService.previous();
    await Future.delayed(Duration(milliseconds: 500));
    await _updateStatus();
  }

  Future<void> next() async {
    await _vlcService.next();
    await Future.delayed(Duration(milliseconds: 500));
    await _updateStatus();
  }

  Future<void> volumeUp() async {
    await _vlcService.volumeUp(3);
    await Future.delayed(Duration(milliseconds: 200));
    await _updateStatus();
  }

  Future<void> volumeDown() async {
    await _vlcService.volumeDown(3);
    await Future.delayed(Duration(milliseconds: 200));
    await _updateStatus();
  }

  Future<void> setVolume(double volume) async {
    // Normalizza da 0-100 a 0-256 per VLC
    // Usiamo 256.0 come riferimento per il 100%
    final vlcVolume = (volume * 256.0 / 100.0).round();
    await _vlcService.setVolume(vlcVolume);
    
    // Aggiornamento ottimistico locale per UI fluida
    _status = _status.copyWith(volume: volume.toInt());
    notifyListeners();
  }

  Future<void> toggleFullscreen() async {
    await _vlcService.fullscreen();
  }

  Future<void> seek(int seconds) async {
    await _vlcService.seek(seconds);
    await Future.delayed(Duration(milliseconds: 200));
    await _updateStatus();
  }

  Future<void> seekTo(double seconds) async {
    // Non permettere seek se la durata è sconosciuta
    if (_status.totalTime <= 0) return;
    
    final intSec = seconds.toInt().clamp(0, _status.totalTime);
    await _vlcService.seek(intSec);
    
    // Aggiornamento ottimistico
    _status = _status.copyWith(currentTime: intSec);
    notifyListeners();
  }

  Future<void> goToPlaylistItem(int index) async {
    // Recupera l'elemento dalla playlist usando l'indice visuale
    if (index >= 0 && index < _playlist.length) {
      final item = _playlist[index];
      print('[VlcProvider] Go to item: ${item.title} (ID: ${item.id})');
      await _vlcService.goto(item.id); // Usa l'ID interno di VLC
      await Future.delayed(Duration(milliseconds: 500));
      await _updateStatus();
    }
  }

  void clearPendingPlaylist() {
    _pendingPlaylist = [];
    notifyListeners();
  }

  // ==================== COMANDI MYPLAYLIST ====================

  Future<void> mpGenerateRandom({int? count, bool preview = false}) async {
    await _runMpCommand(
      () => _myPlaylistService.generateRandom(
        _currentConnection!.myPlaylistIp!,
        _currentConnection!.myPlaylistPort ?? 8080,
        _currentConnection!.myPlaylistSecretKey!,
        count: count,
        preview: preview,
      ),
      isPreview: preview,
    );
  }

  Future<void> mpGenerateRecent({int? count, bool preview = false}) async {
    await _runMpCommand(
      () => _myPlaylistService.generateRecent(
        _currentConnection!.myPlaylistIp!,
        _currentConnection!.myPlaylistPort ?? 8080,
        _currentConnection!.myPlaylistSecretKey!,
        count: count,
        preview: preview,
      ),
      isPreview: preview,
    );
  }

  Future<void> mpGenerateFiltered({
    List<String>? genres,
    List<String>? years,
    double? minRating,
    List<String>? actors,
    List<String>? directors,
    int? limit,
    bool preview = false,
  }) async {
    await _runMpCommand(
      () => _myPlaylistService.generateFiltered(
        _currentConnection!.myPlaylistIp!,
        _currentConnection!.myPlaylistPort ?? 8080,
        _currentConnection!.myPlaylistSecretKey!,
        genres: genres,
        years: years,
        minRating: minRating,
        actors: actors,
        directors: directors,
        limit: limit,
        preview: preview,
      ),
      isPreview: preview,
    );
  }

  Future<void> mpPlay() async {
    await _runMpCommand(() => _myPlaylistService.play(
          _currentConnection!.myPlaylistIp!,
          _currentConnection!.myPlaylistPort ?? 8080,
          _currentConnection!.myPlaylistSecretKey!,
        ));
  }

  Future<void> mpStop() async {
    await _runMpCommand(() => _myPlaylistService.stop(
          _currentConnection!.myPlaylistIp!,
          _currentConnection!.myPlaylistPort ?? 8080,
          _currentConnection!.myPlaylistSecretKey!,
        ));
  }

  Future<void> _runMpCommand(
    Future<Map<String, dynamic>> Function() commandFn, {
    bool isPreview = false,
  }) async {
    if (!isMyPlaylistConfigured) {
      _myPlaylistMessage = 'MyPlaylist non configurato';
      notifyListeners();
      return;
    }

    _isMyPlaylistBusy = true;
    _myPlaylistMessage = '';
    notifyListeners();

    try {
      final result = await commandFn();
      final status = result['status'] as String?;
      final message = result['message'] as String? ?? 'Nessuna risposta dal server';
      
      _myPlaylistMessage = message;
      
      // Se è una preview, salviamo la lista dei titoli
      if (isPreview && result['playlist'] != null) {
        final list = result['playlist'] as List;
        _pendingPlaylist = list.map((item) => item['title'] as String).toList();
      } else {
        _pendingPlaylist = [];
      }
      
      // Se il comando è andato a buon fine (status 'success') e NON era una preview, riconnettiamoci
      if (status == 'success' && !isPreview) {
        _myPlaylistMessage = 'OK: $message - Riconnessione VLC...';
        notifyListeners();

        // Attendi che VLC si avvii
        await Future.delayed(Duration(seconds: 2)); 
        
        if (_currentConnection != null) {
          await connect(_currentConnection!);
        }
        
        // Aggiorna sempre la playlist dopo un comando MyPlaylist andato a buon fine
        await Future.delayed(const Duration(milliseconds: 500));
        await refreshPlaylist();
      }
    } catch (e) {
      _myPlaylistMessage = 'ERRORE: $e';
    } finally {
      _isMyPlaylistBusy = false;
      notifyListeners();
    }
  }

  // ==================== GESTIONE CONNESSIONI ====================

  Future<List<VlcConnection>> getSavedConnections() async {
    return await _connectionService.getConnectionsSortedByLastUsed();
  }

  Future<List<VlcConnection>> getFavoriteConnections() async {
    return await _connectionService.getFavoriteConnections();
  }

  Future<bool> saveConnection(VlcConnection connection) async {
    return await _connectionService.saveConnection(connection);
  }

  Future<bool> deleteConnection(String id) async {
    return await _connectionService.deleteConnection(id);
  }

  Future<bool> toggleFavorite(String id) async {
    return await _connectionService.toggleFavorite(id);
  }

  @override
  void dispose() {
    _stopStatusUpdates();
    _vlcService.dispose();
    super.dispose();
  }
}
