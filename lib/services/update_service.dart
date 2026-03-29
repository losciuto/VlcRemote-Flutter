import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class GitHubRelease {
  final String tagName;
  final String body;
  final String htmlUrl;
  final String? apkUrl;

  GitHubRelease({
    required this.tagName,
    required this.body,
    required this.htmlUrl,
    this.apkUrl,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    String? apkUrl;
    final assets = json['assets'] as List?;
    if (assets != null) {
      // Cerca il primo file che finisce con .apk
      final apkAsset = assets.firstWhere(
        (asset) => asset['name'].toString().toLowerCase().endsWith('.apk'),
        orElse: () => null,
      );
      if (apkAsset != null) {
        apkUrl = apkAsset['browser_download_url'];
      }
    }

    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      body: json['body'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      apkUrl: apkUrl,
    );
  }
}

class UpdateService {
  static const String _repoUrl =
      'https://api.github.com/repos/losciuto/VlcRemote-Flutter/releases/latest';

  Future<GitHubRelease?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(Uri.parse(_repoUrl)).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final latestRelease = GitHubRelease.fromJson(json);

        // Rimuove la 'v' iniziale se presente (es: v2.8.0 -> 2.8.0)
        final latestVersion = latestRelease.tagName.replaceAll(
          RegExp(r'^v'),
          '',
        );

        if (_isVersionGreater(latestVersion, currentVersion)) {
          return latestRelease;
        }
      }
    } catch (e) {
      print('[UpdateService] Errore durante il controllo aggiornamenti: $e');
    }
    return null;
  }

  /// Compara due versioni semantiche (es: 2.8.1 e 2.8.0)
  bool _isVersionGreater(String latest, String current) {
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final latestPart = (latestParts.length > i) ? latestParts[i] : 0;
      final currentPart = (currentParts.length > i) ? currentParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    return false;
  }
}
