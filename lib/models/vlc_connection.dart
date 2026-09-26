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

  // VLC HTTP Settings
  final String? vlcPassword;

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
    this.vlcPassword,
  });

  /// Crea una connessione da un Map (per il caricamento da SharedPreferences)
  ///
  /// La lettura è tollerante: un campo mancante o di tipo errato viene
  /// normalizzato invece di far fallire il cast. Serve a evitare che un solo
  /// record malformato (per esempio scritto da una versione precedente)
  /// faccia perdere l'intero elenco delle connessioni.
  factory VlcConnection.fromJson(Map<String, dynamic> json) {
    String asString(Object? value, String fallback) => switch (value) {
      final String v => v,
      final num v => v.toString(),
      _ => fallback,
    };

    int asInt(Object? value, int fallback) => switch (value) {
      final int v => v,
      final double v => v.round(),
      final String v => int.tryParse(v) ?? fallback,
      _ => fallback,
    };

    bool asBool(Object? value, bool fallback) => switch (value) {
      final bool v => v,
      final int v => v != 0,
      final String v => v.toLowerCase() == 'true' ? true : fallback,
      _ => fallback,
    };

    DateTime asDateTime(Object? value) => switch (value) {
      final DateTime v => v,
      final int v => DateTime.fromMillisecondsSinceEpoch(v),
      final String v =>
        DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0),
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };

    return VlcConnection(
      id: asString(json['id'], ''),
      name: asString(json['name'], 'Senza nome'),
      ipAddress: asString(json['ipAddress'], '127.0.0.1'),
      port: asInt(json['port'], 8080),
      lastUsed: asDateTime(json['lastUsed']),
      isFavorite: asBool(json['isFavorite'], false),
      myPlaylistIp: json['myPlaylistIp'] is String
          ? json['myPlaylistIp']
          : null,
      myPlaylistPort: json['myPlaylistPort'] == null
          ? null
          : asInt(json['myPlaylistPort'], 8080),
      myPlaylistSecretKey: json['myPlaylistSecretKey'] is String
          ? json['myPlaylistSecretKey']
          : null,
      vlcPassword: json['vlcPassword'] is String ? json['vlcPassword'] : null,
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
      'vlcPassword': vlcPassword,
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
    String? vlcPassword,
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
      vlcPassword: vlcPassword ?? this.vlcPassword,
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
