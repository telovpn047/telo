import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/vpn_server.dart';
import '../models/subscription.dart';
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
                onPressed: () => Navigator.pop(context))
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
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'QR Skan',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Ekle',
            onPressed: _handleAdd,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext,
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
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Serwer gözle...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        })
                    : null,
                filled: true,
                fillColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGroupedTab(),
                _buildFavoritesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Smart add ─────────────────────────────────────────────────────────────

  Future<void> _handleAdd() async {
    String clipboard = '';
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      clipboard = data?.text?.trim() ?? '';
    } catch (_) {}
    _showSmartAddSheet(clipboard);
  }

  void _showSmartAddSheet(String initialText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.darkSurface : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SmartAddSheet(initialText: initialText),
    );
  }

  // ── Grouped (All Servers) tab ─────────────────────────────────────────────

  Widget _buildGroupedTab() {
    return Consumer<VpnProvider>(
      builder: (context, vpn, _) {
        final items = <Widget>[];

        for (final sub in vpn.subscriptions) {
          final subServers = vpn.servers
              .where((s) => s.subscriptionUrl == sub.url)
              .where((s) {
            if (_searchQuery.isEmpty) return true;
            final matchesSub = sub.name.toLowerCase().contains(_searchQuery);
            return matchesSub ||
                s.name.toLowerCase().contains(_searchQuery) ||
                s.country.toLowerCase().contains(_searchQuery) ||
                s.protocol.toLowerCase().contains(_searchQuery);
          }).toList();

          if (_searchQuery.isNotEmpty && subServers.isEmpty) continue;

          items.add(_SubscriptionGroupCard(
            key: ValueKey(sub.url),
            sub: sub,
            servers: subServers,
            isPicker: widget.isPicker,
          ).animate().fadeIn(duration: 250.ms));
        }

        final customServers = vpn.servers
            .where((s) => s.isCustom)
            .where((s) =>
                _searchQuery.isEmpty ||
                s.name.toLowerCase().contains(_searchQuery) ||
                s.country.toLowerCase().contains(_searchQuery) ||
                s.protocol.toLowerCase().contains(_searchQuery))
            .toList();

        if (customServers.isNotEmpty) {
          items.add(_buildCustomHeader());
          items.addAll(customServers.asMap().entries.map((e) => _ServerTile(
            server: e.value,
            isSelected: vpn.selectedServer?.id == e.value.id,
            isPicker: widget.isPicker,
            grouped: false,
          ).animate().fadeIn(delay: Duration(milliseconds: e.key * 20), duration: 200.ms)));
        }

        if (items.isEmpty) {
          return _buildEmpty();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: items,
        );
      },
    );
  }

  Widget _buildCustomHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.connecting.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_pin_rounded, size: 14, color: AppTheme.connecting),
                const SizedBox(width: 5),
                Text('Öz Serwerler',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: AppTheme.connecting)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Favorites tab ─────────────────────────────────────────────────────────

  Widget _buildFavoritesTab() {
    return Consumer<VpnProvider>(
      builder: (context, vpn, _) {
        final favs = vpn.servers
            .where((s) => s.isFavorite)
            .where((s) =>
                _searchQuery.isEmpty ||
                s.name.toLowerCase().contains(_searchQuery) ||
                s.country.toLowerCase().contains(_searchQuery))
            .toList();

        if (favs.isEmpty) return _buildEmpty();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: favs.length,
          itemBuilder: (context, index) => _ServerTile(
            server: favs[index],
            isSelected: vpn.selectedServer?.id == favs[index].id,
            isPicker: widget.isPicker,
            grouped: false,
          ).animate().fadeIn(delay: Duration(milliseconds: index * 30), duration: 250.ms),
        );
      },
    );
  }

  Widget _buildEmpty() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dns_outlined, size: 48,
              color: isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext),
          const SizedBox(height: 12),
          Text('Serwer tapylmady',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── Smart Add Sheet ──────────────────────────────────────────────────────────

class _SmartAddSheet extends StatefulWidget {
  final String initialText;
  const _SmartAddSheet({this.initialText = ''});

  @override
  State<_SmartAddSheet> createState() => _SmartAddSheetState();
}

class _SmartAddSheetState extends State<_SmartAddSheet> {
  late TextEditingController _ctrl;
  String? _type; // 'sub' | 'servers' | null
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _detect(widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _detect(String raw) {
    final text = raw.trim();
    if (text.isEmpty) { setState(() { _type = null; _count = 0; }); return; }

    if ((text.startsWith('http://') || text.startsWith('https://')) &&
        !text.contains('\n')) {
      setState(() { _type = 'sub'; _count = 0; });
      return;
    }

    final cnt = text.split('\n').where((l) {
      final t = l.trim();
      return t.startsWith('vless://') || t.startsWith('vmess://') ||
          t.startsWith('trojan://') || t.startsWith('ss://');
    }).length;

    setState(() { _type = cnt > 0 ? 'servers' : null; _count = cnt; });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Ekle', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.paste_rounded, size: 14),
                label: const Text('Panodan yapıştır'),
                onPressed: () async {
                  try {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _ctrl.text = data!.text!.trim();
                      _detect(_ctrl.text);
                    }
                  } catch (_) {}
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Detection indicator
          if (_type == 'sub')
            _DetectionChip(
              icon: Icons.subscriptions_outlined,
              text: 'Abuna URL algılandı',
              color: AppTheme.connected,
            )
          else if (_type == 'servers')
            _DetectionChip(
              icon: Icons.dns_rounded,
              text: '$_count sunucu bulundu',
              color: AppTheme.primaryBlue,
            )
          else if (_ctrl.text.isNotEmpty)
            _DetectionChip(
              icon: Icons.help_outline_rounded,
              text: 'vless:// · vmess:// · https:// girin',
              color: isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext,
            ),
          if (_ctrl.text.isNotEmpty) const SizedBox(height: 8),
          // Text field
          TextField(
            controller: _ctrl,
            maxLines: 4,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            onChanged: _detect,
            decoration: InputDecoration(
              hintText: 'vless://...   ya da   https://abuna.url',
              filled: true,
              fillColor: isDark ? AppTheme.darkCard : AppTheme.lightCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.primaryBlue.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _type == null ? null : _doAdd,
              child: Text(
                _type == 'sub' ? 'Abuna Ekle'
                    : _type == 'servers' ? '$_count Sunucu Ekle'
                    : 'Ekle',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _doAdd() async {
    final text = _ctrl.text.trim();
    final vpn = Provider.of<VpnProvider>(context, listen: false);
    Navigator.pop(context);

    if (_type == 'sub') {
      final err = await vpn.addSubscriptionFromUrl(text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err ?? 'Abuna eklendi!'),
          backgroundColor: err == null ? AppTheme.connected : AppTheme.disconnected,
        ));
      }
    } else if (_type == 'servers') {
      final success = vpn.addServerFromConfig(text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? '$_count sunucu eklendi!' : 'Geçerli format bulunamadı'),
          backgroundColor: success ? AppTheme.connected : AppTheme.disconnected,
        ));
      }
    }
  }
}

