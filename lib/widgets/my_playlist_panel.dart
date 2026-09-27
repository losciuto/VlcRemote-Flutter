import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../providers/vlc_provider.dart';
import 'playlist_preview_dialog.dart';
import 'smart_filter_dialog.dart';

class MyPlaylistPanel extends StatefulWidget {
  const MyPlaylistPanel({super.key});

  @override
  State<MyPlaylistPanel> createState() => _MyPlaylistPanelState();
}

class _MyPlaylistPanelState extends State<MyPlaylistPanel> {
  bool _previewMode = true;
  bool _wasBusy = false;

  @override
  void initState() {
    super.initState();
    // Aggiungi un listener per monitorare il completamento delle attività MyPlaylist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<VlcProvider>();
      provider.addListener(_onProviderChange);
    });
  }

  @override
  void dispose() {
    // Rimuovi il listener per evitare perdite di memoria
    try {
      final provider = context.read<VlcProvider>();
      provider.removeListener(_onProviderChange);
    } catch (_) {}
    super.dispose();
  }

  void _onProviderChange() {
    if (!mounted) return;
    final provider = context.read<VlcProvider>();

    // Rileva quando il server ha finito di elaborare (da busy a non busy)
    if (_wasBusy && !provider.isMyPlaylistBusy) {
      if (provider.myPlaylistMessage.isNotEmpty) {
        final isError =
            provider.myPlaylistMessage.toLowerCase().contains('errore') ||
            provider.myPlaylistMessage.toLowerCase().contains('failed');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.myPlaylistMessage),
            backgroundColor: isError ? Colors.red : Colors.blue,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    _wasBusy = provider.isMyPlaylistBusy;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VlcProvider>(
      builder: (context, provider, _) {
        if (!provider.isMyPlaylistConfigured) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.playlist_add_check_circle,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                const Text(
                  'MyPlaylist non configurato',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aggiungi i dettagli MyPlaylist nelle impostazioni di connessione.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Show preview dialog if pending playlist is not empty
        if (provider.pendingPlaylist.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPreviewDialog(context, provider);
          });
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Smart Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (provider.isMyPlaylistBusy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Toggle per Anteprima
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Anteprima playlist prima di riprodurre'),
                    Switch(
                      value: _previewMode,
                      onChanged: (val) => setState(() => _previewMode = val),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (provider.myPlaylistMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: provider.myPlaylistMessage.startsWith('OK')
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        provider.myPlaylistMessage,
                        style: TextStyle(
                          color: provider.myPlaylistMessage.startsWith('OK')
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.shuffle,
                        label: 'Random',
                        color: Colors.purple,
                        onTap: provider.isMyPlaylistBusy
                            ? null
                            : () => provider.mpGenerateRandom(
                                preview: _previewMode,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.history,
                        label: 'Recenti',
                        color: Colors.blue,
                        onTap: provider.isMyPlaylistBusy
                            ? null
                            : () => provider.mpGenerateRecent(
                                preview: _previewMode,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.play_arrow,
                        label: 'Riproduci',
                        color: Colors.green,
                        onTap: provider.isMyPlaylistBusy
                            ? null
                            : () => provider.mpPlay(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.stop,
                        label: 'Ferma',
                        color: Colors.red,
                        onTap: provider.isMyPlaylistBusy
                            ? null
                            : () => provider.mpStop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: provider.isMyPlaylistBusy
                      ? null
                      : () => _showFilterDialog(context, provider),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Genera con Filtri'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextButton.icon(
                  onPressed: provider.isMyPlaylistBusy
                      ? null
                      : () => _confirmKillVlc(context, provider),
                  icon: const Icon(Icons.dangerous_outlined, size: 18),
                  label: const Text('Kill all VLC instances'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red[400],
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
            color: color.withValues(alpha: 0.05),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, VlcProvider provider) {
    showDialog(
      context: context,
      builder: (context) => SmartFilterDialog(
        last: provider.lastFilterSettings,
        previewMode: _previewMode,
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, VlcProvider provider) {
    final items = List<Map<String, dynamic>>.from(provider.pendingPlaylist);
    provider.clearPendingPlaylist(); // Clear immediately so it doesn't loop

    final ip = provider.currentConnection?.myPlaylistIp ?? '';
    final port =
        (provider.currentConnection?.myPlaylistPort ??
            AppConstants.defaultMyPlaylistPort) +
        AppConstants.myPlaylistPosterPortOffset;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PlaylistPreviewDialog(
        items: items,
        ip: ip,
        port: port,
        onPlay: provider.mpPlay,
      ),
    );
  }

  void _confirmKillVlc(BuildContext context, VlcProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma azione'),
        content: const Text(
          'Verranno chiuse in modo forzato tutte le istanze di VLC sul '
          'PC remoto. Sei sicuro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              provider.killAllRemoteVlc();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Killa tutte'),
          ),
        ],
      ),
    );
  }
}
