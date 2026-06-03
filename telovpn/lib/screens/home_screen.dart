import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/vpn_provider.dart';
import '../services/settings_provider.dart';
import '../models/vpn_server.dart';
import '../theme/app_theme.dart';
import '../widgets/connect_button.dart';
import '../widgets/stats_card.dart';
import '../widgets/server_selector_card.dart';
import 'servers_screen.dart' show SmartAddSheet;

String? _extractFlag(String name) {
  final runes = name.runes.toList();
  if (runes.length >= 2 &&
      runes[0] >= 0x1F1E6 && runes[0] <= 0x1F1FF &&
      runes[1] >= 0x1F1E6 && runes[1] <= 0x1F1FF) {
    return String.fromCharCodes(runes.take(2));
  }
  return null;
}

Future<void> _openSmartAdd(BuildContext context) async {
  String clipboard = '';
  try {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    clipboard = data?.text?.trim() ?? '';
  } catch (_) {}
  if (!context.mounted) return;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSurface
        : AppTheme.lightSurface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => SmartAddSheet(initialText: clipboard),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryBlue, AppTheme.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('TeloVPN'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Ekle',
            onPressed: () => _openSmartAdd(context),
          ),
        ],
      ),
      body: Consumer<VpnProvider>(
        builder: (context, vpn, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 24),
                _StatusBanner(status: vpn.status)
                    .animate()
                    .fadeIn(duration: 400.ms),
                const SizedBox(height: 32),
                ConnectButton(
                  status: vpn.status,
                  onPressed: () => vpn.toggleConnection(),
                ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(height: 32),
                ServerSelectorCard(
                  server: vpn.selectedServer,
                  isConnected: vpn.isConnected,
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 16),
                if (!vpn.isConnected && !vpn.isConnecting)
                  _AutoSelectButton()
                      .animate()
                      .fadeIn(delay: 250.ms, duration: 400.ms),
                const SizedBox(height: 16),
                if (vpn.isConnected) ...[
                  StatsCard(stats: vpn.stats)
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 16),
                  _ConnectionDuration(duration: vpn.connectionDuration)
                      .animate()
                      .fadeIn(duration: 300.ms),
                ],
                const SizedBox(height: 32),
                _QuickServers(servers: vpn.favoriteServers)
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final VpnStatus status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    String text;
    IconData icon;

    switch (status) {
      case VpnStatus.connected:
        color = AppTheme.connected;
        text = 'Birikdirildi';
        icon = Icons.lock_rounded;
        break;
      case VpnStatus.connecting:
        color = AppTheme.connecting;
        text = 'Birikdirilýär...';
        icon = Icons.sync_rounded;
        break;
      case VpnStatus.disconnecting:
        color = AppTheme.connecting;
        text = 'Kesilýär...';
        icon = Icons.sync_rounded;
        break;
      case VpnStatus.error:
        color = AppTheme.disconnected;
        text = 'Ýalňyşlyk';
        icon = Icons.error_outline_rounded;
        break;
      default:
        color = AppTheme.disconnected;
        text = 'Birikdirilmedi';
        icon = Icons.lock_open_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          status == VpnStatus.connecting || status == VpnStatus.disconnecting
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color),
                )
              : Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionDuration extends StatelessWidget {
  final Duration duration;
  const _ConnectionDuration({required this.duration});

  String get _formatted {
    final h = duration.inHours.toString().padLeft(2, '0');
    final m = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.timer_outlined,
            size: 16,
            color: isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext),
        const SizedBox(width: 6),
        Text(
          _formatted,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _QuickServers extends StatelessWidget {
  final List<VpnServer> servers;
  const _QuickServers({required this.servers});

  @override
  Widget build(BuildContext context) {
    if (servers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Halanlarym',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ...servers.map((server) => _QuickServerTile(server: server)),
      ],
    );
  }
}

class _QuickServerTile extends StatelessWidget {
  final VpnServer server;
  const _QuickServerTile({required this.server});

  @override
  Widget build(BuildContext context) {
    final vpn = Provider.of<VpnProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => vpn.selectServer(server),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Builder(builder: (context) {
                  final leadingFlag = _extractFlag(server.name);
                  return Text(
                    leadingFlag ?? server.flagEmoji,
                    style: TextStyle(fontSize: leadingFlag != null ? 36.0 : 28.0),
                  );
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          () {
                            final f = _extractFlag(server.name);
                            return f != null
                                ? server.name.substring(f.length).trimLeft()
                                : server.name;
                          }(),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium),
                      Text(server.country,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    server.protocol,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    color: isDark
                        ? AppTheme.darkSubtext
                        : AppTheme.lightSubtext),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoSelectButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<VpnProvider>(
      builder: (context, vpn, _) {
        final isPinging = vpn.isPinging;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isPinging ? null : () async {
                final settings = Provider.of<SettingsProvider>(context, listen: false);
                final best = await vpn.autoSelectBestServer(
                  protocolFilter: settings.selectedProtocol,
                );
                if (best != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      Text(best.flagEmoji, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${best.name} saýlandy -- ${best.ping} ms',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                    ]),
                    backgroundColor: AppTheme.connected,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 3),
                  ));
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: isPinging
                        ? Padding(padding: const EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryBlue))
                        : const Icon(Icons.bolt_rounded, color: AppTheme.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isPinging ? 'Serwerler barlanyor...' : 'Akylly Saylaw',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                    Text(isPinging ? 'Ping olculyor, garasyn' : 'In pes pingli serweri awtomatik say',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
                  if (!isPinging && vpn.pingResults.isNotEmpty) _BestPingBadge(vpn: vpn),
                  if (!isPinging) const Icon(Icons.chevron_right_rounded, color: AppTheme.primaryBlue),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BestPingBadge extends StatelessWidget {
  final VpnProvider vpn;
  const _BestPingBadge({required this.vpn});

  @override
  Widget build(BuildContext context) {
    final pings = vpn.pingResults.values.where((p) => p > 0);
    if (pings.isEmpty) return const SizedBox.shrink();
    final bestPing = pings.reduce((a, b) => a < b ? a : b);
    final color = bestPing < 80 ? AppTheme.connected : bestPing < 150 ? AppTheme.connecting : AppTheme.disconnected;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text('$bestPing ms', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
