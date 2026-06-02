import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/vpn_server.dart';
import '../services/vpn_provider.dart';
import '../theme/app_theme.dart';
import 'qr_scanner_screen.dart';

class ServersScreen extends StatefulWidget {
  final bool isPicker;
  const ServersScreen({super.key, this.isPicker = false});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Serwerler'),
        leading: widget.isPicker
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        actions: [
          Consumer<VpnProvider>(
            builder: (ctx, vpn, _) => IconButton(
              icon: vpn.isPinging
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue))
                  : const Icon(Icons.network_ping_rounded),
              tooltip: 'Ping ölç',
              onPressed: vpn.isPinging ? null : () => vpn.pingAllServers(),
            ),
          ),
          Consumer<VpnProvider>(
            builder: (ctx, vpn, _) => IconButton(
              icon: vpn.isRefreshingSubscriptions
                  ? SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryBlue))
                  : const Icon(Icons.subscriptions_outlined),
              tooltip: 'Abuna',
              onPressed: vpn.isRefreshingSubscriptions
                  ? null
                  : () => _showSubscriptionSheet(context),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'QR Skan',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Serwer gos',
            onPressed: () => _showAddServerSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor:
              isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext,
          tabs: const [
            Tab(text: 'Ähli Serwerler'),
            Tab(text: 'Halananlar ⭐'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Serwer gözle...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor:
                    isDark ? AppTheme.darkCard : AppTheme.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ServerList(
                  filter: (s) =>
                      _searchQuery.isEmpty ||
                      s.name.toLowerCase().contains(_searchQuery) ||
                      s.country.toLowerCase().contains(_searchQuery) ||
                      s.protocol.toLowerCase().contains(_searchQuery),
                  isPicker: widget.isPicker,
                ),
                _ServerList(
                  filter: (s) =>
                      s.isFavorite &&
                      (_searchQuery.isEmpty ||
                          s.name.toLowerCase().contains(_searchQuery) ||
                          s.country.toLowerCase().contains(_searchQuery)),
                  isPicker: widget.isPicker,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionSheet(BuildContext context) {
    final urlCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface
          : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final vpn = Provider.of<VpnProvider>(ctx);
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text('Abuna', style: Theme.of(ctx).textTheme.headlineSmall),
                    const Spacer(),
                    if (vpn.subscriptionUrls.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Täzele'),
                        onPressed: vpn.isRefreshingSubscriptions
                            ? null
                            : () => vpn.refreshAllSubscriptions(),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('http:// ýa-da https:// abuna URL goşuň',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: urlCtrl,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'https://example.com/sub',
                          filled: true,
                          fillColor: Theme.of(ctx).brightness == Brightness.dark
                              ? AppTheme.darkCard
                              : AppTheme.lightCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final url = urlCtrl.text.trim();
                        if (url.isEmpty) return;
                        Navigator.pop(ctx);
                        final error = await Provider.of<VpnProvider>(context, listen: false)
                            .addSubscriptionFromUrl(url);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(error ?? 'Abuna goşuldy!'),
                            backgroundColor: error == null
                                ? AppTheme.connected
                                : AppTheme.disconnected,
                          ));
                        }
                      },
                      child: const Text('Goş'),
                    ),
                  ],
                ),
                if (vpn.subscriptionUrls.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Abunalar', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    color: AppTheme.primaryBlue, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 8),
                  ...vpn.subscriptionUrls.map((url) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).brightness == Brightness.dark
                          ? AppTheme.darkCard
                          : AppTheme.lightCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 16, color: AppTheme.primaryBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(url,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final err = await Provider.of<VpnProvider>(context, listen: false)
                                .refreshSubscription(url);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(err ?? 'Täzelendi!'),
                                backgroundColor: err == null
                                    ? AppTheme.connected
                                    : AppTheme.disconnected,
                              ));
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.disconnected),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () {
                            Provider.of<VpnProvider>(ctx, listen: false).removeSubscription(url);
                          },
                        ),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddServerSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface
          : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Serwer Goş',
                style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'vless://, vmess://, trojan://, ss:// formatynda ýazyň',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 5,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'vless://uuid@host:port?type=tcp&security=tls#name',
                filled: true,
                fillColor: Theme.of(ctx).brightness == Brightness.dark
                    ? AppTheme.darkCard
                    : AppTheme.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('Göçür'),
                    onPressed: () async {
                      final data =
                          await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        controller.text = data!.text!;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Goş'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (controller.text.isNotEmpty) {
                        final vpn = Provider.of<VpnProvider>(ctx, listen: false);
                        final success = vpn.addServerFromConfig(controller.text);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Serwer goşuldy!'
                                : 'Nädogry sazlama formaty'),
                            backgroundColor: success
                                ? AppTheme.connected
                                : AppTheme.disconnected,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ServerList extends StatelessWidget {
  final bool Function(VpnServer) filter;
  final bool isPicker;

  const _ServerList({required this.filter, required this.isPicker});

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnProvider>(
      builder: (context, vpn, _) {
        final filtered = vpn.servers.where(filter).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.dns_outlined, size: 48,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.darkSubtext
                        : AppTheme.lightSubtext),
                const SizedBox(height: 12),
                Text('Serwer tapylmady',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _ServerTile(
            server: filtered[index],
            isSelected: vpn.selectedServer?.id == filtered[index].id,
            isPicker: isPicker,
          ).animate().fadeIn(delay: Duration(milliseconds: index * 30), duration: 250.ms),
        );
      },
    );
  }
}

