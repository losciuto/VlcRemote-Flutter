/// Comandi riconosciuti dal parser vocale.
enum VoiceCommandType {
  /// Genera una playlist casuale e la avvia.
  playlistRandom,

  /// Genera una playlist con i video piu' recenti e la avvia.
  playlistRecent,

  /// Avvia la playlist corrente.
  playlistPlay,

  /// Ferma il player.
  playerStop,

  /// Mette in pausa la riproduzione nel VLC esterno.
  vlcPause,

  /// Riprende la riproduzione nel VLC esterno.
  vlcResume,

  /// Passa alla traccia successiva nel VLC esterno.
  vlcNext,

  /// Torna alla traccia precedente nel VLC esterno.
  vlcPrevious,

  /// Alza il volume del VLC esterno.
  vlcVolumeUp,

  /// Abbassa il volume del VLC esterno.
  vlcVolumeDown,

  /// Imposta il volume del VLC esterno a una percentuale.
  vlcVolumeSet,

  /// Avanza nella riproduzione di un numero di secondi.
  vlcSeekForward,

  /// Torna indietro nella riproduzione di un numero di secondi.
  vlcSeekBackward,

  /// Mostra la locandina del film in corso di riproduzione (solo MyPlaylist).
  showPoster,

  /// Chiude la locandina del film in corso di riproduzione (solo MyPlaylist).
  closePoster,
}

/// Esito dell'analisi di una frase trascritta.
class VoiceCommand {
  const VoiceCommand({required this.type, this.number});

  final VoiceCommandType type;

  /// Numero associato al comando: quanti video generare, quanti secondi
  /// spostarsi, quale volume impostare. Nullo quando il comando non ne usa.
  final int? number;

  @override
  String toString() => 'VoiceCommand(${type.name}, number: $number)';
}

/// Esito sintetico di un comando, mostrato nella cronologia.
enum VoiceFeedback {
  playlistRandom,
  playlistRecent,
  playlistPlay,
  stopped,
  paused,
  resumed,
  next,
  previous,
  volumeUp,
  volumeDown,
  volumeSet,
  seekForward,
  seekBackward,
  showPoster,
  posterNotAvailable,
  closePoster,
  notRecognized,

  /// Comando riconosciuto ma non eseguibile (per esempio: nessun server
  /// collegato al momento).
  notExecuted,
}

/// Una riga della cronologia dei comandi vocali.
class VoiceLogEntry {
  VoiceLogEntry({
    required this.transcript,
    required this.feedback,
    required this.timestamp,
    this.command,
    this.number,
    this.succeeded = true,
  });

  /// Testo riconosciuto dal motore vocale.
  final String transcript;

  /// Esito del comando.
  VoiceFeedback feedback;

  /// Momento in cui il comando e' stato eseguito.
  final DateTime timestamp;

  /// Comando riconosciuto, nullo se la frase non corrisponde a nulla.
  final VoiceCommand? command;

  /// Numero utilizzato dal comando, se presente.
  int? number;

  /// False quando il comando non e' stato eseguito.
  bool succeeded;
}
