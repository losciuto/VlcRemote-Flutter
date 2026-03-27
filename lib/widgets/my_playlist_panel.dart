import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/vlc_provider.dart';

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
        final isError = provider.myPlaylistMessage.toLowerCase().contains('errore') || 
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
                const Icon(Icons.playlist_add_check_circle, size: 64, color: Colors.grey),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                        onTap: provider.isMyPlaylistBusy ? null : () => provider.mpGenerateRandom(preview: _previewMode),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.history,
                        label: 'Recenti',
                        color: Colors.blue,
                        onTap: provider.isMyPlaylistBusy ? null : () => provider.mpGenerateRecent(preview: _previewMode),
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
                        onTap: provider.isMyPlaylistBusy ? null : () => provider.mpPlay(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionCard(
                        context,
                        icon: Icons.stop,
                        label: 'Ferma',
                        color: Colors.red,
                        onTap: provider.isMyPlaylistBusy ? null : () => provider.mpStop(),
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextButton.icon(
                  onPressed: provider.isMyPlaylistBusy ? null : () => _confirmKillVlc(context, provider),
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
    final genresController = TextEditingController();
    final excludedGenresController = TextEditingController();
    final yearController = TextEditingController();
    final excludedYearController = TextEditingController();
    final actorsController = TextEditingController();
    final excludedActorsController = TextEditingController();
    final directorsController = TextEditingController();
    final excludedDirectorsController = TextEditingController();
    final limitController = TextEditingController(text: '10');
    double minRating = 0.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.filter_alt, color: Colors.blue),
              SizedBox(width: 12),
              Text('Smart Playlist Filter'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('METADATI DA INCLUDERE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                const SizedBox(height: 12),
                TextField(
                  controller: genresController,
                  decoration: const InputDecoration(
                    labelText: 'Generi',
                    hintText: 'Azione, Commedia',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(
                    labelText: 'Anni',
                    hintText: '2023, 2024',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: actorsController,
                        decoration: const InputDecoration(
                          labelText: 'Attori',
                          hintText: 'Tom Cruise',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: directorsController,
                        decoration: const InputDecoration(
                          labelText: 'Registi',
                          hintText: 'Christopher Nolan',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('METADATI DA ESCLUDERE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
                const SizedBox(height: 12),
                TextField(
                  controller: excludedGenresController,
                  decoration: const InputDecoration(
                    labelText: 'Escludi Generi',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: excludedYearController,
                  decoration: const InputDecoration(
                    labelText: 'Escludi Anni',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: excludedActorsController,
                        decoration: const InputDecoration(
                          labelText: 'Escludi Attori',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: excludedDirectorsController,
                        decoration: const InputDecoration(
                          labelText: 'Escludi Registi',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('ALTRI PARAMETRI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                const SizedBox(height: 12),
                const Text('Valutazione Minima:'),
                Slider(
                  value: minRating,
                  min: 0,
                  max: 10,
                  divisions: 20,
                  label: minRating.toStringAsFixed(1),
                  onChanged: (value) => setState(() => minRating = value),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: limitController,
                  decoration: const InputDecoration(
                    labelText: 'Limite Risultati',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            ElevatedButton(
              onPressed: () {
                List<String> split(String t) => t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                
                final genres = split(genresController.text);
                final excludedGenres = split(excludedGenresController.text);
                final years = split(yearController.text);
                final excludedYears = split(excludedYearController.text);
                final actors = split(actorsController.text);
                final excludedActors = split(excludedActorsController.text);
                final directors = split(directorsController.text);
                final excludedDirectors = split(excludedDirectorsController.text);
                final limit = int.tryParse(limitController.text);

                provider.mpGenerateFiltered(
                  genres: genres.isEmpty ? null : genres,
                  excludedGenres: excludedGenres.isEmpty ? null : excludedGenres,
                  years: years.isEmpty ? null : years,
                  excludedYears: excludedYears.isEmpty ? null : excludedYears,
                  actors: actors.isEmpty ? null : actors,
                  excludedActors: excludedActors.isEmpty ? null : excludedActors,
                  directors: directors.isEmpty ? null : directors,
                  excludedDirectors: excludedDirectors.isEmpty ? null : excludedDirectors,
                  minRating: minRating > 0 ? minRating : null,
                  limit: limit,
                  preview: _previewMode,
                );
                Navigator.pop(context);
              },
              child: const Text('Genera'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, VlcProvider provider) {
    final items = List<Map<String, dynamic>>.from(provider.pendingPlaylist);
    provider.clearPendingPlaylist(); // Clear immediately so it doesn't loop

    final ip = provider.currentConnection?.myPlaylistIp ?? '';
    final port = (provider.currentConnection?.myPlaylistPort ?? 8080) + 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
              ? const Center(child: Text('Nessun video trovato con questi filtri.'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSeries = item['isSeries'] == 1 || item['isSeries'] == true;
                    
                    final videoId = item['id'];
                    final String? rawPoster = item['posterPath'];
                    
                    Widget leadingWidget;
                    if (videoId != null && ip.isNotEmpty) {
                      final imageUrl = (rawPoster != null && rawPoster.startsWith('http')) 
                            ? rawPoster 
                            : 'http://$ip:$port/poster/$videoId';
                            
                      leadingWidget = ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 40,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.grey[800], width: 40, height: 60, child: const Icon(Icons.movie, size: 20, color: Colors.white54)),
                          errorWidget: (context, url, error) => isSeries 
                            ? const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.tv, color: Colors.white, size: 20))
                            : CircleAvatar(backgroundColor: Colors.grey[700], child: Text('${index + 1}', style: const TextStyle(color: Colors.white))),
                        ),
                      );
                    } else {
                      leadingWidget = isSeries 
                          ? const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.tv, color: Colors.white, size: 20))
                          : CircleAvatar(backgroundColor: Colors.grey[700], child: Text('${index + 1}', style: const TextStyle(color: Colors.white)));
                    }

                    return ListTile(
                      leading: leadingWidget,
                      title: Text(item['title'] ?? ''),
                      trailing: isSeries ? const Badge(label: Text('SERIE')) : null,
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
                provider.mpPlay();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Riproduci Ora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmKillVlc(BuildContext context, VlcProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Action'),
        content: const Text(
          'This will force-stop all VLC instances on the remote PC. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              provider.killAllRemoteVlc();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('KILL ALL'),
          ),
        ],
      ),
    );
  }
}
