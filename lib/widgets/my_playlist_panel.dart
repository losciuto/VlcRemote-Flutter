import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vlc_provider.dart';

class MyPlaylistPanel extends StatefulWidget {
  const MyPlaylistPanel({super.key});

  @override
  State<MyPlaylistPanel> createState() => _MyPlaylistPanelState();
}

class _MyPlaylistPanelState extends State<MyPlaylistPanel> {
  bool _previewMode = true;

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
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.red.withOpacity(0.1),
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
                  onPressed: provider.isMyPlaylistBusy ? null : () => _showFilterDialog(context, provider),
                  icon: const Icon(Icons.filter_list),
                  label: const Text('Genera con Filtri'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(12),
            color: color.withOpacity(0.05),
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
    final yearController = TextEditingController();
    final limitController = TextEditingController(text: '50');
    double minRating = 0.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.filter_list, color: Colors.blue),
              SizedBox(width: 12),
              Text('Genera con Filtri'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filtri Avanzati', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: genresController,
                  decoration: const InputDecoration(
                    labelText: 'Generi (separati da virgola)',
                    hintText: 'Azione, Commedia',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: yearController,
                  decoration: const InputDecoration(
                    labelText: 'Anni (separati da virgola)',
                    hintText: '2023, 2024',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
                const SizedBox(height: 16),
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
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.format_list_numbered),
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
                final genres = genresController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final years = yearController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                final limit = int.tryParse(limitController.text);

                provider.mpGenerateFiltered(
                  genres: genres.isEmpty ? null : genres,
                  years: years.isEmpty ? null : years,
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
    final titles = List<String>.from(provider.pendingPlaylist);
    provider.clearPendingPlaylist(); // Clear immediately so it doesn't loop

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            const Icon(Icons.playlist_play, size: 48, color: Colors.blue),
            const SizedBox(height: 8),
            Text('Anteprima Playlist (${titles.length})'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: titles.isEmpty 
              ? const Center(child: Text('Nessun video trovato con questi filtri.'))
              : ListView.builder(
                  itemCount: titles.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(titles[index]),
                    dense: true,
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          if (titles.isNotEmpty)
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
}
