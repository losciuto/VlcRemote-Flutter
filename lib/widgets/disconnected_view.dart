import 'package:flutter/material.dart';

/// Schermata mostrata quando non c'e' nessun server collegato.
///
/// E' la prima cosa che vede chi apre l'app, quindi fa tre cose insieme:
/// dice che non e' collegata, spiega come si fa a collegarsi, e contiene il
/// pulsante per arrivare alla gestione dei server. Il pulsante c'e' anche
/// quando la lista dei server e' vuota, ed e' l'unico modo di uscire da
/// questa schermata.
class DisconnectedView extends StatelessWidget {
  const DisconnectedView({
    super.key,
    required this.onManageServers,
    this.errorMessage,
  });

  final VoidCallback onManageServers;

  /// Errore dell'ultimo tentativo di connessione, mostrato sotto il pulsante.
  ///
  /// Va qui e non in un banner a parte perche' senza collegamento non c'e'
  /// nient'altro da guardare: se non si connette, la schermata vuota da sola
  /// non dice perche'.
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
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
              'Tocca l\'icona di connessione in alto a destra\n'
              'o seleziona un server salvato.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onManageServers,
              icon: const Icon(Icons.link),
              label: const Text('Gestione Server VLC'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 24),
              _BannerDiErrore(messaggio: errorMessage!),
            ],
          ],
        ),
      ),
    );
  }
}

class _BannerDiErrore extends StatelessWidget {
  const _BannerDiErrore({required this.messaggio});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(messaggio, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
