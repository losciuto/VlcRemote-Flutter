import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command.dart';
import 'package:vlc_remote_flutter/services/voice/voice_command_service.dart';
import 'package:vlc_remote_flutter/services/voice/voice_language.dart';

/// Apre il pannello dei comandi vocali.
Future<void> showVoicePanel(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const VoicePanel(),
  );
}

/// Pannello dei comandi vocali.
///
/// Il microfono si attiva solo da qui: non esiste un push-to-talk globale ne'
/// una parola di attivazione. Il riconoscimento e' offline, l'audio non
/// lascia il dispositivo.
class VoicePanel extends StatefulWidget {
  const VoicePanel({super.key});

  @override
  State<VoicePanel> createState() => _VoicePanelState();
}

class _VoicePanelState extends State<VoicePanel> {
  @override
  void initState() {
    super.initState();
    // L'elenco dei microfoni e il motore si avviano all'apertura del
    // pannello: il modello, se e' gia' in locale, e' pronto in pochi
    // secondi e non serve alcun download.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final voice = context.read<VoiceCommandService>();
      voice.init();
      voice.loadInputDevices();
      voice.prepareIfModelPresent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final voice = context.watch<VoiceCommandService>();
    final theme = Theme.of(context);

    // Il foglio occupa tutta la larghezza disponibile e al massimo l'80%
    // dell'altezza. Senza i vincoli espliciti la lista si stringe alla
    // larghezza dei suoi figli e il pannello si vede storto.
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            'Comandi vocali',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Riconoscimento offline: la voce viene trascritta sul '
            'dispositivo, senza inviare nulla online.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _Microfono(voice: voice),
          const SizedBox(height: 16),
          _StatoModello(voice: voice),
          const SizedBox(height: 16),
          _Lingua(voice: voice),
          const SizedBox(height: 16),
          _Dispositivo(voice: voice),
          const SizedBox(height: 16),
          _Cronologia(voice: voice),
          const SizedBox(height: 16),
          _ComandiDisponibili(),
        ],
      ),
    );
  }
}

/// Il bottone del microfono con il livello di ingresso.
class _Microfono extends StatelessWidget {
  const _Microfono({required this.voice});

  final VoiceCommandService voice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isListening = voice.isListening;
    final bool isPreparing = voice.isPreparing;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton.filled(
              iconSize: 40,
              padding: const EdgeInsets.all(12),
              style: IconButton.styleFrom(
                backgroundColor: isListening
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              // Il pulsante resta attivo anche senza modello pronto: la
              // preparazione parte automaticamente al primo ascolto.
              onPressed: () =>
                  isListening ? voice.stopListening() : voice.startListening(),
              icon: isPreparing
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : Icon(isListening ? Icons.stop_circle : Icons.mic),
              tooltip: isListening ? 'Ferma' : 'Ascolta',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _stato(voice),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isListening ? theme.colorScheme.error : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _LivelloMicrofono(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _stato(VoiceCommandService voice) {
    if (voice.isListening) return 'In ascolto';
    if (voice.isPreparing) return 'Preparazione del modello...';
    if (voice.status == VoiceStatus.ready) return 'Pronto';
    if (voice.status == VoiceStatus.error) return 'Non disponibile';
    return 'Modello non installato';
  }
}

/// La barra che mostra il livello del microfono.
class _LivelloMicrofono extends StatelessWidget {
  const _LivelloMicrofono();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<double>(
      valueListenable: context.read<VoiceCommandService>().inputLevel,
      builder: (context, level, _) {
        // -60 dB e' il fondo della scala: sotto non si sente niente.
        final double normalized = ((level + 60) / 60).clamp(0.0, 1.0);
        final Color color = level > -6
            ? theme.colorScheme.error
            : (level > -20 ? Colors.amber : theme.colorScheme.primary);

        return Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: normalized,
                  minHeight: 8,
                  color: color,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 62,
              child: Text(
                level <= -159 ? '-- dB' : '${level.toStringAsFixed(0)} dB',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Lo stato del modello di riconoscimento.
class _StatoModello extends StatelessWidget {
  const _StatoModello({required this.voice});

  final VoiceCommandService voice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (voice.status == VoiceStatus.ready ||
        voice.status == VoiceStatus.listening) {
      return Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Modello pronto (${voice.language.modelName})',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      );
    }

    if (voice.status == VoiceStatus.error) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _messaggioErrore(voice),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modello non installato', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(
          'Il modello viene scaricato una volta sola '
          '(${voice.language.modelSizeText}) e tenuto sul dispositivo. '
          'Serve una connessione per il primo download.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: voice.isPreparing ? null : voice.prepare,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Scarica il modello'),
        ),
      ],
    );
  }

  String _messaggioErrore(VoiceCommandService voice) {
    switch (voice.error) {
      case VoiceError.none:
        return 'Errore sconosciuto';
      case VoiceError.unsupportedPlatform:
        return 'I comandi vocali non sono supportati su questa piattaforma.';
      case VoiceError.nativeLibraryMissing:
        return 'Libreria nativa Vosk non trovata: esegui l\'installazione '
            'nativa e ricompila l\'applicazione.';
      case VoiceError.modelDownloadFailed:
      case VoiceError.modelLoadFailed:
        return 'Modello di riconoscimento non disponibile: '
            '${voice.errorDetails ?? ''}';
      case VoiceError.microphoneDenied:
        return 'Accesso al microfono negato.';
      case VoiceError.recorderUnavailable:
        return 'Acquisizione audio non disponibile: '
            '${voice.errorDetails ?? ''}';
    }
  }
}

/// Il selettore della lingua del riconoscimento.
class _Lingua extends StatelessWidget {
  const _Lingua({required this.voice});

  final VoiceCommandService voice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Lingua', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButton<VoiceLanguage>(
            value: voice.language,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem<VoiceLanguage>(
                value: VoiceLanguage.italian,
                child: Text('Italiano'),
              ),
              DropdownMenuItem<VoiceLanguage>(
                value: VoiceLanguage.english,
                child: Text('Inglese'),
              ),
            ],
            onChanged: voice.isPreparing
                ? null
                : (VoiceLanguage? language) {
                    if (language != null) voice.setLanguage(language);
                  },
          ),
        ),
      ],
    );
  }
}

