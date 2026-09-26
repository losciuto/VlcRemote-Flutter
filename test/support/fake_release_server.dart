import 'dart:io';

/// Server HTTP finto che ospita un APK e, opzionalmente, la sua impronta.
///
/// Serve a verificare il download dell'aggiornamento: senza questo, la
/// verifica SHA-256 resterebbe un'asserzione sulla carta.
class FakeReleaseServer {
  FakeReleaseServer._(this._server, this._apkBytes, this._publishedHash);

  final HttpServer _server;
  final List<int> _apkBytes;

  /// Impronta pubblicata nell'asset `.sha256`, se presente.
  final String? _publishedHash;

  final List<String> requestedPaths = [];

  static Future<FakeReleaseServer> start({
    required List<int> apkBytes,
    String? publishedHash,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = FakeReleaseServer._(server, apkBytes, publishedHash);

    server.listen((request) async {
      final path = request.uri.path;
      fake.requestedPaths.add(path);

      if (path.endsWith('.sha256')) {
        if (fake._publishedHash == null) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.text
          // Formato identico a sha256sum: "<hash>  <nomefile>"
          ..write('${fake._publishedHash}  app-release.apk\n');
        await request.response.close();
        return;
      }

      if (path.endsWith('.apk')) {
        request.response
          ..statusCode = HttpStatus.ok
          ..contentLength = fake._apkBytes.length
          ..add(fake._apkBytes);
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });

    return fake;
  }

  String get host => '127.0.0.1';

  int get port => _server.port;

  String apkUrl() => 'http://$host:$port/download/app-release.apk';

  Future<void> close() => _server.close(force: true);
}
