import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/vlc_provider.dart';
import '../widgets/connection_dialog.dart';
import '../widgets/control_panel.dart';
import '../widgets/now_playing_card.dart';
import '../widgets/status_bar.dart';
import '../widgets/playlist_panel.dart';
import '../widgets/my_playlist_panel.dart';
import '../widgets/update_dialog.dart';
import '../services/update_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // Controlla gli aggiornamenti dopo che il frame è stato renderizzato
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final release = await updateService.checkUpdate();

    if (release != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => UpdateDialog(release: release),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/icon/icon.png', width: 32, height: 32),
            ),
            const SizedBox(width: 12),
            // Su uno schermo stretto il titolo non ci sta accanto alle
            // azioni e finisce sopra l'icona di connessione. Con `Flexible`
            // si accorcia con i puntini invece di uscire dai bordi.
            Flexible(
              child: Text(
                'VLC Remote',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
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
      // Il corpo arriva fino in fondo allo schermo: senza questo, l'ultimo
      // pannello finisce sotto la barra dei gesti del telefono e con i
      // pulsanti di volume sul bordo. La `AppBar` copre gia' il bordo
      // superiore, quindi qui serve solo il basso.
      body: SafeArea(
        top: false,
        child: Consumer<VlcProvider>(
          builder: (context, provider, _) {
            return Column(
              children: [
                // Barra di Stato Globale (Avvisi di Collegamento)
                StatusBar.forProvider(provider),

                Expanded(child: _buildMainContent(context, provider)),
              ],
            );
          },
        ),
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
              Icon(Icons.cloud_off, size: 80, color: Colors.grey[600]),
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
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
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
              foregroundColor: Theme.of(
                context,
              ).colorScheme.onSecondaryContainer,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/icon/icon.png', height: 80),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'VLC Remote Flutter',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // La versione arriva da pubspec.yaml, non da una costante nel
            // codice: era la prima cosa che smetteva di corrispondere, e il
            // controllo degli aggiornamenti ne legge gia' una copia.
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final versione = snapshot.data?.version;
                return Text(
                  versione == null
                      ? 'Versione sconosciuta'
                      : 'Versione $versione',
                  style: TextStyle(color: Colors.grey[600]),
                );
              },
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
              'Versione Flutter migliorata - Marzo 2026',
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
