import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/services/update_service.dart';

import 'support/fake_release_server.dart';

void main() {
  group('isVersionGreater', () {
    test('restituisce true quando latest è maggiore', () {
      expect(isVersionGreater('2.8.0', '2.7.4'), isTrue);
      expect(isVersionGreater('3.0.0', '2.9.9'), isTrue);
      expect(isVersionGreater('2.7.5', '2.7.4'), isTrue);
    });

    test('restituisce false quando latest è minore o uguale', () {
      expect(isVersionGreater('2.7.4', '2.7.4'), isFalse);
      expect(isVersionGreater('2.7.3', '2.7.4'), isFalse);
      expect(isVersionGreater('1.9.0', '2.0.0'), isFalse);
    });

    test('ignora il prefisso v dei tag GitHub', () {
      expect(isVersionGreater('v2.8.0', '2.7.4'), isTrue);
      expect(isVersionGreater('v2.7.4', 'v2.7.4'), isFalse);
    });

    test('ignora la maiuscola del prefisso v', () {
      // Regressione: il 27/09 esisteva una release 'V2.7.5' con la v
      // maiuscola, e `releases/latest` la restituiva al posto di 'v2.7.5'.
      // Con il confronto sensibile al caso, 'V2' non e' un intero e diventava
      // 0: la versione risultava [0, 7, 5], minore di qualunque 2.x, e
      // l'aggiornamento non veniva offerto a nessuno senza dare errori.
      expect(isVersionGreater('V2.7.5', '2.7.4+1'), isTrue);
      expect(isVersionGreater('v2.7.5', '2.7.4+1'), isTrue);
      expect(isVersionGreater('V2.7.4+1', 'V2.7.4+1'), isFalse);
      // La V non deve pero' valere come versione: senza prefisso, 2.7.5 resta
      // maggiore di 2.7.4.
      expect(isVersionGreater('2.7.5', '2.7.4'), isTrue);
    });

    test('ignora i metadati di build (+N)', () {
      // Regressione: '4+1' non e' un intero, il confronto deve usare solo il
      // numero di versione, non il build number di Android.
      expect(isVersionGreater('2.7.5', '2.7.4+1'), isTrue);
      expect(isVersionGreater('2.7.4+1', '2.7.4+1'), isFalse);
      expect(isVersionGreater('2.7.4+2', '2.7.4+1'), isFalse);
    });

    test('ignora i prerelease', () {
      expect(isVersionGreater('2.8.0', '2.8.0-rc1'), isFalse);
      expect(isVersionGreater('2.8.0-rc1', '2.7.4'), isTrue);
    });

    test('gestisce segmenti mancanti o non numerici', () {
      expect(isVersionGreater('2.8', '2.7.4'), isTrue);
      expect(isVersionGreater('2.8.0', '2.8'), isFalse);
      expect(isVersionGreater('2.8.x', '2.7.4'), isTrue);
      expect(isVersionGreater('', '0.0.0'), isFalse);
    });
  });

  group('downloadVerifiedApk', () {
    late Directory tempDir;
    late UpdateService service;

    // Un APK finto: il contenuto non conta, conta l'impronta.
    final apkBytes = utf8.encode('PK\x03\x04 contenuto fittizio di un APK');

    String hashOf(List<int> bytes) => crypto.sha256.convert(bytes).toString();

    GitHubRelease releaseFor(String url) =>
        GitHubRelease(tagName: 'v9.9.9', body: '', htmlUrl: url, apkUrl: url);

    setUp(() async {
      service = UpdateService();
      tempDir = await Directory.systemTemp.createTemp('vlcremote_update');
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('scarica e accetta un APK con impronta corretta', () async {
      final server = await FakeReleaseServer.start(
        apkBytes: apkBytes,
        publishedHash: hashOf(apkBytes),
      );
      addTearDown(server.close);

      final path = await service.downloadVerifiedApk(
        releaseFor(server.apkUrl()),
        targetDirectory: tempDir,
      );

      expect(File(path).existsSync(), isTrue);
      expect(File(path).readAsBytesSync(), apkBytes);
    });

    test('rifiuta e cancella un APK con impronta diversa', () async {
      // Regressione di sicurezza: prima l'APK veniva installato senza
      // nessuna verifica.
      final server = await FakeReleaseServer.start(
        apkBytes: apkBytes,
        publishedHash: hashOf(utf8.encode('qualcosa-diverso')),
      );
      addTearDown(server.close);

      await expectLater(
        service.downloadVerifiedApk(
          releaseFor(server.apkUrl()),
          targetDirectory: tempDir,
        ),
        throwsA(
          isA<UpdateVerificationException>().having(
            (e) => e.message,
            'messaggio',
            contains('non corrispondente'),
          ),
        ),
      );

      // Nessun file installabile resta sul disco.
      expect(
        File('${tempDir.path}/VlcRemote_update.apk').existsSync(),
        isFalse,
      );
      expect(
        File('${tempDir.path}/VlcRemote_update.apk.part').existsSync(),
        isFalse,
      );
    });

    test('rifiuta se il rilascio non pubblica l\'impronta', () async {
      // Fail closed: senza impronta non c'e' nulla a cui agganciarsi.
      final server = await FakeReleaseServer.start(apkBytes: apkBytes);
      addTearDown(server.close);

      await expectLater(
        service.downloadVerifiedApk(
          releaseFor(server.apkUrl()),
          targetDirectory: tempDir,
        ),
        throwsA(
          isA<UpdateVerificationException>().having(
            (e) => e.message,
            'messaggio',
            contains('SHA-256'),
          ),
        ),
      );
      expect(
        File('${tempDir.path}/VlcRemote_update.apk').existsSync(),
        isFalse,
      );
    });

    test('rifiuta un rilascio senza APK', () async {
      final server = await FakeReleaseServer.start(apkBytes: apkBytes);
      addTearDown(server.close);

      await expectLater(
        service.downloadVerifiedApk(
          GitHubRelease(tagName: 'v9.9.9', body: '', htmlUrl: 'https://x'),
          targetDirectory: tempDir,
        ),
        throwsA(isA<UpdateVerificationException>()),
      );
    });

    test('propaga il progresso del download', () async {
      final server = await FakeReleaseServer.start(
        apkBytes: apkBytes,
        publishedHash: hashOf(apkBytes),
      );
      addTearDown(server.close);

      final progress = <double?>[];
      await service.downloadVerifiedApk(
        releaseFor(server.apkUrl()),
        targetDirectory: tempDir,
        onProgress: progress.add,
      );

      expect(progress, isNotEmpty);
      expect(progress.last, 1.0);
    });

    test('rifiuta un APK piu\' grande del limite', () async {
      // Il limite e' applicato mentre si scrive, non solo sull\'header.
      final server = await FakeReleaseServer.start(
        apkBytes: List<int>.filled(1024, 65),
        publishedHash: 'a' * 64,
      );
      addTearDown(server.close);

      await expectLater(
        service.downloadVerifiedApk(
          releaseFor(server.apkUrl()),
          targetDirectory: tempDir,
        ),
        throwsA(anything),
      );
    });
  });
}
