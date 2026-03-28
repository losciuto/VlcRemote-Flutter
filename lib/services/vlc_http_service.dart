import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/vlc_status.dart';
import '../models/playlist_item.dart';

/// Servizio per comunicare con VLC tramite interfaccia HTTP
/// Richiede che VLC sia configurato con una password.
class VlcHttpService {
  String? _host;
  int? _port;
  String? _password;

  bool get isConfigured => _host != null && _port != null && _password != null && _password!.isNotEmpty;

  void configure(String host, int port, String password) {
    _host = host;
    _port = port;
    _password = password;
  }

  Map<String, String> _getHeaders() {
    final auth = 'Basic ${base64Encode(utf8.encode(':$_password'))}';
    return {
      'Authorization': auth,
    };
  }

  Uri _getUri(String path) {
    return Uri.parse('http://$_host:$_port$path');
  }

  /// Ottiene lo stato corrente di VLC in formato XML e lo parsa in VlcStatus
  Future<VlcStatus?> getStatus() async {
    if (!isConfigured) return null;

    try {
      final response = await http.get(
        _getUri('/requests/status.xml'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final root = document.rootElement;

        final state = root.findElements('state').first.innerText;
        final time = int.tryParse(root.findElements('time').first.innerText) ?? 0;
        final length = int.tryParse(root.findElements('length').first.innerText) ?? 0;
        final volume = int.tryParse(root.findElements('volume').first.innerText) ?? 0;
        final fullscreen = root.findElements('fullscreen').first.innerText == '1';

        // Estrazione titolo e metadati (trama, voto, poster)
        String title = 'Nessun video in riproduzione';
        String? plot;
        String? rating;
        String? posterUrl;
        try {
          final infoNodes = root.findAllElements('info');
          for (final node in infoNodes) {
            final name = node.getAttribute('name')?.toLowerCase();
            if (name == 'filename' && title == 'Nessun video in riproduzione') {
              title = node.innerText;
            } else if (name == 'title') {
              title = node.innerText;
            } else if (name == 'description' || name == 'comment' || name == 'synopsis' || name == 'comments') {
              if (node.innerText.isNotEmpty) plot = node.innerText;
            } else if (name == 'rating' || name == 'vote') {
              if (node.innerText.isNotEmpty) rating = node.innerText;
            } else if (name == 'poster_url' || name == 'artwork' || name == 'poster') {
              if (node.innerText.isNotEmpty) posterUrl = node.innerText;
            }
          }
        } catch (_) {}

        return VlcStatus(
          nowPlaying: title,
          currentTime: time,
          totalTime: length,
          volume: (volume * 100 / 256).round().clamp(0, 100),
          isPlaying: state == 'playing',
          isFullscreen: fullscreen,
          plot: plot,
          rating: rating,
          posterUrl: posterUrl,
        );
      }
    } catch (e) {
      print('[VlcHttpService] Errore getStatus: $e');
    }
    return null;
  }

  /// Ottiene la playlist corrente di VLC in formato XML
  Future<List<PlaylistItem>> getPlaylist() async {
    if (!isConfigured) return [];

    try {
      final response = await http.get(
        _getUri('/requests/playlist.xml'),
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final playlistItems = <PlaylistItem>[];
        
        // VLC organizza la playlist in nodi e foglie
        final leaves = document.findAllElements('leaf');
        int index = 0;
        
        for (final leaf in leaves) {
          final id = int.tryParse(leaf.getAttribute('id') ?? '') ?? 0;
          final name = leaf.getAttribute('name') ?? 'Senza titolo';
          final duration = leaf.getAttribute('duration');
          final isCurrent = leaf.getAttribute('current') == 'current';

          playlistItems.add(PlaylistItem(
            id: id,
            index: index,
            title: name,
            duration: duration,
            isPlaying: isCurrent,
          ));
          index++;
        }
        return playlistItems;
      }
    } catch (e) {
      print('[VlcHttpService] Errore getPlaylist: $e');
    }
    return [];
  }

  /// Invia un comando generico (play, pause, etc.)
  Future<bool> sendCommand(String command, {Map<String, String>? params}) async {
    if (!isConfigured) return false;

    try {
      final queryParams = {'command': command};
      if (params != null) queryParams.addAll(params);
      
      final uri = Uri.http('$_host:$_port', '/requests/status.xml', queryParams);
      
      final response = await http.get(
        uri,
        headers: _getHeaders(),
      ).timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (e) {
      print('[VlcHttpService] Errore invio comando $command: $e');
      return false;
    }
  }
}
