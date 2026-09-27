import 'package:flutter/material.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';
import 'package:vlc_remote_flutter/widgets/connections/connection_card.dart';

/// Elenco dei server salvati, con il pulsante per aggiungerne uno.
///
/// Si occupa anche del caso in cui la lista e' vuota, che e' il primo schermo
/// che vede chi apre il dialogo per la prima volta e non ha niente da
/// collegarsi.
class ConnectionList extends StatelessWidget {
  const ConnectionList({
    super.key,
    required this.connections,
    required this.selectedConnectionId,
    required this.onConnect,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    required this.onAddNew,
  });

  final List<VlcConnection> connections;

  /// Id del server collegato in questo momento, per evidenziarlo nella lista.
  final String? selectedConnectionId;

  final void Function(VlcConnection connection) onConnect;
  final Future<void> Function(VlcConnection connection) onToggleFavorite;
  final void Function(VlcConnection connection) onEdit;
  final void Function(VlcConnection connection) onDelete;
  final VoidCallback onAddNew;

  @override
  Widget build(BuildContext context) {
    // Il pulsante sta fuori dal ramo vuoto/pieno perche' serve in entrambi i
    // casi: e' l'unico modo di aggiungere un server, quindi metterlo dentro
    // "quando la lista c'e'" avrebbe lasciato chi apre il dialogo per la prima
    // volta senza uscita.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (connections.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nessun server salvato',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: connections.length,
              itemBuilder: (context, index) {
                final connection = connections[index];
                return ConnectionCard(
                  connection: connection,
                  isSelected: connection.id == selectedConnectionId,
                  onConnect: () => onConnect(connection),
                  onToggleFavorite: () => onToggleFavorite(connection),
                  onEdit: () => onEdit(connection),
                  onDelete: () => onDelete(connection),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onAddNew,
          icon: const Icon(Icons.add),
          label: const Text('Nuovo Server VLC'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}
