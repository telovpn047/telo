import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vpn_native_service.dart';
import '../theme/app_theme.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<String> _logs = [];
  Timer? _timer;
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchLogs());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    final logs = await VpnNativeService.getLogs();
    if (!mounted) return;
    setState(() => _logs = logs);
    if (_autoScroll && _scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _clearLogs() async {
    await VpnNativeService.clearLogs();
    setState(() => _logs = []);
  }

  void _copyAll() {
    Clipboard.setData(ClipboardData(text: _logs.join('\n')));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loglar kopyalandı'), duration: Duration(seconds: 2)),
    );
  }

  Color _lineColor(String line, bool isDark) {
    if (line.contains('[Xray]')) return isDark ? const Color(0xFF82AAFF) : const Color(0xFF1565C0);
    if (line.contains('[tun2socks]')) return isDark ? const Color(0xFF89DDFF) : const Color(0xFF00838F);
    if (line.toLowerCase().contains('hata') || line.toLowerCase().contains('error') || line.toLowerCase().contains('fail')) {
      return isDark ? const Color(0xFFFF5370) : const Color(0xFFD32F2F);
    }
    if (line.toLowerCase().contains('başarı') || line.toLowerCase().contains('hayatta') || line.toLowerCase().contains('hazır')) {
      return isDark ? const Color(0xFFC3E88D) : const Color(0xFF388E3C);
    }
    return isDark ? const Color(0xFFCDD3DE) : const Color(0xFF37474F);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('VPN Logları'),
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_center),
            tooltip: 'Otomatik kaydır',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Tümünü kopyala',
            onPressed: _logs.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Temizle',
            onPressed: _logs.isEmpty ? null : _clearLogs,
          ),
        ],
      ),
      body: _logs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('Log yok', style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text('VPN başlatıldığında loglar burada görünür',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final line = _logs[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: _lineColor(line, isDark),
                      height: 1.4,
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        child: Row(
          children: [
            Icon(Icons.circle, size: 8, color: Colors.green.shade400),
            const SizedBox(width: 6),
            Text('${_logs.length} satır', style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text('Her 2 saniyede güncellenir', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
