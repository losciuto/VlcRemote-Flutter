import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../constants/app_constants.dart';
import '../utils/app_logger.dart';

/// Confronta due versioni semantiche.
///
/// Accetta un eventuale 'v' iniziale ('v2.8.0'), i metadati di build ('2.7.4+1')
/// e i prerelease ('2.8.0-rc1'), che non incidono sull'ordine numerico.
/// Restituisce true solo se [latest] è strettamente maggiore di [current].
bool isVersionGreater(String latest, String current) {
  List<int> parse(String version) {
    return version
        .trim()
        .replaceFirst(RegExp(r'^v'), '')
        .split('+')
        .first
        .split('-')
        .first
        .split('.')
        .map((e) => int.tryParse(e) ?? 0)
        .toList();
  }

  final latestParts = parse(latest);
  final currentParts = parse(current);

  final length = latestParts.length > currentParts.length
      ? latestParts.length
      : currentParts.length;

  for (var i = 0; i < length; i++) {
    final latestPart = (latestParts.length > i) ? latestParts[i] : 0;
    final currentPart = (currentParts.length > i) ? currentParts[i] : 0;

    if (latestPart > currentPart) return true;
    if (latestPart < currentPart) return false;
  }
  return false;
}

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

/// Cosa fare con un rilascio: installare l'APK in locale, o mandare l'utente
/// alla pagina del rilascio.
class UpdateStart {
  const UpdateStart._({this.apkPath, this.releasePage});

  /// Percorso dell'APK scaricato e verificato.
  final String? apkPath;

  /// Pagina del rilascio da aprire nel browser.
  final Uri? releasePage;

  factory UpdateStart.apk(String path) => UpdateStart._(apkPath: path);

  factory UpdateStart.openReleasePage(Uri url) =>
      UpdateStart._(releasePage: url);
}

class UpdateService {
  /// Tag usato nei log di questo servizio.
  static const String _tag = 'UpdateService';
  static const String _repoUrl =
      'https://api.github.com/repos/losciuto/VlcRemote-Flutter/releases/latest';

  Future<GitHubRelease?> checkUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http
          .get(Uri.parse(_repoUrl))
          .timeout(
            const Duration(milliseconds: AppConstants.updateCheckTimeoutMs),
          );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final latestRelease = GitHubRelease.fromJson(json);

        // Rimuove la 'v' iniziale se presente (es: v2.8.0 -> 2.8.0)
        final latestVersion = latestRelease.tagName.replaceAll(
          RegExp(r'^v'),
          '',
        );

