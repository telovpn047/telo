class VpnServer {
  final String id;
  final String name;
  final String country;
  final String countryCode;
  final String flagEmoji;
  final String address;
  final int port;
  final String protocol;
  final String? uuid;
  final String? path;
  final String? configUri;
  final bool isFavorite;
  final int ping;
  final double load;

  VpnServer({
    required this.id,
    required this.name,
    required this.country,
    required this.countryCode,
    required this.flagEmoji,
    required this.address,
    required this.port,
    required this.protocol,
    this.uuid,
    this.path,
    this.configUri,
    this.isFavorite = false,
    this.ping = 0,
    this.load = 0.0,
  });

  VpnServer copyWith({
    String? id, String? name, String? country, String? countryCode,
    String? flagEmoji, String? address, int? port, String? protocol,
    String? uuid, String? path, String? configUri, bool? isFavorite,
    int? ping, double? load,
  }) {
    return VpnServer(
      id: id ?? this.id, name: name ?? this.name, country: country ?? this.country,
      countryCode: countryCode ?? this.countryCode, flagEmoji: flagEmoji ?? this.flagEmoji,
      address: address ?? this.address, port: port ?? this.port, protocol: protocol ?? this.protocol,
      uuid: uuid ?? this.uuid, path: path ?? this.path, configUri: configUri ?? this.configUri,
      isFavorite: isFavorite ?? this.isFavorite, ping: ping ?? this.ping, load: load ?? this.load,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'country': country, 'countryCode': countryCode,
    'flagEmoji': flagEmoji, 'address': address, 'port': port, 'protocol': protocol,
    'uuid': uuid, 'path': path, 'configUri': configUri, 'isFavorite': isFavorite,
    'ping': ping, 'load': load,
  };

  factory VpnServer.fromJson(Map<String, dynamic> json) => VpnServer(
    id: json['id'], name: json['name'], country: json['country'],
    countryCode: json['countryCode'], flagEmoji: json['flagEmoji'],
    address: json['address'], port: json['port'], protocol: json['protocol'],
    uuid: json['uuid'], path: json['path'], configUri: json['configUri'],
    isFavorite: json['isFavorite'] ?? false,
    ping: json['ping'] ?? 0, load: (json['load'] ?? 0.0).toDouble(),
  );

  String get pingLabel {
    if (ping <= 0) return '—';
    return '$ping ms';
  }

  String get pingQuality {
    if (ping <= 0) return 'unknown';
    if (ping < 80) return 'excellent';
    if (ping < 150) return 'good';
    if (ping < 300) return 'fair';
    return 'poor';
  }
}

enum VpnStatus { disconnected, connecting, connected, disconnecting, error }

class VpnStats {
  final int downloadBytes;
  final int uploadBytes;
  final double downloadSpeed;
  final double uploadSpeed;
  final Duration duration;

  const VpnStats({
    this.downloadBytes = 0, this.uploadBytes = 0,
    this.downloadSpeed = 0, this.uploadSpeed = 0,
    this.duration = Duration.zero,
  });

  String get formattedDownload => _formatBytes(downloadBytes);
  String get formattedUpload => _formatBytes(uploadBytes);
  String get formattedDownloadSpeed => '${_formatSpeed(downloadSpeed)}/s';
  String get formattedUploadSpeed => '${_formatSpeed(uploadSpeed)}/s';

  String get formattedDuration {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
  }

  static String _formatSpeed(double b) {
    if (b < 1024) return '${b.toStringAsFixed(0)}B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)}KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(2)}MB';
  }
}
