/// Modello per rappresentare una connessione VLC salvata
class VlcConnection {
  final String id;
  final String name;
  final String ipAddress;
  final int port;
  final DateTime lastUsed;
  final bool isFavorite;

  // MyPlaylist Settings
  final String? myPlaylistIp;
  final int? myPlaylistPort;
  final String? myPlaylistSecretKey;

  VlcConnection({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.port,
    required this.lastUsed,
    this.isFavorite = false,
    this.myPlaylistIp,
    this.myPlaylistPort,
    this.myPlaylistSecretKey,
  });

  /// Crea una connessione da un Map (per il caricamento da SharedPreferences)
  factory VlcConnection.fromJson(Map<String, dynamic> json) {
    return VlcConnection(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
      myPlaylistIp: json['myPlaylistIp'] as String?,
      myPlaylistPort: json['myPlaylistPort'] as int?,
      myPlaylistSecretKey: json['myPlaylistSecretKey'] as String?,
    );
  }

  /// Converte la connessione in un Map (per il salvataggio in SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'port': port,
      'lastUsed': lastUsed.toIso8601String(),
      'isFavorite': isFavorite,
      'myPlaylistIp': myPlaylistIp,
      'myPlaylistPort': myPlaylistPort,
      'myPlaylistSecretKey': myPlaylistSecretKey,
    };
  }

  /// Crea una copia della connessione con alcuni campi modificati
  VlcConnection copyWith({
    String? id,
    String? name,
    String? ipAddress,
    int? port,
    DateTime? lastUsed,
    bool? isFavorite,
    String? myPlaylistIp,
    int? myPlaylistPort,
    String? myPlaylistSecretKey,
  }) {
    return VlcConnection(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      lastUsed: lastUsed ?? this.lastUsed,
      isFavorite: isFavorite ?? this.isFavorite,
      myPlaylistIp: myPlaylistIp ?? this.myPlaylistIp,
      myPlaylistPort: myPlaylistPort ?? this.myPlaylistPort,
      myPlaylistSecretKey: myPlaylistSecretKey ?? this.myPlaylistSecretKey,
    );
  }

  @override
  String toString() {
    return 'VlcConnection(name: $name, ip: $ipAddress, port: $port, myPlaylistIp: $myPlaylistIp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VlcConnection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
