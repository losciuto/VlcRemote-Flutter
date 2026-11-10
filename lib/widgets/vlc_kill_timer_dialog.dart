import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';

/// Dialog per configurare il timer di spegnimento VLC su MyPlaylist (server side).
Future<void> showVlcKillTimerDialog(BuildContext context) async {
  final provider = context.read<VlcProvider>();

  if (!provider.isMyPlaylistConfigured) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('MyPlaylist non configurato'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  // Carica le impostazioni attuali
  final result = await provider.mpGetVlcKillTimer();

  bool enabled = result['enabled'] ?? false;
  String time = result['time'] ?? '23:59';

  if (!context.mounted) return;

  final timeController = TextEditingController(text: time);

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Timer Spegnimento VLC'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Imposta un\'ora per terminare automaticamente VLC su MyPlaylist.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Abilita Timer'),
                subtitle: const Text(
                    'Quando attivo, VLC verrà chiuso all\'ora specificata'),
                value: enabled,
                onChanged: (val) => setState(() => enabled = val),
                activeThumbColor: Colors.green,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: timeController,
                decoration: const InputDecoration(
                  labelText: 'Ora di spegnimento (24h)',
                  hintText: 'Es. 23:30',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.datetime,
                onChanged: (value) {
                  final regex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
                  if (!regex.hasMatch(value)) {
                    timeController.text = time; // Ripristina valore valido
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Nota: Il timer controlla l\'ora ogni minuto su MyPlaylist. '
                'Quando l\'ora corrente corrisponde a quella impostata, '
                'VLC viene terminato forzatamente (pkill su Linux, taskkill su Windows). '
                'Il timer funziona solo mentre MyPlaylist è in esecuzione.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTime = timeController.text.trim();
              final regex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
              if (!regex.hasMatch(newTime)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Formato ora non valido (usa HH:mm 24h)'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(context).pop();

              final result = await provider.mpSetVlcKillTimer(
                enabled: enabled,
                time: newTime,
              );

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'Impostazioni aggiornate'),
                  backgroundColor: result['status'] == 'success'
                      ? Colors.green
                      : Colors.red,
                ),
              );
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    ),
  );
}