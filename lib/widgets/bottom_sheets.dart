import 'package:flutter/material.dart';
import 'package:vlc_remote_flutter/widgets/my_playlist_panel.dart';
import 'package:vlc_remote_flutter/widgets/playlist_panel.dart';

/// Foglio con i filtri e le azioni di MyPlaylist.
///
/// Sale a metà schermo e si allarga fino all'80%: sotto, la lista dei filtri
/// sta tutta dentro il foglio e non si sposta, quindi si vede sempre da dove
/// si sta arrivando.
Future<void> showSmartActionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        child: const MyPlaylistPanel(),
      ),
    ),
  );
}

/// Foglio con la playlist del server VLC.
///
/// Sale piu' in alto di quello delle azioni, perche' la lista delle voci e'
/// la cosa che si va a guardare: con il foglio a meta' schermo restano tre
/// voci e un testo di aiuto.
Future<void> showPlaylistSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const _Presa(),
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Playlist',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              child: const PlaylistPanel(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Il pallino grigio in alto: e' l'unico accenno al fatto che il foglio si
/// puo' trascinare.
///
/// Il foglio delle azioni di MyPlaylist non ce l'ha. E' una piccola
/// disuguaglianza, non un errore, e si lascia cosi' perche' aggiungerlo
/// richiederebbe di scegliere la forma giusta per due pannelli che non hanno
/// la stessa struttura.
class _Presa extends StatelessWidget {
  const _Presa();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
