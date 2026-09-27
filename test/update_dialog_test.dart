import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/services/update_service.dart';
import 'package:vlc_remote_flutter/widgets/update_dialog.dart';

/// Canale di `open_filex`: senza un mock, l'apertura di un file dal test
/// fallirebbe e non si saprebbe distinguere da un errore dell'app.
const MethodChannel _openFilex = MethodChannel('com.example.open_filex');

/// Canale di `url_launcher`, per lo stesso motivo.
const MethodChannel _urlLauncher = MethodChannel(
  'plugins.flutter.io/url_launcher',
);

void main() {
  late List<MethodCall> openFileCalls;
  late List<MethodCall> launchCalls;
  late Directory tempDir;

  /// [withApk] esiste per poter costruire un rilascio *senza* APK: con un
  /// parametro nullable e un valore di default non si distingueva "non
  /// passato" da "passato null".
  GitHubRelease release({bool withApk = true, String body = 'correzioni'}) =>
      GitHubRelease(
        tagName: 'v2.8.0',
        body: body,
        htmlUrl:
            'https://github.com/losciuto/VlcRemote-Flutter/releases/tag/v2.8.0',
        apkUrl: withApk ? 'https://example.test/app.apk' : null,
      );

  /// Mostra il dialog e restituisce il tester, con l'albero montato.
  Future<void> pump(
    WidgetTester tester, {
    GitHubRelease? rel,
    bool? android,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: UpdateDialog(
              release: rel ?? release(),
              isAndroid: android ?? false,
              temporaryDirectory: () async => tempDir,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() async {
    openFileCalls = [];
    launchCalls = [];
    tempDir = await Directory.systemTemp.createTemp('update_dialog_test');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_openFilex, (call) async {
          openFileCalls.add(call);
          // `done` e' il risultato di successo di open_filex.
          return 'done';
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, (call) async {
          launchCalls.add(call);
          return true;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_openFilex, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_urlLauncher, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('UpdateDialog - contenuto', () {
    testWidgets('mostra versione e note del rilascio', (tester) async {
      await pump(tester, rel: release(body: 'correzione di sicurezza'));

      expect(find.text('Versione v2.8.0'), findsOneWidget);
      expect(find.text('correzione di sicurezza'), findsOneWidget);
      expect(find.text('Novità:'), findsOneWidget);
    });

    testWidgets('senza note non mostra il riquadro Novità', (tester) async {
      await pump(tester, rel: release(body: ''));

      expect(find.text('Novità:'), findsNothing);
      expect(find.text('Versione v2.8.0'), findsOneWidget);
    });

    testWidgets('offre annulla e aggiorna', (tester) async {
      await pump(tester);

      expect(find.text('ANNULLA'), findsOneWidget);
      expect(find.text('AGGIORNA ORA'), findsOneWidget);
    });

    testWidgets('annulla chiude il dialog', (tester) async {
      await pump(tester);

      await tester.tap(find.text('ANNULLA'));
      await tester.pumpAndSettle();

      expect(find.byType(UpdateDialog), findsNothing);
    });
  });

  group('UpdateDialog - ramo non Android', () {
    testWidgets('apre la pagina del rilascio e non scarica nulla', (
      tester,
    ) async {
      // Su desktop e iOS non esiste un APK installabile: il dialog deve
      // mandare al browser, dove la firma viene verificata dal sistema.
      await pump(tester, android: false);

      await tester.tap(find.text('AGGIORNA ORA'));
      await tester.pumpAndSettle();

      expect(launchCalls, hasLength(1));
      expect(launchCalls.single.method, 'launch');
      expect(
        (launchCalls.single.arguments as Map)['url'],
        contains('releases/tag/v2.8.0'),
      );
      // Nessun tentativo di aprire un file: non c'è niente da installare.
      expect(openFileCalls, isEmpty);
    });
  });

  group('UpdateDialog - errori', () {
    testWidgets('un rilascio senza APK va alla pagina, non al download', (
      tester,
    ) async {
      // apkUrl null anche su Android: senza APK non c'è cosa installare.
      await pump(tester, rel: release(withApk: false), android: true);

      await tester.tap(find.text('AGGIORNA ORA'));
      await tester.pumpAndSettle();

      expect(launchCalls, hasLength(1));
      expect(openFileCalls, isEmpty);
    });
  });

  group('UpdateService.prepareUpdate', () {
    test('su Android con APK non ricade sulla pagina del rilascio', () async {
      // In un test la rete è bloccata, quindi il download non può riuscire.
      // Quello che conta è che il ramo Android *tenti* il download verificato
      // e non restituisca la pagina: l'errore è di verifica, non un fallback
      // silenzioso che lascerebbe credere di aver installato qualcosa.
      await expectLater(
        UpdateService().prepareUpdate(
          release(),
          targetDirectory: tempDir,
          isAndroid: true,
        ),
        throwsA(
          isA<UpdateVerificationException>().having(
            (e) => e.message,
            'message',
            contains('impronta'),
          ),
        ),
      );
    });

    test('fuori da Android torna la pagina del rilascio', () async {
      final start = await UpdateService().prepareUpdate(
        release(),
        targetDirectory: tempDir,
        isAndroid: false,
      );

      expect(start.apkPath, isNull);
      expect(start.releasePage.toString(), contains('releases/tag/v2.8.0'));
    });

    test('Android senza APK torna la pagina del rilascio', () async {
      final start = await UpdateService().prepareUpdate(
        release(withApk: false),
        targetDirectory: tempDir,
        isAndroid: true,
      );

      expect(start.apkPath, isNull);
      expect(start.releasePage, isNotNull);
    });
  });
}
