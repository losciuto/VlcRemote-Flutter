import 'package:vlc_remote_flutter/providers/vlc_provider.dart';

import 'voice_command.dart';

/// Esegue i comandi riconosciuti dal motore vocale.
///
/// E' un'interfaccia perche' il motore non deve conoscere il provider: cosi'
/// il riconoscimento si puo' provare con un esecutore finto, senza aprire
/// una socket e senza toccare VLC.
abstract class VoiceCommandExecutor {
  /// Esegue il comando e restituisce true se e' stato eseguito.
  ///
  /// False significa che non era possibile eseguirlo: per esempio nessun
  /// server e' collegato, o il server MyPlaylist non e' configurato.
  Future<bool> execute(VoiceCommand command);
}

/// Esecutore che agisce sul provider dell'applicazione.
///
/// Riusa i metodi gia' presenti nel provider: la socket resta una sola e la
/// UI si aggiorna come per i pulsanti premuti a mano.
class VlcVoiceCommandExecutor implements VoiceCommandExecutor {
  VlcVoiceCommandExecutor(this.provider);

  final VlcProvider provider;

  @override
  Future<bool> execute(VoiceCommand command) async {
    switch (command.type) {
      case VoiceCommandType.playlistRandom:
        if (!provider.isMyPlaylistConfigured) return false;
        await provider.mpGenerateRandom(count: command.number);
        return true;

      case VoiceCommandType.playlistRecent:
        if (!provider.isMyPlaylistConfigured) return false;
        await provider.mpGenerateRecent(count: command.number);
        return true;

      case VoiceCommandType.playlistPlay:
        if (!provider.isMyPlaylistConfigured) return false;
        await provider.mpPlay();
        return true;

      case VoiceCommandType.playerStop:
        if (!provider.isConnected) return false;
        await provider.stop();
        return true;

      case VoiceCommandType.vlcPause:
        if (!provider.isConnected) return false;
        await provider.pause();
        return true;

      case VoiceCommandType.vlcResume:
        if (!provider.isConnected) return false;
        await provider.play();
        return true;

      case VoiceCommandType.vlcNext:
        if (!provider.isConnected) return false;
        await provider.next();
        return true;

      case VoiceCommandType.vlcPrevious:
        if (!provider.isConnected) return false;
        await provider.previous();
        return true;

      case VoiceCommandType.vlcVolumeUp:
        if (!provider.isConnected) return false;
        await provider.volumeUp();
        return true;

      case VoiceCommandType.vlcVolumeDown:
        if (!provider.isConnected) return false;
        await provider.volumeDown();
        return true;

      case VoiceCommandType.vlcVolumeSet:
        if (!provider.isConnected) return false;
        final double percent = (command.number ?? 100).clamp(0, 100).toDouble();
        await provider.setVolume(percent);
        return true;

      case VoiceCommandType.vlcSeekForward:
        return _seek(command.number ?? 30, forward: true);

      case VoiceCommandType.vlcSeekBackward:
        return _seek(command.number ?? 30, forward: false);
    }
  }

  /// Spostamento nella traccia, in avanti o indietro.
  ///
  /// Il comando RC `seek` di VLC e' assoluto, quindi la posizione di partenza
  /// viene letta dallo stato corrente: il provider la aggiorna a ogni giro
  /// di polling.
  Future<bool> _seek(int seconds, {required bool forward}) async {
    if (!provider.isConnected) return false;

    final int total = provider.status.totalTime;
    if (total <= 0) return false;

    final int current = provider.status.currentTime;
    final int target = forward ? current + seconds : current - seconds;
    if (target < 0 || target > total) return false;

    await provider.seekTo(target.toDouble());
    return true;
  }
}
