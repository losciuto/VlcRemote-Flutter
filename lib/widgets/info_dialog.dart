import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:vlc_remote_flutter/providers/vlc_provider.dart';

/// Apre il dialogo delle informazioni.
///
/// Se l'utente chiede di fermare VLC, chi ha aperto il dialogo decide cosa
/// succede dopo: il passaggio e' una richiesta e non una faccia, perche'
/// fermare tutte le istanze di VLC sul PC remoto interrompe quello che
/// l'utente sta ascoltando, e la conferma va chiesta da chi ha ancora uno
/// schermo vivo.
Future<void> showInfoDialog(
  BuildContext context, {
  required VoidCallback onKillRequested,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => InfoDialog(onKillRequested: onKillRequested),
  );
}

class InfoDialog extends StatelessWidget {
  const InfoDialog({super.key, required this.onKillRequested});

  final VoidCallback onKillRequested;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // `scrollable` e' il modo previsto da Flutter per un dialogo piu' alto
      // dello schermo, e fa piu' di mettergli uno `SingleChildScrollView`
      // attorno al contenuto: quello, dentro l'`IntrinsicWidth` del dialogo,
      // misura i figli con larghezza illimitata e il pulsante a tutta
      // larghezza faceva traboccare tutto di 92 pixel.
      scrollable: true,
      // Il titolo dentro una `Row` senza `Flexible` fa traboccare il dialogo
      // su uno schermo stretto: l'icona e il testo si spingono fuori e dalla
      // `AlertDialog` esce un'eccezione di layout. Con `Flexible` il titolo si
      // accorcia con i puntini.
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 12),
          Flexible(child: Text('Informazioni')),
        ],
      ),
      // L'ultima riga e' il pulsante che ferma VLC, e su uno schermo basso
      // finiva sotto il bordo inferiore del dialogo: l'azione che interrompe
      // la riproduzione era proprio quella che non si vedeva.
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
                onKillRequested();
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
    );
  }
}

/// Chiede conferma prima di terminare tutte le istanze di VLC sul PC remoto.
///
/// Si chiama con il contesto della schermata, non con quello del dialogo delle
/// informazioni: quel dialogo e' gia' stato chiuso, e riusare il suo contesto
/// funziona solo perche' la chiusura non e' ancora finita. Un giro che regge
/// per caso, e su una schermata che interrompe la riproduzione in casa il
/// "funziona per caso" costa un avviso che non parte.
Future<void> showConfirmKillVlc(BuildContext screenContext) {
  return showDialog<void>(
    context: screenContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Conferma Azione'),
      content: const Text(
        'Questa azione terminerà forzatamente tutte le istanze di VLC in '
        'esecuzione sul PC. Vuoi procedere?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('ANNULLA'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            _inviaComandoKill(screenContext);
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('PROCEDI'),
        ),
      ],
    ),
  );
}

void _inviaComandoKill(BuildContext screenContext) {
  Provider.of<VlcProvider>(screenContext, listen: false).killAllRemoteVlc();

  ScaffoldMessenger.of(screenContext).showSnackBar(
    const SnackBar(
      content: Text('Comando Kill VLC inviato'),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 3),
    ),
  );
}