// ── Detection chip ───────────────────────────────────────────────────────────

class _DetectionChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _DetectionChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Subscription Group Card ──────────────────────────────────────────────────

class _SubscriptionGroupCard extends StatefulWidget {
  final SubscriptionInfo sub;
  final List<VpnServer> servers;
  final bool isPicker;

  const _SubscriptionGroupCard({
    super.key,
    required this.sub,
    required this.servers,
    required this.isPicker,
  });

  @override
  State<_SubscriptionGroupCard> createState() => _SubscriptionGroupCardState();
}

class _SubscriptionGroupCardState extends State<_SubscriptionGroupCard> {
  bool _expanded = true;
  bool _isRefreshing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = widget.sub;
    final cardColor = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final subtext = isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext;
    final dividerColor = isDark ? AppTheme.darkDivider : AppTheme.lightDivider;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────────
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: _expanded ? Radius.zero : const Radius.circular(16),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmtDateTime(sub.lastUpdated)}  •  Auto: ${sub.autoUpdateHours}h',
                          style: TextStyle(fontSize: 11, color: subtext),
                        ),
                      ],
                    ),
                  ),
                  // Refresh
                  if (_isRefreshing)
                    const Padding(
                      padding: EdgeInsets.all(9),
                      child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      tooltip: 'Täzele',
                      onPressed: _doRefresh,
                    ),
                  // Ping
                  IconButton(
                    icon: const Icon(Icons.network_ping_rounded, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    tooltip: 'Ping ölç',
                    onPressed: () =>
                        Provider.of<VpnProvider>(context, listen: false).pingAllServers(),
                  ),
                  // More
                  PopupMenuButton<String>(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    tooltip: 'Seçenekler',
                    onSelected: _handleMenu,
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename',
                          child: Text('Adını Değiştir')),
                      const PopupMenuItem(value: 'interval',
                          child: Text('Güncelleme Aralığı')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Sil',
                            style: TextStyle(color: AppTheme.disconnected)),
                      ),
                    ],
                  ),
                  // Chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, size: 20, color: subtext),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),

          // ── Usage / expiry bar ────────────────────────────────────────────
          if (sub.hasInfo)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!sub.isUnlimited) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: sub.usageRatio,
                              minHeight: 5,
                              backgroundColor: dividerColor,
                              valueColor: AlwaysStoppedAnimation(_usageColor(sub.usageRatio)),
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Row(
                          children: [
                            if (sub.usageText.isNotEmpty)
                              Text(sub.usageText,
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (sub.expireDate != null)
                              Text(
                                'Bitiş: ${_fmtDate(sub.expireDate!)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: (sub.daysLeft ?? 99) < 7
                                      ? AppTheme.disconnected
                                      : subtext,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // ── Server list ───────────────────────────────────────────────────
          if (_expanded && widget.servers.isNotEmpty) ...[
            Divider(height: 1, thickness: 0.5, color: dividerColor),
            ...widget.servers.asMap().entries.map((entry) {
              final i = entry.key;
              final server = entry.value;
              final isLast = i == widget.servers.length - 1;
              return Column(
                children: [
                  Consumer<VpnProvider>(
                    builder: (ctx, vpn, _) => _ServerTile(
                      server: server,
                      isSelected: vpn.selectedServer?.id == server.id,
                      isPicker: widget.isPicker,
                      grouped: true,
                    ),
                  ),
                  if (!isLast)
                    Divider(
                        height: 1, thickness: 0.5,
                        indent: 60, color: dividerColor),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  Color _usageColor(double r) {
    if (r < 0.7) return AppTheme.connected;
    if (r < 0.9) return AppTheme.connecting;
    return AppTheme.disconnected;
  }

  String _fmtDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  Future<void> _doRefresh() async {
    setState(() => _isRefreshing = true);
    final vpn = Provider.of<VpnProvider>(context, listen: false);
    final err = await vpn.refreshSubscription(widget.sub.url);
    if (mounted) {
      setState(() => _isRefreshing = false);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: AppTheme.disconnected,
        ));
      }
    }
  }

  Future<void> _handleMenu(String action) async {
    final vpn = Provider.of<VpnProvider>(context, listen: false);
    switch (action) {
      case 'rename':
        final ctrl = TextEditingController(text: widget.sub.name);
        final newName = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Abuna Adını Değiştir'),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Abuna adı'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal')),
              TextButton(
                  onPressed: () => Navigator.pop(context, ctrl.text.trim()),
                  child: const Text('Kaydet')),
            ],
          ),
        );
        if (newName != null && newName.isNotEmpty) {
          await vpn.renameSubscription(widget.sub.url, newName);
        }
        break;

      case 'interval':
        final picked = await showDialog<int>(
          context: context,
          builder: (_) => SimpleDialog(
            title: const Text('Güncelleme Aralığı'),
            children: [1, 3, 6, 12, 24].map((h) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, h),
              child: Text(
                h == 1 ? 'Her saat' : 'Her $h saatte bir',
                style: TextStyle(
                  fontWeight: widget.sub.autoUpdateHours == h
                      ? FontWeight.w700 : null,
                  color: widget.sub.autoUpdateHours == h
                      ? AppTheme.primaryBlue : null,
                ),
              ),
            )).toList(),
          ),
        );
        if (picked != null) {
          await vpn.setSubscriptionAutoUpdate(widget.sub.url, picked);
        }
        break;

      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Abunayı Sil'),
            content: Text('"${widget.sub.name}" silinsin mi?\nTüm sunucular da silinecek.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('İptal')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Sil',
                    style: TextStyle(color: AppTheme.disconnected)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await vpn.removeSubscription(widget.sub.url);
        }
        break;
    }
  }
}

