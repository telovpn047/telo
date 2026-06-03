import 'dart:convert';

class XrayConfigBuilder {
  /// VLESS config builder
  static Map<String, dynamic> buildVless({
    required String address,
    required int port,
    required String uuid,
    String network = 'tcp',
    String security = 'none',
    String? sni,
    String? wsPath,
    String? wsHost,
    String? fingerprint,
    String? publicKey,
    String? shortId,
    String? mode,
    int localPort = 10808,
  }) {
    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vless',
      'settings': {
        'vnext': [
          {
            'address': address,
            'port': port,
            'users': [
              {
                'id': uuid,
                'encryption': 'none',
                // Xray boş 'flow' string'ini reddedebilir; yalnızca Reality/XTLS
                // kullanılırken bu anahtarı ekle.
                if (security == 'reality') 'flow': 'xtls-rprx-vision',
              }
            ]
          }
        ]
      },
      'streamSettings': _buildStreamSettings(
        network: network,
        security: security,
        sni: sni,
        wsPath: wsPath,
        wsHost: wsHost,
        fingerprint: fingerprint,
        publicKey: publicKey,
        shortId: shortId,
        mode: mode,
      ),
    };
    return _buildFullConfig(outbound, localPort);
  }

  /// VMESS config builder
  static Map<String, dynamic> buildVmess({
    required String address,
    required int port,
    required String uuid,
    int alterId = 0,
    String network = 'tcp',
    String security = 'none',
    String? sni,
    String? wsPath,
    String? wsHost,
    String? mode,
    int localPort = 10808,
  }) {
    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'vmess',
      'settings': {
        'vnext': [
          {
            'address': address,
            'port': port,
            'users': [
              {
                'id': uuid,
                'alterId': alterId,
                'security': 'auto',
              }
            ]
          }
        ]
      },
      'streamSettings': _buildStreamSettings(
        network: network,
        security: security,
        sni: sni,
        wsPath: wsPath,
        wsHost: wsHost,
        mode: mode,
      ),
    };
    return _buildFullConfig(outbound, localPort);
  }

  /// Trojan config builder
  static Map<String, dynamic> buildTrojan({
    required String address,
    required int port,
    required String password,
    String? sni,
    String network = 'tcp',
    int localPort = 10808,
  }) {
    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'trojan',
      'settings': {
        'servers': [
          {
            'address': address,
            'port': port,
            'password': password,
          }
        ]
      },
      'streamSettings': _buildStreamSettings(
        network: network,
        security: 'tls',
        sni: sni ?? address,
      ),
    };
    return _buildFullConfig(outbound, localPort);
  }

  /// Shadowsocks config builder
  static Map<String, dynamic> buildShadowsocks({
    required String address,
    required int port,
    required String password,
    String method = 'aes-256-gcm',
    int localPort = 10808,
  }) {
    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': 'shadowsocks',
      'settings': {
        'servers': [
          {
            'address': address,
            'port': port,
            'password': password,
            'method': method,
          }
        ]
      },
      'streamSettings': {
        'network': 'tcp',
      },
    };
    return _buildFullConfig(outbound, localPort);
  }

  static Map<String, dynamic> _buildStreamSettings({
    required String network,
    required String security,
    String? sni,
    String? wsPath,
    String? wsHost,
    String? fingerprint,
    String? publicKey,
    String? shortId,
    String? mode,
  }) {
    // Xray 26.x renamed "splithttp" to "xhttp"; normalize so old subscriptions work.
    final effectiveNetwork = network == 'splithttp' ? 'xhttp' : network;

    final settings = <String, dynamic>{
      'network': effectiveNetwork,
      'security': security,
    };

    // TLS settings — allowInsecure removed in Xray 26.x
    if (security == 'tls') {
      settings['tlsSettings'] = {
        'serverName': sni ?? '',
        'fingerprint': fingerprint ?? 'chrome',
      };
    }

    // Reality settings
    if (security == 'reality') {
      settings['realitySettings'] = {
        'serverName': sni ?? '',
        'fingerprint': fingerprint ?? 'chrome',
        'publicKey': publicKey ?? '',
        'shortId': shortId ?? '',
        'spiderX': '/',
      };
    }

    // WebSocket settings — use standalone "host" field (Xray 26.x deprecated headers.Host)
    if (effectiveNetwork == 'ws') {
      settings['wsSettings'] = {
        'path': wsPath ?? '/',
        if (wsHost != null && wsHost.isNotEmpty) 'host': wsHost,
      };
    }

    // XHTTP settings — covers both "xhttp" and legacy "splithttp" URIs
    if (effectiveNetwork == 'xhttp') {
      settings['xhttpSettings'] = {
        'path': wsPath ?? '/',
        if (wsHost != null && wsHost.isNotEmpty) 'host': wsHost,
        'mode': mode ?? 'auto',
      };
    }

    // HTTP Upgrade settings
    if (effectiveNetwork == 'httpupgrade') {
      settings['httpupgradeSettings'] = {
        'path': wsPath ?? '/',
        if (wsHost != null && wsHost.isNotEmpty) 'host': wsHost,
      };
    }

    // gRPC settings
    if (effectiveNetwork == 'grpc') {
      settings['grpcSettings'] = {
        'serviceName': wsPath ?? '',
      };
    }

    // HTTP/2 settings
    if (effectiveNetwork == 'h2') {
      settings['httpSettings'] = {
        'path': wsPath ?? '/',
        'host': wsHost != null ? [wsHost] : [],
      };
    }

    return settings;
  }

  static Map<String, dynamic> _buildFullConfig(
      Map<String, dynamic> outbound, int localPort) {
    return {
      'log': {
        'loglevel': 'warning',
        'access': '',
        'error': '',
      },
      'dns': {
        'servers': [
          {
            'address': 'https+local://1.1.1.1/dns-query',
            'domains': ['geosite:geolocation-!cn'],
          },
          '8.8.8.8',
          '8.8.4.4',
          'localhost',
        ],
      },
      'inbounds': [
        {
          'tag': 'socks',
          'port': localPort,
          'listen': '127.0.0.1',
          'protocol': 'socks',
          'settings': {
            'auth': 'noauth',
            'udp': true,
            'ip': '127.0.0.1',
          },
        },
        {
          'tag': 'http',
          'port': localPort + 1,
          'listen': '127.0.0.1',
          'protocol': 'http',
          'settings': {
            'allowTransparent': false,
          },
        },
        {
          'tag': 'tun',
          'port': 10800,
          'listen': '127.0.0.1',
          'protocol': 'dokodemo-door',
          'settings': {
            'address': '1.1.1.1',
            'port': 53,
            'network': 'udp',
          },
        },
      ],
      'outbounds': [
        outbound,
        {
          'tag': 'direct',
          'protocol': 'freedom',
          'settings': {},
        },
        {
          'tag': 'block',
          'protocol': 'blackhole',
          'settings': {'response': {'type': 'http'}},
        },
      ],
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': [
          {
            'type': 'field',
            'outboundTag': 'block',
            'domain': ['geosite:category-ads-all'],
          },
          {
            'type': 'field',
            'outboundTag': 'direct',
            'ip': ['geoip:private', 'geoip:tm'],
          },
          {
            'type': 'field',
            'outboundTag': 'proxy',
            'network': 'tcp,udp',
          },
        ],
      },
    };
  }

  /// Parse URI and build config automatically
  static Map<String, dynamic>? fromUri(String uri) {
    try {
      if (uri.startsWith('vless://')) return _parseVless(uri);
      if (uri.startsWith('vmess://')) return _parseVmess(uri);
      if (uri.startsWith('trojan://')) return _parseTrojan(uri);
      if (uri.startsWith('ss://')) return _parseShadowsocks(uri);
    } catch (e) {
      return null;
    }
    return null;
  }

  static Map<String, dynamic> _parseVless(String uri) {
    final withoutScheme = uri.substring(8);
    final hashIndex = withoutScheme.indexOf('#');
    final main = hashIndex >= 0
        ? withoutScheme.substring(0, hashIndex)
        : withoutScheme;

    final atIndex = main.lastIndexOf('@');
    final uuid = main.substring(0, atIndex);

    final hostPart = main.substring(atIndex + 1);
    final queryIndex = hostPart.indexOf('?');
    final hostPort =
        queryIndex >= 0 ? hostPart.substring(0, queryIndex) : hostPart;
    final queryString =
        queryIndex >= 0 ? hostPart.substring(queryIndex + 1) : '';

    final lastColon = hostPort.lastIndexOf(':');
    final address = hostPort.substring(0, lastColon);
    final port = int.parse(hostPort.substring(lastColon + 1));

    final params = Uri.splitQueryString(queryString);
    final network = params['type'] ?? 'tcp';
    final security = params['security'] ?? 'none';
    final sni = params['sni'] ?? params['peer'];
    final wsPath = params['path'];
    final wsHost = params['host'];
    final fingerprint = params['fp'];
    final publicKey = params['pbk'];
    final shortId = params['sid'];
    final mode = params['mode'];

    return buildVless(
      address: address,
      port: port,
      uuid: uuid,
      network: network,
      security: security,
      sni: sni,
      wsPath: wsPath,
      wsHost: wsHost,
      fingerprint: fingerprint,
      publicKey: publicKey,
      shortId: shortId,
      mode: mode,
    );
  }

  static Map<String, dynamic> _parseVmess(String uri) {
    final b64 = uri.substring(8);
    final decoded = utf8.decode(base64Url.decode(base64Url.normalize(b64)));
    final json = jsonDecode(decoded) as Map<String, dynamic>;

    return buildVmess(
      address: json['add'] ?? '',
      port: int.tryParse(json['port'].toString()) ?? 443,
      uuid: json['id'] ?? '',
      alterId: int.tryParse(json['aid'].toString()) ?? 0,
      network: json['net'] ?? 'tcp',
      security: json['tls'] == 'tls' ? 'tls' : 'none',
      sni: json['sni'] ?? json['host'],
      wsPath: json['path'],
      wsHost: json['host'],
      mode: json['mode'] as String?,
    );
  }

  static Map<String, dynamic> _parseTrojan(String uri) {
    final parsed = Uri.parse(uri.replaceFirst('trojan://', 'https://'));
    return buildTrojan(
      address: parsed.host,
      port: parsed.port,
      password: parsed.userInfo,
      sni: parsed.queryParameters['sni'] ?? parsed.host,
      network: parsed.queryParameters['type'] ?? 'tcp',
    );
  }

  static Map<String, dynamic> _parseShadowsocks(String uri) {
    final withoutScheme = uri.substring(5);
    final hashIndex = withoutScheme.indexOf('#');
    final main = hashIndex >= 0
        ? withoutScheme.substring(0, hashIndex)
        : withoutScheme;

    final atIndex = main.lastIndexOf('@');
    String methodPassword;
    String hostPort;

    if (atIndex >= 0) {
      final encoded = main.substring(0, atIndex);
      hostPort = main.substring(atIndex + 1);
      try {
        methodPassword = utf8
            .decode(base64Url.decode(base64Url.normalize(encoded)));
      } catch (_) {
        methodPassword = encoded;
      }
    } else {
      try {
        final decoded = utf8
            .decode(base64Url.decode(base64Url.normalize(main)));
        final atIdx2 = decoded.lastIndexOf('@');
        methodPassword = decoded.substring(0, atIdx2);
        hostPort = decoded.substring(atIdx2 + 1);
      } catch (_) {
        return buildShadowsocks(
            address: 'unknown', port: 443, password: 'unknown');
      }
    }

    final colonIndex = methodPassword.indexOf(':');
    final method = methodPassword.substring(0, colonIndex);
    final password = methodPassword.substring(colonIndex + 1);

    final lastColon = hostPort.lastIndexOf(':');
    final address = hostPort.substring(0, lastColon);
    final port = int.parse(hostPort.substring(lastColon + 1));

    return buildShadowsocks(
      address: address,
      port: port,
      password: password,
      method: method,
    );
  }

  /// Apply DNS, fragment, and mux settings on top of an already-built config.
  static void applyAdvancedSettings(
    Map<String, dynamic> config, {
    String primaryDns = '8.8.8.8',
    String secondaryDns = '1.1.1.1',
    bool enableFragment = false,
    String fragmentLength = '100-200',
    String fragmentInterval = '10-20',
    bool enableMux = false,
    int muxConcurrency = 8,
  }) {
    config['dns'] = {
      'servers': [
        {
          'address': 'https+local://1.1.1.1/dns-query',
          'domains': ['geosite:geolocation-!cn'],
        },
        primaryDns,
        secondaryDns,
        'localhost',
      ],
    };

    final outbounds = config['outbounds'] as List<dynamic>;
    final proxyIdx = outbounds.indexWhere((o) => o['tag'] == 'proxy');
    if (proxyIdx < 0) return;
    final proxy = outbounds[proxyIdx] as Map<String, dynamic>;

    if (enableMux) {
      proxy['mux'] = {'enabled': true, 'concurrency': muxConcurrency};
    } else {
      proxy.remove('mux');
    }

    if (enableFragment) {
      final stream = proxy['streamSettings'] as Map<String, dynamic>?;
      if (stream != null) {
        stream['sockopt'] = {
          'fragment': {
            'packets': 'tlshello',
            'length': fragmentLength,
            'interval': fragmentInterval,
          },
        };
      }
    } else {
      final stream = proxy['streamSettings'] as Map<String, dynamic>?;
      (stream?['sockopt'] as Map?)?.remove('fragment');
    }
  }

  static String toJsonString(Map<String, dynamic> config) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(config);
  }
}
