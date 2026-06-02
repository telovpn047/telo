import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_server.dart';
import 'vpn_native_service.dart';
import 'xray_config_builder.dart';
import 'ping_service.dart';

class VpnProvider extends ChangeNotifier {
  VpnStatus _status = VpnStatus.disconnected;
  VpnServer? _selectedServer;
  VpnStats _stats = const VpnStats();
  Timer? _statsTimer;
  Timer? _durationTimer;
  Duration _connectionDuration = Duration.zero;
  final List<VpnServer> _servers = [];
  String? _errorMessage;

  // Ping / Auto-select state
  bool _isPinging = false;
  final Map<String, int> _pingResults = {};
  String? _pingError;

  // Subscription state
  final List<String> _subscriptionUrls = [];
  bool _isRefreshingSubscriptions = false;
  String? _subscriptionError;

  VpnStatus get status => _status;
  VpnServer? get selectedServer => _selectedServer;
  VpnStats get stats => _stats;
  Duration get connectionDuration => _connectionDuration;
  List<VpnServer> get servers => _servers;
  List<VpnServer> get favoriteServers => _servers.where((s) => s.isFavorite).toList();
  String? get errorMessage => _errorMessage;
  bool get isPinging => _isPinging;
  Map<String, int> get pingResults => Map.unmodifiable(_pingResults);
  String? get pingError => _pingError;
  List<String> get subscriptionUrls => List.unmodifiable(_subscriptionUrls);
  bool get isRefreshingSubscriptions => _isRefreshingSubscriptions;
  String? get subscriptionError => _subscriptionError;

  List<VpnServer> get serversSortedByPing {
    final sorted = List<VpnServer>.from(_servers);
    sorted.sort((a, b) {
      final pa = _pingResults[a.id] ?? a.ping;
      final pb = _pingResults[b.id] ?? b.ping;
      if (pa <= 0 && pb <= 0) return 0;
      if (pa <= 0) return 1;
      if (pb <= 0) return -1;
      return pa.compareTo(pb);
    });
    return sorted;
  }

  bool get isConnected => _status == VpnStatus.connected;
  bool get isConnecting => _status == VpnStatus.connecting;
  bool get isDisconnected => _status == VpnStatus.disconnected;

  Future<void> pingAllServers() async {
    if (_isPinging) return;
    _isPinging = true;
    _pingError = null;
    notifyListeners();

    try {
      final serverList = _servers
          .map((s) => {'id': s.id, 'host': s.address, 'port': s.port})
          .toList();

      await PingService.pingAll(
        serverList,
        onResult: (id, ms) {
          _pingResults[id] = ms;
          final idx = _servers.indexWhere((s) => s.id == id);
          if (idx != -1) {
            _servers[idx] = _servers[idx].copyWith(ping: ms > 0 ? ms : 9999);
          }
          notifyListeners();
        },
      );
    } catch (e) {
      _pingError = 'Ping ölçüm hatasy: $e';
    }

    _isPinging = false;
    notifyListeners();
  }

  Future<VpnServer?> autoSelectBestServer({
    bool connectAfter = false,
    String protocolFilter = 'AUTO',
  }) async {
    if (_isPinging) return null;

    await pingAllServers();

    VpnServer? best;
    int bestPing = 999999;

    for (final server in _servers) {
      if (protocolFilter != 'AUTO' &&
          server.protocol.toUpperCase() != protocolFilter) continue;
      final p = _pingResults[server.id] ?? server.ping;
      if (p > 0 && p < bestPing) {
        bestPing = p;
        best = server;
      }
    }

    if (best != null) {
      selectServer(best);
      if (connectAfter && isDisconnected) {
        await toggleConnection();
      }
    }

    return best;
  }