// ── Server Tile ──────────────────────────────────────────────────────────────

class _ServerTile extends StatelessWidget {
  final VpnServer server;
  final bool isSelected;
  final bool isPicker;
  final bool grouped;

  const _ServerTile({
    required this.server,
    required this.isSelected,
    required this.isPicker,
    required this.grouped,
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
            vpn.pingResults[server.id] ==
                vpn.pingResults.values
                    .where((p) => p > 0)
                    .fold<int>(999999, (m, p) => p < m ? p : m);

        final content = _buildContent(
            context, vpn, isDark, pingQuality, pingLabel, isBest);

        if (grouped) {
          return InkWell(
            onTap: () {
              vpn.selectServer(server);
              if (isPicker) Navigator.pop(context);
            },
            child: content,
          );
        }

        return Dismissible(
          key: Key(server.id),
          direction: (server.isCustom || server.isFromSubscription)
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
          confirmDismiss: (_) async => await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Serweri Poz'),
              content: Text('${server.name} pozulsynmy?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Yok')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Poz',
                      style: TextStyle(color: AppTheme.disconnected)),
                ),
              ],
            ),
          ) ?? false,
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
                child: content,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, VpnProvider vpn, bool isDark,
      String pingQuality, String pingLabel, bool isBest) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(server.flagEmoji, style: const TextStyle(fontSize: 28)),
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
                              ),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (isBest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.connected.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('EN GYZ',
                            style: TextStyle(
                                fontSize: 8,
                                color: AppTheme.connected,
                                fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(server.country,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 8),
                    if (vpn.isPinging && vpn.pingResults[server.id] == null)
                      SizedBox(
                          width: 10, height: 10,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppTheme.primaryBlue))
                    else ...[
                      Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _pingColor(pingQuality))),
                      const SizedBox(width: 4),
                      Text(pingLabel,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: _pingColor(pingQuality))),
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
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w700)),
              ),
              if (server.load > 0) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: server.load,
                      minHeight: 4,
                      backgroundColor:
                          isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        server.load < 0.5
                            ? AppTheme.connected
                            : server.load < 0.75
                                ? AppTheme.connecting
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
              server.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: server.isFavorite
                  ? const Color(0xFFFFCC00)
                  : isDark ? AppTheme.darkSubtext : AppTheme.lightSubtext,
            ),
            onPressed: () => vpn.toggleFavorite(server.id),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
