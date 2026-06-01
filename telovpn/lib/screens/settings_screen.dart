import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Sazlamalar')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Appearance section
              _SectionHeader(title: 'Görünüş'),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.dark_mode_rounded,
                    iconColor: const Color(0xFF6E6E93),
                    title: 'Tema',
                    trailing: SegmentedButton<ThemeMode>(
                      selected: {settings.themeMode},
                      onSelectionChanged: (v) =>
                          settings.setThemeMode(v.first),
                      segments: const [
                        ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded, size: 16)),
                        ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.auto_mode_rounded, size: 16)),
                        ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded, size: 16)),
                      ],
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Connection section
              _SectionHeader(title: 'Birikme'),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.bolt_rounded,
                    iconColor: AppTheme.connecting,
                    title: 'Awtomatik Birikme',
                    subtitle: 'Başlanda özbaşdak birikdir',
                    trailing: Switch(
                      value: settings.autoConnect,
                      onChanged: settings.setAutoConnect,
                    ),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.security_rounded,
                    iconColor: AppTheme.disconnected,
                    title: 'Kill Switch',
                    subtitle: 'VPN kesilse interneti öçür',
                    trailing: Switch(
                      value: settings.killSwitch,
                      onChanged: settings.setKillSwitch,
                    ),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.route_rounded,
                    iconColor: AppTheme.primaryBlue,
                    title: 'Split Tunneling',
                    subtitle: 'Käbir programmalar üçin VPN',
                    trailing: Switch(
                      value: settings.splitTunneling,
                      onChanged: settings.setSplitTunneling,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Protocol section
              _SectionHeader(title: 'Protokol'),
              _SettingsCard(
                children: [
                  ...['AUTO', 'VLESS', 'VMESS', 'TROJAN', 'SHADOWSOCKS']
                      .map((p) => Column(
                            children: [
                              _ProtocolTile(
                                protocol: p,
                                isSelected:
                                    settings.selectedProtocol == p,
                                onTap: () => settings.setProtocol(p),
                              ),
                              if (p != 'SHADOWSOCKS') _Divider(),
                            ],
                          )),
                ],
              ),
              const SizedBox(height: 16),

              // About section
              _SectionHeader(title: 'Barada'),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: AppTheme.primaryBlue,
                    title: 'Wersiýa',
                    trailing: Text('1.0.0',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.shield_outlined,
                    iconColor: AppTheme.connected,
                    title: 'Gizlinlik Syýasaty',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                  _Divider(),
                  _SettingsTile(
                    icon: Icons.description_outlined,
                    iconColor: AppTheme.connecting,
                    title: 'Ulanmak Şertleri',
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryBlue,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: Theme.of(context).textTheme.bodySmall)
          : null,
      trailing: trailing,
    );
  }
}

class _ProtocolTile extends StatelessWidget {
  final String protocol;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProtocolTile({
    required this.protocol,
    required this.isSelected,
    required this.onTap,
  });

  String get _description {
    switch (protocol) {
      case 'AUTO':
        return 'Iň gowy protokoly saý';
      case 'VLESS':
        return 'Ýeňil we çalt';
      case 'VMESS':
        return 'Standart V2Ray';
      case 'TROJAN':
        return 'HTTPS görnüşinde';
      case 'SHADOWSOCKS':
        return 'Klassyk şifrlemek';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(protocol,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isSelected ? AppTheme.primaryBlue : null,
              )),
      subtitle:
          Text(_description, style: Theme.of(context).textTheme.bodySmall),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded,
              color: AppTheme.primaryBlue)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 66,
      color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
    );
  }
}
