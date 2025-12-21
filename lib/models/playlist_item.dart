/// Modello per rappresentare un elemento della playlist VLC
class PlaylistItem {
  final int id;
  final int index;
  final String title;
  final String? duration;
  final bool isPlaying;

  PlaylistItem({
    required this.id,
    required this.index,
    required this.title,
    this.duration,
    this.isPlaying = false,
  });

  /// Estrae il nome del file dal percorso completo
  String get displayName {
    // Rimuove il percorso e mantiene solo il nome del file
    final parts = title.split('/');
    String filename = parts.isNotEmpty ? parts.last : title;
    
    // Rimuove l'estensione del file
    final lastDot = filename.lastIndexOf('.');
    if (lastDot > 0) {
      filename = filename.substring(0, lastDot);
    }
    
    return filename;
  }

  PlaylistItem copyWith({
    int? id,
    int? index,
    String? title,
    String? duration,
    bool? isPlaying,
  }) {
    return PlaylistItem(
      id: id ?? this.id,
      index: index ?? this.index,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }

  @override
  String toString() {
    return 'PlaylistItem(id: $id, index: $index, title: $displayName, isPlaying: $isPlaying)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlaylistItem && 
           other.id == id && 
           other.index == index && 
           other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, index, title);
}
