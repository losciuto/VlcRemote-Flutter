import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';
import 'package:vlc_remote_flutter/services/update_service.dart';
import 'package:vlc_remote_flutter/widgets/bottom_sheets.dart';
import 'package:vlc_remote_flutter/widgets/connection_dialog.dart';
import 'package:vlc_remote_flutter/widgets/control_panel.dart';
import 'package:vlc_remote_flutter/widgets/disconnected_view.dart';
import 'package:vlc_remote_flutter/widgets/info_dialog.dart';
import 'package:vlc_remote_flutter/widgets/now_playing_card.dart';
import 'package:vlc_remote_flutter/widgets/status_bar.dart';
import 'package:vlc_remote_flutter/widgets/update_dialog.dart';

/// La schermata principale.
///
/// E' rimasta solo la struttura: cosa mostrare quando si e' collegati e cosa
/// mostrare quando no stanno in [_HomeScreenState._contenutoConnesso] e
/// [DisconnectedView], e ogni foglio, dialogo e pannello e' in un file suo.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();

    // Controlla gli aggiornamenti dopo che il frame e' stato renderizzato:
    // chiedere una release richiede una richiesta di rete, e farla mentre si
    // costruisce il primo frame blocca la schermata.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    final release = await UpdateService().checkUpdate();

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
              borderRadius: BorderRadius.all(Radius.circular(8)),
              child: Image.asset('assets/icon/icon.png', width: 32, height: 32),
            ),
            const SizedBox(width: 12),
            // Su uno schermo stretto il titolo non ci sta accanto alle
            // azioni e finisce sopra l'icona di connessione. Con `Flexible`
            // si accorcia con i puntini invece di uscire dai bordi.
            const Flexible(
              child: Text(
                'VLC Remote',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
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
                onPressed: _showConnectionDialog,
                tooltip: provider.isConnected
                    ? 'Connesso a ${provider.currentConnection?.name}'
                    : 'Non connesso',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showInfoDialog(
              // `this.context` e non quello del dialogo: la conferma di
              // fermare VLC viene richiesta dopo che il dialogo si e' chiuso,
              // e un contesto gia' smontato non fa piu' quello che deve fare.
              context,
              onKillRequested: () => showConfirmKillVlc(this.context),
            ),
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
                StatusBar.forProvider(provider),
                Expanded(child: _contenuto(provider)),
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

  Widget _contenuto(VlcProvider provider) {
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
      return DisconnectedView(
        onManageServers: _showConnectionDialog,
        errorMessage: provider.errorMessage,
      );
    }

    return _contenutoConnesso();
  }

  Widget _contenutoConnesso() {
    final schema = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const NowPlayingCard(),
          const SizedBox(height: 16),

          const ControlPanel(),
          const SizedBox(height: 24),

          // Bottone "Smart Actions"
          ElevatedButton.icon(
            onPressed: () => showSmartActionsSheet(context),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Smart Actions'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: schema.secondaryContainer,
              foregroundColor: schema.onSecondaryContainer,
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bottone "Apri Playlist"
          ElevatedButton.icon(
            onPressed: () => showPlaylistSheet(context),
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

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => const ConnectionDialog(),
    );
  }
}
