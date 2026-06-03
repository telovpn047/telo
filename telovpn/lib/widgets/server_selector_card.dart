import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_server.dart';
import '../services/vpn_provider.dart';
import '../theme/app_theme.dart';
import '../screens/servers_screen.dart';

Widget _buildServerAvatar(String serverName, {double size = 44}) {
  final runes = serverName.runes.toList();
  int skip = 0;
  while (skip < runes.length && runes[skip] >= 0x1F1E6 && runes[skip] <= 0x1F1FF) skip++;
  final clean = String.fromCharCodes(runes.skip(skip)).trim();
  final letter = clean.isNotEmpty ? clean[0].toUpperCase() : 'S';
  final gradients = [
    [const Color(0xFF0381FE), const Color(0xFF4DAAFF)],
    [const Color(0xFF34C759), const Color(0xFF30D158)],
    [const Color(0xFFFF9500), const Color(0xFFFFCC00)],
    [const Color(0xFFAF52DE), const Color(0xFFBF5AF2)],
    [const Color(0xFFFF2D55), const Color(0xFFFF6B81)],
    [const Color(0xFF00C7BE), const Color(0xFF5AC8FA)],
  ];
  final idx = serverName.hashCode.abs() % gradients.length;
  final g = gradients[idx];
  return Container(
    width: size, height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.27),
      gradient: LinearGradient(
        colors: [g[0], g[1]],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Text(letter,
          style: TextStyle(
            color: Colors.white, fontSize: size * 0.42,
            fontWeight: FontWeight.w800, height: 1,
          )),
    ),
  );
}

class ServerSelectorCard extends StatelessWidget {
  final VpnServer? server;
  final bool isConnected;

  const ServerSelectorCard({
    super.key,
    required this.server,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isConnected
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ServersScreen(isPicker: true)),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Server avatar
              server != null
                  ? _buildServerAvatar(server!.name, size: 52)
                  : Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.language_rounded, color: Colors.white, size: 26),
                    ),
              const SizedBox(width: 14),
              // Server info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server?.name ?? 'Serwer saýlaň',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          server?.country ?? '—',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (server != null) ...[
                          const SizedBox(width: 8),
                          _PingDot(ping: server!.ping),
                          const SizedBox(width: 4),
                          Text(
                            server!.pingLabel,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: _pingColor(server!.pingQuality),
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Protocol badge + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (server != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        server!.protocol,
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (!isConnected)
                    Icon(
                      Icons.unfold_more_rounded,
                      color: isDark
                          ? AppTheme.darkSubtext
                          : AppTheme.lightSubtext,
                      size: 18,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _pingColor(String quality) {
    switch (quality) {
      case 'excellent':
        return AppTheme.connected;
      case 'good':
        return const Color(0xFF34C759);
      case 'fair':
        return AppTheme.connecting;
      case 'poor':
        return AppTheme.disconnected;
      default:
        return AppTheme.darkSubtext;
    }
  }
}

class _PingDot extends StatelessWidget {
  final int ping;
  const _PingDot({required this.ping});

  Color get color {
    if (ping <= 0) return AppTheme.darkSubtext;
    if (ping < 80) return AppTheme.connected;
    if (ping < 150) return AppTheme.connecting;
    return AppTheme.disconnected;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
