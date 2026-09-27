import 'package:flutter/material.dart';
import 'package:vlc_remote_flutter/constants/app_constants.dart';
import 'package:vlc_remote_flutter/models/vlc_connection.dart';

/// Scheda di un server salvato, con le tre azioni che si possono fare su di esso.
///
/// Il pulsante di collegamento e' l'intera scheda; le tre azioni in basso sono
/// separate, perche' eliminare un server e' una cosa diversa dal collegarsi a
/// lui e non devono stare sotto lo stesso tocco.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    super.key,
    required this.connection,
    required this.isSelected,
    required this.onConnect,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  final VlcConnection connection;
  final bool isSelected;
  final VoidCallback onConnect;
  final Future<void> Function() onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final schema = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: schema.primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onConnect,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: schema.primaryContainer,
                    child: Icon(
                      Icons.computer,
                      size: 20,
                      color: schema.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          connection.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'VLC: ${connection.ipAddress}:${connection.port}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (connection.myPlaylistIp != null)
                          Text(
                            'MP: ${connection.myPlaylistIp}:'
                            '${connection.myPlaylistPort ?? AppConstants.defaultMyPlaylistPort}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _CardActionButton(
                    icon: connection.isFavorite
                        ? Icons.star
                        : Icons.star_border,
                    color: connection.isFavorite ? Colors.amber : Colors.grey,
                    // Il pulsante cambia significato a seconda dello stato:
                    // senza questo, il lettore di schermo annuncerebbe
                    // "aggiungi ai preferiti" per un server che lo e' gia'.
                    label: connection.isFavorite
                        ? 'Togli dai preferiti'
                        : 'Aggiungi ai preferiti',
                    onPressed: onToggleFavorite,
                  ),
                  const SizedBox(width: 8),
                  _CardActionButton(
                    icon: Icons.edit_outlined,
                    color: Colors.blue,
                    label: 'Modifica il server',
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 8),
                  _CardActionButton(
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    label: 'Elimina il server',
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsante quadrato con icona, dentro una sfumatura del suo stesso colore.
///
/// Non puo' essere un `IconButton`: quello porta con se' un bordo e uno
/// spazio di 48 pixel che qui farebbero schizzare la riga delle azioni. Il
/// prezzo e' che serve mettere a mano l'etichetta per chi non vede
/// l'icona, ed e' il motivo per cui [label] non e' facoltativa.
class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(icon, size: 18, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