/// Il selettore del microfono.
class _Dispositivo extends StatelessWidget {
  const _Dispositivo({required this.voice});

  final VoiceCommandService voice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Microfono', style: theme.textTheme.bodyMedium),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButton<String?>(
            value: voice.selectedDeviceId,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox.shrink(),
            hint: const Text('Predefinito di sistema'),
            items: [
              const DropdownMenuItem<String?>(
                child: Text(
                  'Predefinito di sistema',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final device in voice.inputDevices)
                DropdownMenuItem<String?>(
                  value: device.id,
                  child: Text(device.label, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: voice.setInputDevice,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Aggiorna l\'elenco dei microfoni',
          onPressed: voice.loadingDevices ? null : voice.loadInputDevices,
        ),
      ],
    );
  }
}

/// La cronologia dei comandi riconosciuti.
class _Cronologia extends StatelessWidget {
  const _Cronologia({required this.voice});

  final VoiceCommandService voice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (voice.history.isEmpty) {
      return Text(
        'Nessun comando ancora riconosciuto.',
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Comandi riconosciuti',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: voice.clearHistory,
              child: const Text('Svuota'),
            ),
          ],
        ),
        for (final entry in voice.history)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              entry.succeeded
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              size: 20,
              color: entry.succeeded
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
            title: Text('"${entry.transcript}"'),
            subtitle: Text(_descrizione(entry)),
          ),
      ],
    );
  }

  String _descrizione(VoiceLogEntry entry) {
    switch (entry.feedback) {
      case VoiceFeedback.playlistRandom:
        return 'Playlist casuale generata (${entry.number ?? 0} video)';
      case VoiceFeedback.playlistRecent:
        return 'Playlist dei video recenti generata (${entry.number ?? 0} video)';
      case VoiceFeedback.playlistPlay:
        return 'Riproduzione avviata';
      case VoiceFeedback.stopped:
        return 'Riproduzione fermata';
      case VoiceFeedback.paused:
        return 'Riproduzione in pausa';
      case VoiceFeedback.resumed:
        return 'Riproduzione ripresa';
      case VoiceFeedback.next:
        return 'Traccia successiva';
      case VoiceFeedback.previous:
        return 'Traccia precedente';
      case VoiceFeedback.volumeUp:
        return 'Volume aumentato';
      case VoiceFeedback.volumeDown:
        return 'Volume abbassato';
      case VoiceFeedback.volumeSet:
        return 'Volume impostato al ${entry.number ?? 0}%';
      case VoiceFeedback.seekForward:
        return 'Avanzamento di ${entry.number ?? 0} secondi';
      case VoiceFeedback.seekBackward:
        return 'Ritorno di ${entry.number ?? 0} secondi';
      case VoiceFeedback.showPoster:
        return 'Locandina visualizzata su MyPlaylist';
      case VoiceFeedback.closePoster:
        return 'Locandina chiusa su MyPlaylist';
      case VoiceFeedback.posterNotAvailable:
        return 'Locandina non disponibile';
      case VoiceFeedback.notRecognized:
        return 'Comando non riconosciuto';
      case VoiceFeedback.notExecuted:
        return 'Comando non eseguito: nessun server collegato';
    }
  }
}

/// L'elenco dei comandi riconoscibili.
class _ComandiDisponibili extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comandi disponibili',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'riproduci / riprendi / pausa / ferma\n'
          'traccia successiva / traccia precedente\n'
          'alza il volume / abbassa il volume / volume 50\n'
          'avanti 30 secondi / indietro 30 secondi\n'
          'playlist casuale / playlist recenti / suona la playlist\n'
          'locandina / poster / chiudi / close',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
