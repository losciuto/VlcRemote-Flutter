/// Configurazione dell'applicazione VLC Remote
class AppConfig {
  // Versione dell'app
  static const String appVersion = '1.1.0';
  static const String appBuildNumber = '1';

  // Impostazioni di connessione
  static const int socketTimeoutMs = 2000;
  static const int statusUpdateIntervalSeconds = 1;
  static const int commandDelayMs = 200;

  // Host e porta predefiniti di VLC
  static const String defaultVlcHost = '127.0.0.1';
  static const int defaultVlcPort =
      4242; // Porta standard interfaccia RC di VLC

  // Impostazioni UI
  static const int maxSavedConnections = 20;
  static const bool enableAnimations = true;

  // Limiti e vincoli
  static const int minVolumeLevel = 0;
  static const int maxVolumeLevel = 100;
  static const int maxPlaylistDisplayItems = 100;

  /// Verifica se la configurazione è valida
  static bool isValid() {
    return appVersion.isNotEmpty &&
        defaultVlcPort > 0 &&
        defaultVlcPort < 65535;
  }

  /// Ottiene il timeout come Duration
  static Duration getSocketTimeout() {
    return Duration(milliseconds: socketTimeoutMs);
  }

  /// Ottiene l'intervallo di aggiornamento dello stato come Duration
  static Duration getStatusUpdateInterval() {
    return Duration(seconds: statusUpdateIntervalSeconds);
  }

  /// URL di connessione predefinito
  static String get defaultConnectionUrl =>
      'http://$defaultVlcHost:$defaultVlcPort';
}
