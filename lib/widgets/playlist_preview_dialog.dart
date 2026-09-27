import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/my_playlist_service.dart';

/// Anteprima della playlist generata dal server, prima di riprodurla.
///
/// Vive in un file a se' perche' da sola e' lunga quanto mezzo pannello: ha
/// la lista delle voci, la copertina di ciascuna e i pulsanti. Il pannello si
/// occupa di chiederla, questo file di mostrarla.
///
/// [onPlay] viene chiamata quando l'utente conferma: chi apre il dialogo
/// decide cosa significa "riproduci", qui si chiude e si esce.
class PlaylistPreviewDialog extends StatelessWidget {
  const PlaylistPreviewDialog({
    super.key,
    required this.items,
    required this.ip,
    required this.port,
    required this.onPlay,
  });

  /// Voci come le manda il server, gia' trasformate in una lista propria.
  final List<Map<String, dynamic>> items;

  /// Host e porta del server MyPlaylist, per le copertine.
  final String ip;
  final int port;

  /// Chiamata quando l'utente preme "Riproduci ora".
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        children: [
          const Icon(Icons.playlist_play, size: 48, color: Colors.blue),
          const SizedBox(height: 8),
          Text('Anteprima Playlist (${items.length})'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: items.isEmpty
            ? const Center(
                child: Text('Nessun video trovato con questi filtri.'),
              )
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSeries =
                      item['isSeries'] == 1 || item['isSeries'] == true;

                  final videoId = item['id'];
                  final String? rawPoster = item['posterPath'];

                  Widget leadingWidget;
                  // L'id arriva dal server: l'URL viene costruito con Uri,
                  // che codifica il percorso e rifiuta un host non valido.
                  final imageUrl =
                      (rawPoster != null && rawPoster.startsWith('http'))
                      ? rawPoster
                      : (videoId != null && ip.isNotEmpty
                            ? MyPlaylistService.posterUri(
                                host: ip,
                                port: port,
                                videoId: videoId,
                              )?.toString()
                            : null);

                  if (imageUrl != null) {
                    leadingWidget = ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 40,
                        height: 60,
                        fit: BoxFit.cover,
                        imageBuilder: (context, imageProvider) => GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => Dialog(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                insetPadding: const EdgeInsets.all(20),
                                child: Container(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () => Navigator.pop(ctx),
                                            tooltip: 'Chiudi',
                                          ),
                                        ],
                                      ),
                                      Flexible(
                                        flex: 5,
                                        child: Center(
                                          child: InteractiveViewer(
                                            panEnabled: true,
                                            minScale: 0.5,
                                            maxScale: 4.0,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                fit: BoxFit.contain,
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const SizedBox.shrink(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.star,
                                            color: Colors.amber,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            (item['rating'] as num?)
                                                    ?.toStringAsFixed(1) ??
                                                'N/A',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Flexible(
                                        flex: 3,
                                        child: SingleChildScrollView(
                                          child: Text(
                                            item['plot']
                                                        ?.toString()
                                                        .isNotEmpty ==
                                                    true
                                                ? item['plot']
                                                : 'Nessuna trama disponibile.',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            textAlign: TextAlign.justify,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: imageProvider,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        placeholder: (context, url) => Container(
                          color: Colors.grey[800],
                          width: 40,
                          height: 60,
                          child: const Icon(
                            Icons.movie,
                            size: 20,
                            color: Colors.white54,
                          ),
                        ),
                        errorWidget: (context, url, error) => isSeries
                            ? const CircleAvatar(
                                backgroundColor: Colors.blueGrey,
                                child: Icon(
                                  Icons.tv,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.grey[700],
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                      ),
                    );
                  } else {
                    // URL non utilizzabile: host non valido, id assente o
                    // percorso non costruibile.
                    leadingWidget = isSeries
                        ? const CircleAvatar(
                            backgroundColor: Colors.blueGrey,
                            child: Icon(
                              Icons.tv,
                              color: Colors.white,
                              size: 20,
                            ),
                          )
                        : CircleAvatar(
                            backgroundColor: Colors.grey[700],
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                  }

                  return ListTile(
                    leading: leadingWidget,
                    title: Text(item['title'] ?? ''),
                    trailing: isSeries
                        ? const Badge(label: Text('SERIE'))
                        : null,
                    dense: true,
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        if (items.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () {
              onPlay();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Riproduci Ora'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
      ],
    );
  }
}
