/// Modello per rappresentare lo stato corrente di VLC
class VlcStatus {
  final String nowPlaying;
  final int currentTime; // in secondi
  final int totalTime; // in secondi
  final int? volume; // 0-100 (opzionale)
  final bool isPlaying;
  final bool isFullscreen;

  VlcStatus({
    this.nowPlaying = 'Nessun video in riproduzione',
    this.currentTime = 0,
    this.totalTime = 0,
    this.volume,
    this.isPlaying = false,
    this.isFullscreen = false,
  });

  /// Formatta il tempo in formato mm:ss
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// Restituisce il tempo corrente formattato
  String get currentTimeFormatted => formatTime(currentTime);

  /// Restituisce il tempo totale formattato
  String get totalTimeFormatted => formatTime(totalTime);

  /// Restituisce la percentuale di progresso (0-100)
  double get progress {
    if (totalTime == 0) return 0.0;
    return (currentTime / totalTime * 100).clamp(0.0, 100.0);
  }

  VlcStatus copyWith({
    String? nowPlaying,
    int? currentTime,
    int? totalTime,
    int? volume,
    bool? isPlaying,
    bool? isFullscreen,
  }) {
    return VlcStatus(
      nowPlaying: nowPlaying ?? this.nowPlaying,
      currentTime: currentTime ?? this.currentTime,
      totalTime: totalTime ?? this.totalTime,
      volume: volume ?? this.volume,
      isPlaying: isPlaying ?? this.isPlaying,
      isFullscreen: isFullscreen ?? this.isFullscreen,
    );
  }

  @override
  String toString() {
    return 'VlcStatus(nowPlaying: $nowPlaying, time: $currentTimeFormatted/$totalTimeFormatted, volume: $volume%, isPlaying: $isPlaying)';
  }
}
