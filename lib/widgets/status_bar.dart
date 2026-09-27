import 'package:flutter/material.dart';

import '../providers/vlc_provider.dart';

/// Stato di un collegamento, come lo mostra la barra in alto.
class LinkStatus {
  const LinkStatus({
    required this.label,
    required this.text,
    required this.color,
    required this.icon,
    required this.ip,
  });

  /// Sigla mostrata a sinistra: `VLC`, `MP`.
  final String label;

  /// Stato in parole: `COLLEGATO`, `TENTATIVO...`.
  final String text;

  final Color color;
  final IconData icon;

  /// Indirizzo, o `---` se non configurato.
  final String ip;
}

/// Barra con lo stato dei due collegamenti.
///
/// Vive in un file a se' perche' da sola e' lunga come un quarto dello
/// scheletro, e perche' la parte interessante non e' il disegno: e' la
/// traduzione dello stato del provider in parole e colori. Sta qui, e non
/// dentro la schermata, cosi' si puo' provare senza montare tutto il resto.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.vlc, required this.myPlaylist});

  final LinkStatus vlc;
  final LinkStatus myPlaylist;

  /// Costruisce la barra leggendo lo stato dal provider.
  factory StatusBar.forProvider(VlcProvider provider) => StatusBar(
    vlc: _daProvider(provider),
    myPlaylist: _myPlaylistDaProvider(provider),
  );

  /// Collegamento con VLC.
  ///
  /// L'ordine conta: mentre si collega, l'app e' "in tentativo" e non
  /// "collegata", anche se dalla sessione precedente risultava connessa.
  static LinkStatus _daProvider(VlcProvider provider) {
    String testo;
    Color colore;
    if (provider.isConnecting) {
      testo = 'TENTATIVO...';
      colore = Colors.orange;
    } else if (provider.isConnected) {
      testo = 'COLLEGATO';
      colore = Colors.green;
    } else {
      testo = 'DISCONNESSO';
      colore = Colors.red;
    }

    return LinkStatus(
      label: 'VLC',
      text: testo,
      color: colore,
      icon: Icons.link,
      ip: provider.currentConnection?.ipAddress ?? '---',
    );
  }

  /// Collegamento con il server MyPlaylist.
  ///
  /// Qui la differenza rispetto a VLC e' che "configurato" non vuol dire
  /// "funzionante": se non c'e' mai stato un comando, si distingue da "non
  /// risponde" con `NON TESTATO`. Senza quella distinzione, un server appena
  /// configurato e uno spento sembrerebbero identici.
  static LinkStatus _myPlaylistDaProvider(VlcProvider provider) {
    String testo;
    Color colore;
    if (provider.isMyPlaylistBusy) {
      testo = 'INVIO...';
      colore = Colors.orange;
    } else if (provider.isMyPlaylistConfigured) {
      switch (provider.lastMpStatus) {
        case 'SUCCESS':
          testo = 'CONNESSO';
          colore = Colors.blue;
          break;
        case 'ERROR':
          testo = 'NON CONNESSO';
          colore = Colors.red;
          break;
        default:
          testo = 'NON TESTATO';
          colore = Colors.orange.withValues(alpha: 0.7);
      }
    } else {
      testo = 'NON CONFIG.';
      colore = Colors.grey;
    }

    return LinkStatus(
      label: 'MP',
      text: testo,
      color: colore,
      icon: Icons.playlist_add_check,
      ip: provider.currentConnection?.myPlaylistIp ?? '---',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        children: [_voce(vlc), const SizedBox(width: 12), _voce(myPlaylist)],
      ),
    );
  }

  Widget _voce(LinkStatus stato) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: stato.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: stato.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stato.icon, size: 12, color: stato.color),
          const SizedBox(width: 4),
          Text(
            '${stato.label}: ',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
          Flexible(
            child: Text(
              stato.text,
              style: TextStyle(
                fontSize: 9,
                color: stato.color,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              stato.ip,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 8,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
