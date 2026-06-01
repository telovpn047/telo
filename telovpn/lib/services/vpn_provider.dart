import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  VpnStatus get status => _status;
  VpnServer? get selectedServer => _selectedServer;
  VpnStats get stats => _stats;
  Duration get connectionDuration => _connectionDuration;
  List<VpnServer> get servers => _servers;
  List<VpnServer> get favoriteServers =>
      _servers.where((s) => s.isFavorite).toList();
  String? get errorMessage => _errorMessage;
  bool get isPinging => _isPinging;
  Map<String, int> get pingResults => Map.unmodifiable(_pingResults);
  String? get pingError => _pingError;

  // Servers sorted by ping (best first)
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

  /// Ping all servers and update results
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
          // Update server ping in list
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

  /// Auto-select server with best (lowest) ping, optionally filtered by protocol
  Future<VpnServer?> autoSelectBestServer({bool connectAfter = false, String protocolFilter = 'AUTO'}) async {
    if (_isPinging) return null;

    await pingAllServers();

    VpnServer? best;
    int bestPing = 999999;

    for (final server in _servers) {
      if (protocolFilter != 'AUTO' && server.protocol.toUpperCase() != protocolFilter) continue;
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
    _initDemoServers();
    _loadSavedServers();
  }

  void _initDemoServers() {
    _servers.addAll([
      VpnServer(id: 'demo_us1', name: 'Nyu-York', country: 'Amerika', countryCode: 'US', flagEmoji: '🇺🇸', address: 'us1.telovpn.net', port: 443, protocol: 'VLESS', ping: 120, load: 0.35, isFavorite: true, configUri: ''),
      VpnServer(id: 'demo_de1', name: 'Frankfurt', country: 'Germaniýa', countryCode: 'DE', flagEmoji: '🇩🇪', address: 'de1.telovpn.net', port: 443, protocol: 'VMESS', ping: 65, load: 0.45, configUri: ''),
      VpnServer(id: 'demo_gb1', name: 'London', country: 'Beýik Britaniýa', countryCode: 'GB', flagEmoji: '🇬🇧', address: 'uk1.telovpn.net', port: 443, protocol: 'VLESS', ping: 80, load: 0.60, configUri: ''),
      VpnServer(id: 'demo_jp1', name: 'Tokio', country: 'Ýaponiýa', countryCode: 'JP', flagEmoji: '🇯🇵', address: 'jp1.telovpn.net', port: 443, protocol: 'TROJAN', ping: 180, load: 0.25, configUri: ''),
      VpnServer(id: 'demo_sg1', name: 'Singapur', country: 'Singapur', countryCode: 'SG', flagEmoji: '🇸🇬', address: 'sg1.telovpn.net', port: 443, protocol: 'VMESS', ping: 155, load: 0.50, configUri: ''),
      VpnServer(id: 'demo_nl1', name: 'Amsterdam', country: 'Niderlandlar', countryCode: 'NL', flagEmoji: '🇳🇱', address: 'nl1.telovpn.net', port: 443, protocol: 'SHADOWSOCKS', ping: 72, load: 0.30, isFavorite: true, configUri: ''),
      VpnServer(id: 'demo_ae1', name: 'Dubay', country: 'BAE', countryCode: 'AE', flagEmoji: '🇦🇪', address: 'ae1.telovpn.net', port: 443, protocol: 'VLESS', ping: 95, load: 0.40, configUri: ''),
      VpnServer(id: 'demo_fr1', name: 'Pariz', country: 'Fransiýa', countryCode: 'FR', flagEmoji: '🇫🇷', address: 'fr1.telovpn.net', port: 443, protocol: 'VMESS', ping: 88, load: 0.55, configUri: ''),
    ]);
    _selectedServer = _servers.first;
  }

  Future<void> _loadSavedServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getStringList('custom_servers') ?? [];
      for (final json in savedJson) {
        final server = VpnServer.fromJson(jsonDecode(json));
        if (!_servers.any((s) => s.id == server.id)) {
          _servers.add(server);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved servers: $e');
    }
  }

  Future<void> _saveCustomServers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customServers = _servers.where((s) => s.id.startsWith('custom_')).toList();
      await prefs.setStringList('custom_servers', customServers.map((s) => jsonEncode(s.toJson())).toList());
    } catch (e) {
      debugPrint('Error saving: $e');
    }
  }

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

      final configJson = _buildConfigForServer(_selectedServer!);
      if (configJson == null) {
        _status = VpnStatus.error;
        _errorMessage = 'Serwer sazlamasy nädogry';
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastConfig', configJson);
      await prefs.setString('lastServerName', _selectedServer!.name);

      final started = await VpnNativeService.startVpn(configJson: configJson, serverName: _selectedServer!.name);

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

  String? _buildConfigForServer(VpnServer server) {
    if (server.configUri != null && server.configUri!.isNotEmpty) {
      final config = XrayConfigBuilder.fromUri(server.configUri!);
      if (config != null) return XrayConfigBuilder.toJsonString(config);
    }
    Map<String, dynamic> config;
    switch (server.protocol.toUpperCase()) {
      case 'VLESS':
        config = XrayConfigBuilder.buildVless(address: server.address, port: server.port, uuid: server.uuid ?? '00000000-0000-0000-0000-000000000000', security: 'tls', sni: server.address);
        break;
      case 'VMESS':
        config = XrayConfigBuilder.buildVmess(address: server.address, port: server.port, uuid: server.uuid ?? '00000000-0000-0000-0000-000000000000', network: 'ws', security: 'tls', sni: server.address, wsPath: server.path ?? '/');
        break;
      case 'TROJAN':
        config = XrayConfigBuilder.buildTrojan(address: server.address, port: server.port, password: server.uuid ?? 'password', sni: server.address);
        break;
      case 'SHADOWSOCKS':
        config = XrayConfigBuilder.buildShadowsocks(address: server.address, port: server.port, password: server.uuid ?? 'password');
        break;
      default:
        config = XrayConfigBuilder.buildVless(address: server.address, port: server.port, uuid: server.uuid ?? '00000000-0000-0000-0000-000000000000');
    }
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

  bool _addSingleConfig(String config) {
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
      final newServer = VpnServer(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: name, country: countryInfo['country']!, countryCode: countryInfo['code']!,
        flagEmoji: countryInfo['flag']!, address: address, port: port,
        protocol: protocol == 'SS' ? 'SHADOWSOCKS' : protocol, configUri: config,
      );
      _servers.add(newServer);
      return true;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> _detectCountry(String address) {
    final l = address.toLowerCase();
    if (l.contains('.us') || l.contains('us.')) return {'country': 'Amerika', 'code': 'US', 'flag': '🇺🇸'};
    if (l.contains('.de') || l.contains('de.')) return {'country': 'Germaniýa', 'code': 'DE', 'flag': '🇩🇪'};
    if (l.contains('.nl') || l.contains('nl.')) return {'country': 'Niderlandlar', 'code': 'NL', 'flag': '🇳🇱'};
    if (l.contains('.uk') || l.contains('uk.')) return {'country': 'Beýik Britaniýa', 'code': 'GB', 'flag': '🇬🇧'};
    if (l.contains('.jp') || l.contains('jp.')) return {'country': 'Ýaponiýa', 'code': 'JP', 'flag': '🇯🇵'};
    if (l.contains('.sg') || l.contains('sg.')) return {'country': 'Singapur', 'code': 'SG', 'flag': '🇸🇬'};
    if (l.contains('.fr') || l.contains('fr.')) return {'country': 'Fransiýa', 'code': 'FR', 'flag': '🇫🇷'};
    if (l.contains('.ae') || l.contains('ae.')) return {'country': 'BAE', 'code': 'AE', 'flag': '🇦🇪'};
    if (l.contains('.tr') || l.contains('tr.')) return {'country': 'Türkiýe', 'code': 'TR', 'flag': '🇹🇷'};
    if (l.contains('.ru') || l.contains('ru.')) return {'country': 'Russiýa', 'code': 'RU', 'flag': '🇷🇺'};
    return {'country': 'Nabelli', 'code': 'XX', 'flag': '🌐'};
  }

  void deleteServer(String serverId) {
    _servers.removeWhere((s) => s.id == serverId);
    if (_selectedServer?.id == serverId) _selectedServer = _servers.isNotEmpty ? _servers.first : null;
    _saveCustomServers();
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
          _baseRx = rx;
          _baseTx = tx;
          _lastRx = rx;
          _lastTx = tx;
          return;
        }

        final dlSpeed = (rx - _lastRx).clamp(0, 100 * 1024 * 1024).toDouble();
        final ulSpeed = (tx - _lastTx).clamp(0, 100 * 1024 * 1024).toDouble();
        _lastRx = rx;
        _lastTx = tx;

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
