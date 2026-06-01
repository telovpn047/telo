import 'package:flutter/services.dart';

class VpnNativeService {
  static const _channel = MethodChannel('com.telovpn.app/vpn');

  /// Request VPN permission from Android
  static Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestVpnPermission');
      return result ?? false;
    } on PlatformException catch (e) {
      print('VPN permission error: ${e.message}');
      return false;
    }
  }

  /// Start VPN with xray config JSON
  static Future<bool> startVpn({
    required String configJson,
    required String serverName,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('startVpn', {
        'config': configJson,
        'serverName': serverName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Start VPN error: ${e.message}');
      return false;
    }
  }

  /// Stop VPN
  static Future<bool> stopVpn() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopVpn');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Stop VPN error: ${e.message}');
      return false;
    }
  }

  /// Get current VPN running status
  static Future<bool> getStatus() async {
    try {
      final result = await _channel.invokeMethod<bool>('getVpnStatus');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Get real-time traffic stats (rx/tx bytes) from the VPN interface
  static Future<Map<String, int>> getTrafficStats() async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTrafficStats');
      if (result == null) return {'rx': 0, 'tx': 0};
      return {
        'rx': (result['rx'] as num?)?.toInt() ?? 0,
        'tx': (result['tx'] as num?)?.toInt() ?? 0,
      };
    } on PlatformException {
      return {'rx': 0, 'tx': 0};
    }
  }
}
