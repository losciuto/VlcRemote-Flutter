/// Costanti utilizzate in tutta l'applicazione
class AppConstants {
  // Messaggi di errore
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

  // Porte di default
  // Attenzione: la porta del server MyPlaylist e' il default del lato server
  // (MyPlaylist/lib/services/settings_service.dart). Il server espone le
  // immagini sull'offset indicato qui: non cambiarlo senza accordo.
  static const int defaultMyPlaylistPort = 8080;
  static const int myPlaylistPosterPortOffset = 1;

  // Porta della Web API di VLC (interfaccia http di VLC, non MyPlaylist)
  static const int defaultVlcHttpPort = 8000;

  // Parametri di volume
  static const int volumeStepSize = 3;
  static const int maxVolumePercent = 100;
  static const int vlcVolumeMax = 256; // VLC usa 0-256 internamente

  // Timing comandi
  static const int commandDelayShortMs = 200; // Per play/pause/stop
  static const int commandDelayLongMs = 500; // Per next/prev
  static const int myPlaylistReconnectDelayMs = 2000;

  // Timeout
  static const int connectionTimeoutMs = 2000;
  static const int commandTimeoutMs = 1500;
  static const int myPlaylistTimeoutMs = 5000;
  static const int updateCheckTimeoutMs = 5000;

  /// Attesa massima per la risposta a un comando MyPlaylist.
  ///
  /// Distincta da [myPlaylistTimeoutMs], che e' il timeout di connessione: la
  /// risposta arriva dopo che il collegamento e' gia' stato stabilito, e una
  /// playlist generata puo' essere pesante. Era scritto a mano come 10 secondi
  /// e senza nome, quindi non risultava da nessuna parte.
  static const int myPlaylistResponseTimeoutMs = 10000;

  // Aggiornamento
  // Suffix dell'asset che contiene l'impronta SHA-256 dell'APK. La sua
  // assenza blocca l'installazione: un APK non verificato non viene mai
  // eseguito, perche' sul canale degli aggiornamenti non c'e' una firma
  // attendibile a cui agganciarsi.
  static const String apkChecksumSuffix = '.sha256';
  static const int updateDownloadTimeoutMs = 120000;
  static const int updateChecksumTimeoutMs = 10000;
  static const int maxApkSizeBytes = 200 * 1024 * 1024;

  // Retry & Resilience
  static const int maxRetries = 3;
  static const int reconnectBackoffBaseMs = 1000;
  static const int reconnectBackoffMaxMs = 10000;

  // Debouncing
  static const int volumeDebounceMs = 300;
}