  VpnProvider() {
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load custom servers
      final savedCustom = prefs.getStringList('custom_servers') ?? [];
      for (final json in savedCustom) {
        final server = VpnServer.fromJson(jsonDecode(json));
        if (!_servers.any((s) => s.id == server.id)) {
          _servers.add(server);
        }
      }

      // Load subscription URLs
      final urls = prefs.getStringList('subscription_urls') ?? [];
      _subscriptionUrls.addAll(urls);

      // Load subscription servers
      final savedSub = prefs.getStringList('subscription_servers') ?? [];
      for (final json in savedSub) {
        final server = VpnServer.fromJson(jsonDecode(json));
        if (!_servers.any((s) => s.id == server.id)) {
          _servers.add(server);
        }
      }

      if (_servers.isNotEmpty) _selectedServer = _servers.first;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved data: $e');
    }
  }

  Future<void> _saveCustomServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = _servers.where((s) => s.isCustom).toList();
      await prefs.setStringList(
          'custom_servers', custom.map((s) => jsonEncode(s.toJson())).toList());
    } catch (e) {
      debugPrint('Error saving custom servers: $e');
    }
  }

  Future<void> _saveSubscriptionServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sub = _servers.where((s) => s.isFromSubscription).toList();
      await prefs.setStringList('subscription_servers',
          sub.map((s) => jsonEncode(s.toJson())).toList());
      await prefs.setStringList('subscription_urls', _subscriptionUrls);
    } catch (e) {
      debugPrint('Error saving subscription data: $e');
    }
  }

  // ─── Subscription management ─────────────────────────────────────────────

  Future<String?> addSubscriptionFromUrl(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) return 'URL boş';
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'URL http:// veya https:// ile başlamalı';
    }
    if (_subscriptionUrls.contains(url)) return 'Bu abuna zaten mevcut';

    final result = await _fetchAndParseSubscription(url);
    if (result != null) return result;

    _subscriptionUrls.add(url);
    await _saveSubscriptionServers();
    notifyListeners();
    return null;
  }

  Future<void> removeSubscription(String url) async {
    _subscriptionUrls.remove(url);
    _servers.removeWhere((s) => s.subscriptionUrl == url);
    if (_selectedServer?.subscriptionUrl == url) {
      _selectedServer = _servers.isNotEmpty ? _servers.first : null;
    }
    await _saveSubscriptionServers();
    notifyListeners();
  }

  Future<String?> refreshSubscription(String url) async {
    _servers.removeWhere((s) => s.subscriptionUrl == url);
    final result = await _fetchAndParseSubscription(url);
    await _saveSubscriptionServers();
    notifyListeners();
    return result;
  }

  Future<void> refreshAllSubscriptions() async {
    if (_isRefreshingSubscriptions) return;
    _isRefreshingSubscriptions = true;
    _subscriptionError = null;
    notifyListeners();

    for (final url in List<String>.from(_subscriptionUrls)) {
      await refreshSubscription(url);
    }

    _isRefreshingSubscriptions = false;
    notifyListeners();
  }

  Future<String?> _fetchAndParseSubscription(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        return 'HTTP ${response.statusCode} hatasy';
      }

      String body = response.body.trim();
      // Try base64 decode first (standard subscription format)
      try {
        body = utf8.decode(base64.decode(base64.normalize(body)));
      } catch (_) {
        // Not base64, use raw text
      }

      final lines = body.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      int added = 0;
      for (final line in lines) {
        if (_addSingleConfig(line, subscriptionUrl: url)) added++;
      }

      if (added == 0) return 'Geçerli sunucu bulunamadı';
      return null;
    } on TimeoutException {
      return 'Bağlantı zaman aşımı (15s)';
    } catch (e) {
      return 'Hata: $e';
    }
  }

  // ─── Connection ──────────────────────────────────────────────────────────

  Future<void> toggleConnection() async {
    if (_status == VpnStatus.disconnected || _status == VpnStatus.error) {
      await _connect();
    } else if (_status == VpnStatus.connected) {
      await _disconnect();
    }
  }

  Future<void> _connect() async {
    if (_selectedServer == null) return;
    _status = VpnStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final hasPermission = await VpnNativeService.requestPermission();
      if (!hasPermission) {
        _status = VpnStatus.error;
        _errorMessage = 'VPN rugsady berilmedi';
        notifyListeners();
        return;
      }

      final configJson = await _buildConfigForServer(_selectedServer!);
      if (configJson == null) {
        _status = VpnStatus.error;
        _errorMessage = 'Serwer sazlamasy nädogry';
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastConfig', configJson);
      await prefs.setString('lastServerName', _selectedServer!.name);

      final started = await VpnNativeService.startVpn(
          configJson: configJson, serverName: _selectedServer!.name);

      if (started) {
        _status = VpnStatus.connected;
        _connectionDuration = Duration.zero;
        _startStatsTimer();
        _startDurationTimer();
      } else {
        _status = VpnStatus.error;
        _errorMessage = 'Birikme başartmady';
      }
    } catch (e) {
      _status = VpnStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<String?> _buildConfigForServer(VpnServer server) async {
    final prefs = await SharedPreferences.getInstance();
    final primaryDns = prefs.getString('primaryDns') ?? '8.8.8.8';
    final secondaryDns = prefs.getString('secondaryDns') ?? '1.1.1.1';
    final enableFragment = prefs.getBool('enableFragment') ?? false;
    final fragmentLength = prefs.getString('fragmentLength') ?? '100-200';
    final fragmentInterval = prefs.getString('fragmentInterval') ?? '10-20';
    final enableMux = prefs.getBool('enableMux') ?? false;
    final muxConcurrency = prefs.getInt('muxConcurrency') ?? 8;

    Map<String, dynamic>? config;

    if (server.configUri != null && server.configUri!.isNotEmpty) {
      config = XrayConfigBuilder.fromUri(server.configUri!);
    }

    if (config == null) {
      switch (server.protocol.toUpperCase()) {
        case 'VLESS':
          config = XrayConfigBuilder.buildVless(
              address: server.address, port: server.port,
              uuid: server.uuid ?? '00000000-0000-0000-0000-000000000000',
              security: 'tls', sni: server.address);
          break;
        case 'VMESS':
          config = XrayConfigBuilder.buildVmess(
              address: server.address, port: server.port,
              uuid: server.uuid ?? '00000000-0000-0000-0000-000000000000',
              network: 'ws', security: 'tls', sni: server.address,
              wsPath: server.path ?? '/');
          break;
        case 'TROJAN':
          config = XrayConfigBuilder.buildTrojan(
              address: server.address, port: server.port,
              password: server.uuid ?? 'password', sni: server.address);
          break;
        case 'SHADOWSOCKS':
          config = XrayConfigBuilder.buildShadowsocks(
              address: server.address, port: server.port,
              password: server.uuid ?? 'password');
          break;
        default:
          config = XrayConfigBuilder.buildVless(
              address: server.address, port: server.port,
              uuid: server.uuid ?? '00000000-0000-0000-0000-000000000000');
      }
    }

    if (config == null) return null;

    XrayConfigBuilder.applyAdvancedSettings(
      config,
      primaryDns: primaryDns,
      secondaryDns: secondaryDns,
      enableFragment: enableFragment,
      fragmentLength: fragmentLength,
      fragmentInterval: fragmentInterval,
      enableMux: enableMux,
      muxConcurrency: muxConcurrency,
    );

    return XrayConfigBuilder.toJsonString(config);
  }

  Future<void> _disconnect() async {
    _status = VpnStatus.disconnecting;
    notifyListeners();
    _stopTimers();
    await VpnNativeService.stopVpn();
    _status = VpnStatus.disconnected;
    _stats = const VpnStats();
    _connectionDuration = Duration.zero;
    notifyListeners();
  }

  void selectServer(VpnServer server) async {
    if (_status == VpnStatus.connected) await _disconnect();
    _selectedServer = server;
    notifyListeners();
  }

  void toggleFavorite(String serverId) {
    final idx = _servers.indexWhere((s) => s.id == serverId);
    if (idx != -1) {
      _servers[idx] = _servers[idx].copyWith(isFavorite: !_servers[idx].isFavorite);
      if (_servers[idx].isCustom) _saveCustomServers();
      if (_servers[idx].isFromSubscription) _saveSubscriptionServers();
      notifyListeners();
    }
  }

  bool addServerFromConfig(String config) {
    try {
      final lines = config.trim().split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      int added = 0;
      for (final line in lines) {
        if (_addSingleConfig(line)) added++;
      }
      if (added > 0) {
        _saveCustomServers();
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error adding server: $e');
    }
    return false;
  }

  bool _addSingleConfig(String config, {String? subscriptionUrl}) {
    try {
      final protocol = config.split('://').first.toUpperCase();
      if (!['VLESS', 'VMESS', 'TROJAN', 'SS'].contains(protocol)) return false;
      final xrayConfig = XrayConfigBuilder.fromUri(config);
      if (xrayConfig == null) return false;

      String name = 'Serwer ${_servers.length + 1}';
      final hashIdx = config.lastIndexOf('#');
      if (hashIdx >= 0) name = Uri.decodeComponent(config.substring(hashIdx + 1));

      String address = 'unknown';
      int port = 443;
      try {
        final uri = Uri.parse(config.replaceFirst(RegExp(r'^(vless|vmess|trojan|ss)://'), 'https://'));
        address = uri.host;
        port = uri.port > 0 ? uri.port : 443;
      } catch (_) {}

      final countryInfo = _detectCountry(address);
      final prefix = subscriptionUrl != null ? 'sub_' : 'custom_';
      final newServer = VpnServer(
        id: '${prefix}${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        country: countryInfo['country']!,
        countryCode: countryInfo['code']!,
        flagEmoji: countryInfo['flag']!,
        address: address,
        port: port,
        protocol: protocol == 'SS' ? 'SHADOWSOCKS' : protocol,
        configUri: config,
        subscriptionUrl: subscriptionUrl,
      );
      _servers.add(newServer);
      if (_selectedServer == null) _selectedServer = newServer;
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> _detectCountry(String address) {
    final l = address.toLowerCase();
    if (l.contains('.us') || l.contains('us.') || l.contains('-us-') || l.contains('usa')) return {'country': 'Amerika', 'code': 'US', 'flag': '🇺🇸'};
    if (l.contains('.de') || l.contains('de.') || l.contains('-de-') || l.contains('germany')) return {'country': 'Germaniýa', 'code': 'DE', 'flag': '🇩🇪'};
    if (l.contains('.nl') || l.contains('nl.') || l.contains('-nl-')) return {'country': 'Niderlandlar', 'code': 'NL', 'flag': '🇳🇱'};
    if (l.contains('.uk') || l.contains('uk.') || l.contains('-uk-') || l.contains('london')) return {'country': 'Beýik Britaniýa', 'code': 'GB', 'flag': '🇬🇧'};
    if (l.contains('.jp') || l.contains('jp.') || l.contains('-jp-') || l.contains('japan') || l.contains('tokyo')) return {'country': 'Ýaponiýa', 'code': 'JP', 'flag': '🇯🇵'};
    if (l.contains('.sg') || l.contains('sg.') || l.contains('-sg-') || l.contains('singapore')) return {'country': 'Singapur', 'code': 'SG', 'flag': '🇸🇬'};
    if (l.contains('.fr') || l.contains('fr.') || l.contains('-fr-') || l.contains('paris')) return {'country': 'Fransiýa', 'code': 'FR', 'flag': '🇫🇷'};
    if (l.contains('.ae') || l.contains('ae.') || l.contains('-ae-') || l.contains('dubai')) return {'country': 'BAE', 'code': 'AE', 'flag': '🇦🇪'};
    if (l.contains('.tr') || l.contains('tr.') || l.contains('-tr-') || l.contains('turkey')) return {'country': 'Türkiýe', 'code': 'TR', 'flag': '🇹🇷'};
    if (l.contains('.ru') || l.contains('ru.') || l.contains('-ru-') || l.contains('russia')) return {'country': 'Russiýa', 'code': 'RU', 'flag': '🇷🇺'};
    if (l.contains('.ir') || l.contains('ir.') || l.contains('-ir-') || l.contains('iran')) return {'country': 'Eýran', 'code': 'IR', 'flag': '🇮🇷'};
    if (l.contains('.fi') || l.contains('fi.') || l.contains('-fi-')) return {'country': 'Finlandiýa', 'code': 'FI', 'flag': '🇫🇮'};
    if (l.contains('.ca') || l.contains('ca.') || l.contains('-ca-') || l.contains('canada')) return {'country': 'Kanada', 'code': 'CA', 'flag': '🇨🇦'};
    if (l.contains('.au') || l.contains('au.') || l.contains('-au-') || l.contains('australia')) return {'country': 'Awstraliýa', 'code': 'AU', 'flag': '🇦🇺'};
    return {'country': 'Näbelli', 'code': 'XX', 'flag': '🌐'};
  }

  void deleteServer(String serverId) {
    final server = _servers.firstWhere((s) => s.id == serverId, orElse: () => _servers.first);
    _servers.removeWhere((s) => s.id == serverId);
    if (_selectedServer?.id == serverId) {
      _selectedServer = _servers.isNotEmpty ? _servers.first : null;
    }
    if (server.isCustom) _saveCustomServers();
    if (server.isFromSubscription) _saveSubscriptionServers();
    notifyListeners();
  }

  void _startStatsTimer() {
    int _baseRx = -1, _baseTx = -1;
    int _lastRx = 0, _lastTx = 0;

    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      try {
        final raw = await VpnNativeService.getTrafficStats();
        final rx = raw['rx']!;
        final tx = raw['tx']!;

        if (_baseRx < 0) {
          _baseRx = rx; _baseTx = tx;
          _lastRx = rx; _lastTx = tx;
          return;
        }

        final dlSpeed = (rx - _lastRx).clamp(0, 100 * 1024 * 1024).toDouble();
        final ulSpeed = (tx - _lastTx).clamp(0, 100 * 1024 * 1024).toDouble();
        _lastRx = rx; _lastTx = tx;

        _stats = VpnStats(
          downloadBytes: (rx - _baseRx).clamp(0, double.maxFinite.toInt()),
          uploadBytes: (tx - _baseTx).clamp(0, double.maxFinite.toInt()),
          downloadSpeed: dlSpeed,
          uploadSpeed: ulSpeed,
          duration: _connectionDuration,
        );
        notifyListeners();
      } catch (_) {}
    });
  }

  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _connectionDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopTimers() {
    _statsTimer?.cancel();
    _durationTimer?.cancel();
    _statsTimer = null;
    _durationTimer = null;
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}
