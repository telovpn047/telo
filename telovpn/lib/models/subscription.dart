import 'dart:math' as math;

class SubscriptionInfo {
  final String url;
  final String name;
  final DateTime lastUpdated;
  final int autoUpdateHours;
  final int upload;
  final int download;
  final int total;
  final int? expireAt;

  const SubscriptionInfo({
    required this.url,
    required this.name,
    required this.lastUpdated,
    this.autoUpdateHours = 1,
    this.upload = 0,
    this.download = 0,
    this.total = 0,
    this.expireAt,
  });

  int get usedBytes => upload + download;
  bool get isUnlimited => total <= 0;
  double get usageRatio => total > 0 ? math.min(1.0, usedBytes / total) : 0.0;

  DateTime? get expireDate => (expireAt != null && expireAt! > 0)
      ? DateTime.fromMillisecondsSinceEpoch(expireAt! * 1000)
      : null;

  int? get daysLeft => expireDate?.difference(DateTime.now()).inDays;

  bool get hasInfo => !isUnlimited || expireDate != null;

  String get usageText {
    if (isUnlimited && usedBytes == 0) return '';
    return '${_fmtBytes(usedBytes)}/${isUnlimited ? "∞" : _fmtBytes(total)}';
  }

  static String _fmtBytes(int b) {
    if (b <= 0) return '0B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double v = b.toDouble();
    while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
    return i == 0 ? '${b}B' : '${v.toStringAsFixed(i >= 3 ? 2 : 1)}${units[i]}';
  }

  SubscriptionInfo copyWith({
    String? url,
    String? name,
    DateTime? lastUpdated,
    int? autoUpdateHours,
    int? upload,
    int? download,
    int? total,
    int? expireAt,
  }) =>
      SubscriptionInfo(
        url: url ?? this.url,
        name: name ?? this.name,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        autoUpdateHours: autoUpdateHours ?? this.autoUpdateHours,
        upload: upload ?? this.upload,
        download: download ?? this.download,
        total: total ?? this.total,
        expireAt: expireAt ?? this.expireAt,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
        'name': name,
        'lastUpdated': lastUpdated.millisecondsSinceEpoch,
        'autoUpdateHours': autoUpdateHours,
        'upload': upload,
        'download': download,
        'total': total,
        if (expireAt != null) 'expireAt': expireAt,
      };

  factory SubscriptionInfo.fromJson(Map<String, dynamic> j) => SubscriptionInfo(
        url: j['url'] as String? ?? '',
        name: j['name'] as String? ?? j['url'] as String? ?? '',
        lastUpdated: j['lastUpdated'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['lastUpdated'] as int)
            : DateTime(2000),
        autoUpdateHours: j['autoUpdateHours'] as int? ?? 1,
        upload: j['upload'] as int? ?? 0,
        download: j['download'] as int? ?? 0,
        total: j['total'] as int? ?? 0,
        expireAt: j['expireAt'] as int?,
      );

  factory SubscriptionInfo.fromUrl(String url) => SubscriptionInfo(
        url: url,
        name: _nameFromUrl(url),
        lastUpdated: DateTime(2000),
      );

  static String _nameFromUrl(String url) {
    try { return Uri.parse(url).host; } catch (_) { return url; }
  }
}
