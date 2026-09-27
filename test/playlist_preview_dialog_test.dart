import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/widgets/playlist_preview_dialog.dart';

void main() {
  List<Map<String, dynamic>> playlistDi(int n) => [
    for (var i = 0; i < n; i++)
      {'id': i, 'title': 'Titolo $i', 'isSeries': i % 2},
  ];

  /// Apre il dialogo dentro un'app, cosicche' `Navigator.pop` funzioni.
  Future<void> apri(
    WidgetTester tester, {
    required List<Map<String, dynamic>> items,
    required VoidCallback onPlay,
    String ip = '192.168.1.15',
    int port = 8080,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => PlaylistPreviewDialog(
                    items: items,
                    ip: ip,
                    port: port,
                    onPlay: onPlay,
                  ),
                ),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('il titolo conta le voci', (tester) async {
    await apri(tester, items: playlistDi(3), onPlay: () {});

    expect(find.text('Anteprima Playlist (3)'), findsOneWidget);
  });

  testWidgets('ogni voce appare con il suo titolo', (tester) async {
    await apri(tester, items: playlistDi(3), onPlay: () {});

    for (var i = 0; i < 3; i++) {
      expect(find.text('Titolo $i'), findsOneWidget);
    }
  });

  testWidgets('"Riproduci Ora" chiama il richiamo e chiude', (tester) async {
    var chiamato = 0;
    await apri(tester, items: playlistDi(2), onPlay: () => chiamato++);

    await tester.tap(find.text('Riproduci Ora'));
    await tester.pumpAndSettle();

    expect(chiamato, 1, reason: 'il richiamo deve essere chiamato una volta');
    expect(find.text('Anteprima Playlist (2)'), findsNothing);
  });

  testWidgets('senza voci il pulsante di riproduzione non c\'e\'', (
    tester,
  ) async {
    // Con la lista vuota il pulsore porterebbe a riprodurre una playlist che
    // non esiste, quindi non viene mostrato.
    await apri(tester, items: const [], onPlay: () {});

    expect(find.text('Riproduci Ora'), findsNothing);
    expect(
      find.text('Nessun video trovato con questi filtri.'),
      findsOneWidget,
    );
  });

  testWidgets('la copertina arriva dal server indicato', (tester) async {
    await apri(
      tester,
      items: [
        {'id': 42, 'title': 'Il Film', 'isSeries': 0, 'posterPath': '/p.jpg'},
      ],
      onPlay: () {},
      ip: '10.0.0.5',
      port: 8080,
    );

    final immagini = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .toList();
    expect(immagini, isNotEmpty, reason: 'la voce deve avere la copertina');
    expect(immagini.first.imageUrl, contains('10.0.0.5'));
    expect(immagini.first.imageUrl, contains('42'));
  });

  testWidgets('senza host non si tenta la copertina', (tester) async {
    // `posterUri` restituisce null con l'host vuoto: senza questo controllo
    // l'app costruirebbe un URL tipo "http://:0/..." e ogni immagine andrebbe
    // in errore.
    await apri(
      tester,
      items: [
        {'id': 42, 'title': 'Il Film', 'isSeries': 0, 'posterPath': '/p.jpg'},
      ],
      onPlay: () {},
      ip: '',
    );

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('Il Film'), findsOneWidget);
  });
}
