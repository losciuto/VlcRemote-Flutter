import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/constants/app_constants.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/widgets/connections/connection_card.dart';

VlcConnection _server({
  String id = '1',
  String name = 'VLC Casa',
  bool isFavorite = false,
  String? myPlaylistIp,
}) {
  return VlcConnection(
    id: id,
    name: name,
    ipAddress: '192.168.1.15',
    port: 8080,
    lastUsed: DateTime(2026, 9, 27),
    isFavorite: isFavorite,
    myPlaylistIp: myPlaylistIp,
    myPlaylistPort: myPlaylistIp == null ? null : 9090,
  );
}

Widget _scheda({
  required VlcConnection connection,
  bool isSelected = false,
  VoidCallback? onConnect,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  Future<void> Function()? onToggleFavorite,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ConnectionCard(
        connection: connection,
        isSelected: isSelected,
        onConnect: onConnect ?? () {},
        onToggleFavorite: onToggleFavorite ?? () async {},
        onEdit: onEdit ?? () {},
        onDelete: onDelete ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('mostra nome, indirizzo VLC e indirizzo MyPlaylist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _scheda(connection: _server(myPlaylistIp: '192.168.1.20')),
    );

    expect(find.text('VLC Casa'), findsOneWidget);
    expect(find.text('VLC: 192.168.1.15:8080'), findsOneWidget);
    expect(find.text('MP: 192.168.1.20:9090'), findsOneWidget);
  });

  testWidgets('senza MyPlaylist non mostra la riga MP', (tester) async {
    await tester.pumpWidget(_scheda(connection: _server()));

    expect(find.textContaining('MP:'), findsNothing);
  });

  testWidgets('la riga MP usa la porta di default quando manca', (
    tester,
  ) async {
    // La porta non salvata non e' un errore: il modello la lascia null e
    // l'app la recupera dalla costante, quindi la riga deve dirlo lo stesso.
    final server = VlcConnection(
      id: '1',
      name: 'VLC Casa',
      ipAddress: '192.168.1.15',
      port: 8080,
      lastUsed: DateTime(2026, 9, 27),
      myPlaylistIp: '192.168.1.20',
    );

    await tester.pumpWidget(_scheda(connection: server));

    expect(
      find.text('MP: 192.168.1.20:${AppConstants.defaultMyPlaylistPort}'),
      findsOneWidget,
    );
  });

  testWidgets('toccando la scheda ci si collega', (tester) async {
    var collegati = 0;
    await tester.pumpWidget(
      _scheda(connection: _server(), onConnect: () => collegati++),
    );

    await tester.tap(find.text('VLC Casa'));
    expect(collegati, 1);
  });

  testWidgets('i tre pulsanti hanno un nome per chi non vede le icone', (
    tester,
  ) async {
    // Le tre azioni sono solo icone: senza etichetta non dicono nulla a chi
    // usa il lettore di schermo, e una stella con una X rossa accanto non e'
    // un'informazione che si possa dedurre dal contesto.
    final gestore = tester.ensureSemantics();
    await tester.pumpWidget(
      _scheda(connection: _server(), onToggleFavorite: () async {}),
    );

    expect(find.bySemanticsLabel('Aggiungi ai preferiti'), findsOneWidget);
    expect(find.bySemanticsLabel('Modifica il server'), findsOneWidget);
    expect(find.bySemanticsLabel('Elimina il server'), findsOneWidget);

    gestore.dispose();
  });

  testWidgets('il pulsante dei preferiti cambia nome con lo stato', (
    tester,
  ) async {
    // Se il nome restasse "aggiungi" per un server gia' preferito, il
    // lettore di schermo direbbe il contrario di quello che il pulsante fa.
    final gestore = tester.ensureSemantics();
    await tester.pumpWidget(_scheda(connection: _server(isFavorite: true)));

    expect(find.bySemanticsLabel('Togli dai preferiti'), findsOneWidget);
    expect(find.bySemanticsLabel('Aggiungi ai preferiti'), findsNothing);

    gestore.dispose();
  });

  testWidgets('i tre pulsanti chiamano le tre azioni distinte', (tester) async {
    var preferito = 0;
    var modificato = 0;
    var eliminato = 0;

    await tester.pumpWidget(
      _scheda(
        connection: _server(),
        onToggleFavorite: () async => preferito++,
        onEdit: () => modificato++,
        onDelete: () => eliminato++,
      ),
    );

    await tester.tap(find.byIcon(Icons.star_border));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect([preferito, modificato, eliminato], [1, 1, 1]);
  });

  testWidgets('il server collegato ha il bordo colorato', (tester) async {
    // Il collegamento in corso e' l'informazione che distingue una scheda
    // dalle altre: senza il bordo, l'utente non sa a cosa si e' collegato.
    await tester.pumpWidget(_scheda(connection: _server(), isSelected: true));

    final card = tester.widget<Card>(find.byType(Card));
    final forma = card.shape! as RoundedRectangleBorder;
    expect(
      forma.side,
      BorderSide(color: ThemeData().colorScheme.primary, width: 2),
    );

    await tester.pumpWidget(_scheda(connection: _server()));
    final nonSelezionato =
        tester.widget<Card>(find.byType(Card)).shape! as RoundedRectangleBorder;
    expect(nonSelezionato.side, BorderSide.none);
  });
}
