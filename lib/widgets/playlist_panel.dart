import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/vlc_provider.dart';

class PlaylistPanel extends StatelessWidget {
  const PlaylistPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VlcProvider>(
      builder: (context, provider, _) {
        final playlist = provider.playlist;
        
        return Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.queue_music,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Playlist',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (playlist.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${playlist.length} brani',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: provider.refreshPlaylist,
                          tooltip: 'Aggiorna playlist',
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                if (playlist.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.music_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Playlist vuota',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: playlist.length,
                    itemBuilder: (context, index) {
                      final item = playlist[index];
                      return _buildPlaylistItem(context, item, provider);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistItem(
    BuildContext context,
    dynamic item,
    VlcProvider provider,
  ) {
    final isPlaying = item.isPlaying;
    final conn = provider.currentConnection;
    
    Widget leadingWidget;
    
    if (conn != null && conn.vlcPassword != null && conn.vlcPassword!.isNotEmpty) {
      final host = conn.ipAddress;
      final port = conn.port; // VlcRemote uses same port currently
      final authStr = base64Encode(utf8.encode(':${conn.vlcPassword}'));
      
      final String? extractedPosterUrl = isPlaying ? provider.status.posterUrl : null;
      final bool hasExternalPoster = extractedPosterUrl != null && extractedPosterUrl.startsWith('http');
      
      final artUrl = hasExternalPoster ? extractedPosterUrl : 'http://$host:$port/art?item=${item.id}';
      final Map<String, String>? artHeaders = hasExternalPoster ? null : {'Authorization': 'Basic $authStr'};
      
      leadingWidget = ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CachedNetworkImage(
          imageUrl: artUrl,
          httpHeaders: artHeaders,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          imageBuilder: (context, imageProvider) => GestureDetector(
            onTap: () {
              final String? plot = isPlaying ? provider.status.plot : null;
              final String? rating = isPlaying ? provider.status.rating : null;

              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  insetPadding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(ctx),
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
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: artUrl,
                                  httpHeaders: artHeaders,
                                  fit: BoxFit.contain,
                                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (plot != null || rating != null) ...[
                          const SizedBox(height: 16),
                          if (rating != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star, color: Colors.amber, size: 24),
                                const SizedBox(width: 8),
                                Text(
                                  rating,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          if (plot != null) ...[
                            const SizedBox(height: 12),
                            Flexible(
                              flex: 3,
                              child: SingleChildScrollView(
                                child: Text(
                                  plot,
                                  style: const TextStyle(fontSize: 14),
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                            ),
                          ],
                        ] else if (isPlaying) ...[
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Nessuna trama nei tag del file',
                              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 12),
                            ),
                          ),
                        ],
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
            color: isPlaying
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Text(
                '${item.index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPlaying
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: isPlaying
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Center(
              child: Text(
                '${item.index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPlaying
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      leadingWidget = Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isPlaying
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${item.index + 1}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPlaying
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isPlaying
            ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPlaying
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: ListTile(
        leading: SizedBox(
          width: 40,
          height: 40,
          child: leadingWidget,
        ),
        title: Text(
          item.displayName,
          style: TextStyle(
            fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
            color: isPlaying
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
        subtitle: item.duration != null
            ? Text(item.duration!)
            : null,
        trailing: isPlaying
            ? Icon(
                Icons.play_circle_filled,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: () => provider.goToPlaylistItem(item.index),
      ),
    );
  }
}
