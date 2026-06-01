import 'dart:async';
import 'dart:io';

class PingService {
  // TCP connect ping - fastest & most reliable method
  static Future<int> ping(
    String host, {
    int port = 443,
    int timeoutMs = 3000,
  }) async {
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      sw.stop();
      socket.destroy();
      return sw.elapsedMilliseconds;
    } catch (_) {
      return -1;
    }
  }

  // Ping all servers concurrently
  static Future<Map<String, int>> pingAll(
    List<Map<String, dynamic>> servers, {
    void Function(String id, int ms)? onResult,
    int timeoutMs = 4000,
  }) async {
    final results = <String, int>{};
    await Future.wait(
      servers.map((s) async {
        final String id = s['id'];
        final String host = s['host'];
        final int port = s['port'];
        final int ms = await ping(host, port: port, timeoutMs: timeoutMs);
        results[id] = ms;
        onResult?.call(id, ms);
      }),
    );
    return results;
  }
}