class _ServerTile extends StatelessWidget {
  final VpnServer server;
  final bool isSelected;
  final bool isPicker;

  const _ServerTile({
    required this.server,
    required this.isSelected,
    required this.isPicker,
  });

  Color _pingColor(String q) {
    switch (q) {
      case 'excellent': return AppTheme.connected;
      case 'good': return AppTheme.connected;
      case 'fair': return AppTheme.connecting;
      case 'poor': return AppTheme.disconnected;
      default: return AppTheme.darkSubtext;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCustom = server.isCustom;
    final isSub = server.isFromSubscription;

    return Consumer<VpnProvider>(
      builder: (context, vpn, _) {
        final realtimePing = vpn.pingResults[server.id] ?? server.ping;
        final pingQuality = realtimePing <= 0 ? 'unknown'
            : realtimePing < 80 ? 'excellent'
            : realtimePing < 150 ? 'good'
            : realtimePing < 300 ? 'fair' : 'poor';
        final pingLabel = realtimePing <= 0 ? '—' : '$realtimePing ms';
        final isBest = vpn.pingResults.isNotEmpty &&
            vpn.pingResults[server.id] != null &&
            vpn.pingResults[server.id]! > 0 &&
            vpn.pingResults[server.id] == vpn.pingResults.values.where((p) => p > 0).fold<int>(999999, (m, p) => p < m ? p : m);

    return Dismissible(
      key: Key(server.id),
      direction: (isCustom || isSub)
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.disconnected,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Serweri Poz'),
            content: Text('${server.name} pozulsynmy?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Yok')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Poz', style: TextStyle(color: AppTheme.disconnected)),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) => vpn.deleteServer(server.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: isSelected
              ? AppTheme.primaryBlue.withOpacity(0.1)
              : isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              vpn.selectServer(server);
              if (isPicker) Navigator.pop(context);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(server.flagEmoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(server.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: isSelected ? AppTheme.primaryBlue : null,
                                  ), overflow: TextOverflow.ellipsis),
                            ),
                            if (isBest) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.connected.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('EN GYZ', style: TextStyle(fontSize: 8, color: AppTheme.connected, fontWeight: FontWeight.w800)),
                              ),
                            ] else if (isSub) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Abuna', style: TextStyle(fontSize: 8, color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                              ),
                            ] else if (isCustom) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.connecting.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('Öz', style: TextStyle(fontSize: 9, color: AppTheme.connecting, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(server.country, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(width: 8),
                            if (vpn.isPinging && vpn.pingResults[server.id] == null)
                              SizedBox(width: 10, height: 10,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryBlue))
                            else ...[
                              Container(width: 5, height: 5,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: _pingColor(pingQuality))),
                              const SizedBox(width: 4),
                              Text(pingLabel,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: _pingColor(pingQuality))),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(server.protocol,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                      ),
                      if (server.load > 0) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 50,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: server.load, minHeight: 4,
                              backgroundColor: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                server.load < 0.5 ? AppTheme.connected
                                    : server.load < 0.75 ? AppTheme.connecting
                                    : AppTheme.disconnected,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      server.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: server.isFavorite ? const Color(0xFFFFCC00) : isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext,
                    ),
                    onPressed: () => vpn.toggleFavorite(server.id),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    }); // close Consumer
  }
}
