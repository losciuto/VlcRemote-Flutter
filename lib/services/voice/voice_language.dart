/// Lingue supportate dai comandi vocali.
///
/// Ogni lingua fa riferimento a un modello Vosk "small", che viene
/// scaricato al primo utilizzo e tenuto nella cartella dati dell'app.
enum VoiceLanguage {
  italian(
    code: 'it',
    modelName: 'vosk-model-small-it-0.22',
    modelUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip',
    modelSizeBytes: 49665141,
  ),
  english(
    code: 'en',
    modelName: 'vosk-model-small-en-us-0.15',
    modelUrl:
        'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
    modelSizeBytes: 41205931,
  );

  const VoiceLanguage({
    required this.code,
    required this.modelName,
    required this.modelUrl,
    required this.modelSizeBytes,
  });

  /// Codice della lingua, usato anche come chiave nelle impostazioni.
  final String code;

  /// Nome del modello Vosk, coincide con la cartella estratta.
  final String modelName;

  /// Indirizzo del modello compresso.
  final String modelUrl;

  /// Dimensione del modello compresso, in byte.
  final int modelSizeBytes;

  /// Dimensione del modello in un formato leggibile.
  String get modelSizeText {
    final double mb = modelSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MiB';
  }

  /// Ricostruisce la lingua dal codice salvato nelle impostazioni.
  static VoiceLanguage fromCode(String? code) {
    for (final language in VoiceLanguage.values) {
      if (language.code == code) return language;
    }
    return VoiceLanguage.italian;
  }
}
