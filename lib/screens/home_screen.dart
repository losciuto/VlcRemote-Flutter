import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vlc_provider.dart';
import '../widgets/connection_dialog.dart';
import '../widgets/control_panel.dart';
import '../widgets/now_playing_card.dart';
import '../widgets/playlist_panel.dart';
import '../widgets/my_playlist_panel.dart';
import '../config/app_config.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'VLC Remote',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          Consumer<VlcProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: Icon(
                  provider.isConnected ? Icons.link : Icons.link_off,
                  color: provider.isConnected ? Colors.green : Colors.grey,
                ),
                onPressed: () => _showConnectionDialog(context),
                tooltip: provider.isConnected
                    ? 'Connesso a ${provider.currentConnection?.name}'
                    : 'Non connesso',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'Informazioni',
          ),
        ],
      ),
      body: Consumer<VlcProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Barra di Stato Globale (Avvisi di Collegamento)
              _buildStatusBar(context, provider),
              
              Expanded(
                child: _buildMainContent(context, provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<VlcProvider>(
        builder: (context, provider, _) {
          if (!provider.isConnected) return const SizedBox.shrink();
          
          return FloatingActionButton(
            onPressed: () => provider.refreshStatus(),
            tooltip: 'Aggiorna stato',
            child: const Icon(Icons.refresh),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context, VlcProvider provider) {
    // Definizione stati VLC
    String vlcStatusText = 'DISCONNESSO';
    Color vlcColor = Colors.red;
    if (provider.isConnecting) {
      vlcStatusText = 'TENTATIVO...';
      vlcColor = Colors.orange;
    } else if (provider.isConnected) {
      vlcStatusText = 'COLLEGATO';
      vlcColor = Colors.green;
    }

    // Definizione stati MyPlaylist
    String mpStatusText = 'NON CONFIG.';
    Color mpColor = Colors.grey;
    if (provider.isMyPlaylistBusy) {
      mpStatusText = 'INVIO...';
      mpColor = Colors.orange;
    } else if (provider.isMyPlaylistConfigured) {
      if (provider.lastMpStatus == 'SUCCESS') {
        mpStatusText = 'CONNESSO';
        mpColor = Colors.blue;
      } else if (provider.lastMpStatus == 'ERROR') {
        mpStatusText = 'NON CONNESSO';
        mpColor = Colors.red;
      } else {
        mpStatusText = 'NON TESTATO';
        mpColor = Colors.orange.withValues(alpha: 0.7);
      }
    }

    final String vlcIp = provider.currentConnection?.ipAddress ?? '---';
    final String mpIp = provider.currentConnection?.myPlaylistIp ?? '---';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusItem(
                context,
                'VLC',
                vlcStatusText,
                vlcColor,
                Icons.link,
                vlcIp,
              ),
              const SizedBox(width: 12),
              _buildStatusItem(
                context,
                'MP',
                mpStatusText,
                mpColor,
                Icons.playlist_add_check,
                mpIp,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, String label, String status, Color color, IconData icon, String ip) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              '$label: ',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
            Flexible(
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            Text(
              ip,
              style: TextStyle(fontSize: 8, color: Colors.grey[600], fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, VlcProvider provider) {
    if (provider.isConnecting) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connessione in corso...'),
          ],
        ),
      );
    }

    if (!provider.isConnected) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: 80,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 24),
              Text(
                'Non connesso a VLC',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tocca l\'icona di connessione in alto a destra\no seleziona un server salvato.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _showConnectionDialog(context),
                icon: const Icon(Icons.link),
                label: const Text('Gestione Server VLC'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
              if (provider.errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          provider.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card "Now Playing"
          const NowPlayingCard(),
          const SizedBox(height: 16),
          
          // Pannello di controllo VLC
          const ControlPanel(),
          const SizedBox(height: 24),

          // Bottone "Smart Actions"
          ElevatedButton.icon(
            onPressed: () => _showSmartActionsSheet(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Smart Actions'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          
          // Bottone "Apri Playlist"
          ElevatedButton.icon(
            onPressed: () => _showPlaylistSheet(context),
            icon: const Icon(Icons.queue_music),
            label: const Text('Apri Playlist VLC'),
            style: ElevatedButton.styleFrom(
             padding: const EdgeInsets.symmetric(vertical: 16),
             textStyle: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showSmartActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              child: const MyPlaylistPanel(),
            );
          },
        );
      },
    );
  }

  void _showPlaylistSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    "Playlist",
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
            );
          },
        );
      },
    );
  }

  void _showConnectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ConnectionDialog(),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Text('Informazioni'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'VLC Remote Flutter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Versione ${AppConfig.appVersion}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Text(
              'Telecomando remoto per VLC Media Player',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Sviluppato da: losciuto',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              'Versione Flutter migliorata - Gennaio 2026',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Manutenzione:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _confirmKillVlc(context);
                },
                icon: const Icon(Icons.terminal, color: Colors.white),
                label: const Text('Killa tutte le istanze VLC'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CHIUDI'),
          ),
        ],
      ),
    );
  }

  void _confirmKillVlc(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Azione'),
        content: const Text(
          'Questa azione terminerà forzatamente tutte le istanze di VLC in esecuzione sul PC. Vuoi procedere?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ANNULLA'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final provider = Provider.of<VlcProvider>(context, listen: false);
              provider.killAllRemoteVlc();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Comando Kill VLC inviato'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('PROCEDI'),
          ),
        ],
      ),
    );
  }
}
