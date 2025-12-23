/// Costanti utilizzate in tutta l'applicazione
class AppConstants {
  // Messaggi di errore
  static const String errorConnectionFailed = 'Impossibile connettersi a VLC';
  static const String errorConnectionTimeout = 'Timeout durante la connessione';
  static const String errorCommandFailed = 'Invio del comando non riuscito';
  static const String errorInvalidInput = 'Input non valido';
  static const String errorUnknown = 'Errore sconosciuto';

  // Messaggi di successo
  static const String successConnectionEstablished = 'Connesso a VLC';
  static const String successDisconnected = 'Disconnesso da VLC';
  static const String successCommandSent = 'Comando inviato';

  // Label e testi UI
  static const String appTitle = 'VLC Remote';
  static const String appDescription =
      'Telecomando remoto per VLC Media Player';

  // Nomi dei comandi VLC
  static const Map<String, String> vlcCommands = {
    'play': 'Riproduci',
    'pause': 'Pausa',
    'stop': 'Ferma',
    'next': 'Prossimo',
    'prev': 'Precedente',
    'fullscreen': 'Schermo intero',
    'quit': 'Esci',
  };

  // Intervalli di refresh
  static const int statusRefreshMs = 1000; // Ridotto da 500ms per efficienza
  static const int playlistRefreshMs = 5000;

  // Parametri di volume
  static const int volumeStepSize = 3;
  static const int maxVolumePercent = 100;
  static const int vlcVolumeMax = 256; // VLC usa 0-256 internamente
  
  // Timing comandi
  static const int commandDelayShortMs = 200; // Per play/pause/stop
  static const int commandDelayLongMs = 500;  // Per next/prev
  static const int myPlaylistReconnectDelayMs = 2000;
  
  // Timeout
  static const int connectionTimeoutMs = 2000;
  static const int commandTimeoutMs = 1500;
  static const int myPlaylistTimeoutMs = 5000;
  
  // Retry & Resilience
  static const int maxRetries = 3;
  static const int retryDelayMs = 1000;
  static const int reconnectBackoffBaseMs = 1000;
  static const int reconnectBackoffMaxMs = 10000;
  
  // Debouncing
  static const int volumeDebounceMs = 300;
  static const int seekDebounceMs = 500;
}