        if (isVersionGreater(latestVersion, currentVersion)) {
          return latestRelease;
        }
      }
    } catch (e) {
      AppLogger.w(_tag, 'Errore durante il controllo aggiornamenti', e);
    }
    return null;
  }

  /// Decide come installare [release] e porta avanti l'operazione.
  ///
  /// Su Android l'APK viene scaricato e verificato, e il percorso torna in
  /// [UpdateStart.apkPath]. Su ogni altra piattaforma l'interfaccia HTTP non
  /// e' distribuibile come APK, quindi si rimanda alla pagina del rilascio,
  /// dove la firma viene verificata dal sistema.
  ///
  /// La decisione e' qui e non nel widget per due motivi: il widget non deve
  /// conoscere `Platform`, e cosi' il ramo Android resta verificabile dai test
  /// senza dover simulare una piattaforma.
  Future<UpdateStart> prepareUpdate(
    GitHubRelease release, {
    required Directory targetDirectory,
    void Function(double? progress)? onProgress,
    bool? isAndroid,
  }) async {
    final android = isAndroid ?? Platform.isAndroid;
    if (!android || release.apkUrl == null) {
      return UpdateStart.openReleasePage(Uri.parse(release.htmlUrl));
    }

    final apkPath = await downloadVerifiedApk(
      release,
      targetDirectory: targetDirectory,
      onProgress: onProgress,
    );
    return UpdateStart.apk(apkPath);
  }

  /// Scarica l'APK del rilascio verificandone l'impronta SHA-256.
  ///
  /// L'impronta attesa viene letta dall'asset `<apk>.sha256` della stessa
  /// release GitHub. **Se quell'asset non esiste il download viene rifiutato**:
  /// senza un'impronta non c'è nulla a cui agganciare l'integrità del file, e un
  /// APK scaricato e installato al volo è un vettore di esecuzione di codice
  /// arbitrario. In quel caso l'utente può sempre installare la release dal
  /// browser, dove la firma viene verificata dal sistema.
  ///
  /// Il download scrive su file invece di accumulare tutto in memoria, e rifiuta
  /// i file più grandi di [AppConstants.maxApkSizeBytes].
  ///
  /// Restituisce il percorso del file verificato. [onProgress] riceve un valore
  /// da 0 a 1 quando la lunghezza totale è nota.
  Future<String> downloadVerifiedApk(
    GitHubRelease release, {
    required Directory targetDirectory,
    void Function(double? progress)? onProgress,
  }) async {
    final apkUrl = release.apkUrl;
    if (apkUrl == null) {
      throw UpdateVerificationException('Il rilascio non contiene un APK');
    }

    final expectedHash = await _fetchExpectedHash(apkUrl);
    if (expectedHash == null) {
      throw const UpdateVerificationException(
        'Il rilascio non pubblica l\'impronta SHA-256 '
        '(${AppConstants.apkChecksumSuffix}): installazione rifiutata per '
        'sicurezza. Usa il download manuale dalla pagina del rilascio.',
      );
    }

    final client = http.Client();
    File? partial;
    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      final response = await client
          .send(request)
          .timeout(
            const Duration(milliseconds: AppConstants.updateDownloadTimeoutMs),
          );

      if (response.statusCode != 200) {
        throw UpdateVerificationException(
          'Download fallito: HTTP ${response.statusCode}',
        );
      }

      final contentLength = response.contentLength;
      if (contentLength != null &&
          contentLength > AppConstants.maxApkSizeBytes) {
        throw UpdateVerificationException(
          'APK troppo grande (${contentLength ~/ (1024 * 1024)} MB, '
          'massimo ${AppConstants.maxApkSizeBytes ~/ (1024 * 1024)} MB)',
        );
      }

      final target = File('${targetDirectory.path}/VlcRemote_update.apk');
      // Scriviamo in un file temporaneo: se l'hash non torna, il file scaricato
      // non deve restare sul disco pronto per essere installato.
      partial = File('${target.path}.part');

      var downloaded = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.stream) {
          downloaded += chunk.length;
          if (downloaded > AppConstants.maxApkSizeBytes) {
            throw UpdateVerificationException(
              'APK troppo grande: interrotto a $downloaded byte',
            );
          }
          sink.add(chunk);
          if (contentLength != null && contentLength > 0) {
            onProgress?.call(downloaded / contentLength);
          }
        }
      } finally {
        await sink.close();
      }

      // L'hash si calcola rileggendo il file a blocchi: niente APK da 30 MB
      // in memoria.
      final actualHash = (await crypto.sha256.bind(partial.openRead()).first)
          .toString();

      if (actualHash != expectedHash) {
        throw UpdateVerificationException(
          'Impronta SHA-256 non corrispondente: attesa $expectedHash, '
          'ottenuta $actualHash. File scartato.',
        );
      }

      if (partial.existsSync()) {
        if (target.existsSync()) target.deleteSync();
        partial.renameSync(target.path);
      }
      partial = null;
      onProgress?.call(1);
      return target.path;
    } finally {
      client.close();
      if (partial != null && partial.existsSync()) {
        // Hash non corrispondente o download interrotto: niente file a metà.
        try {
          partial.deleteSync();
        } catch (_) {}
      }
    }
  }

  /// Legge l'asset `<apk>.sha256` e ne estrae l'impronta.
  Future<String?> _fetchExpectedHash(String apkUrl) async {
    final checksumUrl = '$apkUrl${AppConstants.apkChecksumSuffix}';
    try {
      final response = await http
          .get(Uri.parse(checksumUrl))
          .timeout(
            const Duration(milliseconds: AppConstants.updateChecksumTimeoutMs),
          );

      if (response.statusCode != 200) return null;

      // Formato atteso: "<64 caratteri esadecimali>  <nomefile>", come sha256sum.
      final match = RegExp(r'\b([0-9a-fA-F]{64})\b').firstMatch(response.body);
      if (match == null) return null;
      return match.group(1)!.toLowerCase();
    } catch (e) {
      AppLogger.w(_tag, 'Impossibile leggere l\'impronta SHA-256', e);
      return null;
    }
  }
}

/// Errore di integrita' o di download dell'aggiornamento.
class UpdateVerificationException implements Exception {
  final String message;

  const UpdateVerificationException(this.message);

  @override
  String toString() => message;
}
