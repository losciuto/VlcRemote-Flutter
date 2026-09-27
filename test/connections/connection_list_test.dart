import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/widgets/connections/connection_card.dart';
import 'package:vlc_remote_flutter/widgets/connections/connection_list.dart';

VlcConnection _server(String id, String nome) {
  return VlcConnection(
    id: id,
    name: nome,
    ipAddress: '192.168.1.$id',
    port: 8080,
    lastUsed: DateTime(2026, 9, 27),
  );
}

Widget _elenco({
  required List<VlcConnection> connections,
  String? selectedId,
  VoidCallback? onAddNew,
  void Function(VlcConnection)? onConnect,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ConnectionList(
        connections: connections,
        selectedConnectionId: selectedId,
        onConnect: onConnect ?? (c) {},
        onToggleFavorite: (c) async {},
        onEdit: (c) {},
        onDelete: (c) {},
        onAddNew: onAddNew ?? () {},
      ),
    ),
  );
}

void main() {
  testWidgets('con la lista vuota dice che non c\'e\' nessun server', (
    tester,
  ) async {
    await tester.pumpWidget(_elenco(connections: []));

    expect(find.text('Nessun server salvato'), findsOneWidget);
    expect(find.byType(ConnectionCard), findsNothing);
  });

  testWidgets('con la lista vuota il pulsante per aggiungere c\'e\' lo stesso', (
    tester,
  ) async {
    // Il pulsante sta fuori dal ramo "vuoto", e devo restare fuori: e' l'unico
    // modo di aggiungere un server, quindi senza non si puo' cominciare.
    await tester.pumpWidget(_elenco(connections: []));

    expect(find.text('Nuovo Server VLC'), findsOneWidget);
  });

  testWidgets('il pulsante per aggiungere chiama la sua azione', (
    tester,
  ) async {
    var aggiunti = 0;
    await tester.pumpWidget(
      _elenco(connections: [], onAddNew: () => aggiunti++),
    );

    await tester.tap(find.text('Nuovo Server VLC'));
    expect(aggiunti, 1);
  });

  testWidgets('elenca un elemento per ogni server salvato', (tester) async {
    await tester.pumpWidget(
      _elenco(connections: [_server('1', 'Salotto'), _server('2', 'Camera')]),
    );

    expect(find.byType(ConnectionCard), findsNWidgets(2));
    expect(find.text('Salotto'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
  });

  testWidgets('toccando una scheda passa proprio quel server', (tester) async {
    VlcConnection? scelto;
    await tester.pumpWidget(
      _elenco(
        connections: [_server('1', 'Salotto'), _server('2', 'Camera')],
        onConnect: (c) => scelto = c,
      ),
    );

    await tester.tap(find.text('Camera'));
    expect(scelto?.id, '2');
  });

  testWidgets('segnala solo il server collegato', (tester) async {
    await tester.pumpWidget(
      _elenco(
        connections: [_server('1', 'Salotto'), _server('2', 'Camera')],
        selectedId: '2',
      ),
    );

    final selezionate = tester
        .widgetList<ConnectionCard>(find.byType(ConnectionCard))
        .where((c) => c.isSelected)
        .map((c) => c.connection.id)
        .toList();

    expect(selezionate, ['2']);
  });
}
