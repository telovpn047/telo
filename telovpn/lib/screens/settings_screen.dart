import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/settings_provider.dart';
import '../theme/app_theme.dart';
import 'log_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _primaryDnsCtrl;
  late TextEditingController _secondaryDnsCtrl;
  late TextEditingController _fragmentLengthCtrl;
  late TextEditingController _fragmentIntervalCtrl;
  late TextEditingController _muxConcurrencyCtrl;

  bool _initialized = false;

  @override
  void dispose() {
    _primaryDnsCtrl.dispose();
    _secondaryDnsCtrl.dispose();
    _fragmentLengthCtrl.dispose();
    _fragmentIntervalCtrl.dispose();
    _muxConcurrencyCtrl.dispose();
    super.dispose();
  }

  void _init(SettingsProvider s) {
    if (_initialized) return;
    _initialized = true;
    _primaryDnsCtrl = TextEditingController(text: s.primaryDns);
    _secondaryDnsCtrl = TextEditingController(text: s.secondaryDns);
    _fragmentLengthCtrl = TextEditingController(text: s.fragmentLength);
    _fragmentIntervalCtrl = TextEditingController(text: s.fragmentInterval);
    _muxConcurrencyCtrl = TextEditingController(text: '${s.muxConcurrency}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sazlamalar')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          _init(settings);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Görünüş ──────────────────────────────────────────────────
              _SectionHeader(title: 'Görünüş'),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  iconColor: const Color(0xFF6E6E93),
                  title: 'Tema',
                  trailing: SegmentedButton<ThemeMode>(
                    selected: {settings.themeMode},
                    onSelectionChanged: (v) => settings.setThemeMode(v.first),
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded, size: 16)),
                      ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.auto_mode_rounded, size: 16)),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded, size: 16)),
                    ],
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Birikme ───────────────────────────────────────────────────
              _SectionHeader(title: 'Birikme'),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.bolt_rounded,
                  iconColor: AppTheme.connecting,
                  title: 'Awtomatik Birikme',
                  subtitle: 'Başlanda özbaşdak birikdir',
                  trailing: Switch(value: settings.autoConnect, onChanged: settings.setAutoConnect),
                ),
                _Divider(),
                _SettingsTile(
                  icon: Icons.security_rounded,
                  iconColor: AppTheme.disconnected,
                  title: 'Kill Switch',
                  subtitle: 'VPN kesilse interneti öçür',
                  trailing: Switch(value: settings.killSwitch, onChanged: settings.setKillSwitch),
                ),
                _Divider(),
                _SettingsTile(
                  icon: Icons.route_rounded,
                  iconColor: AppTheme.primaryBlue,
                  title: 'Split Tunneling',
                  subtitle: 'Käbir programmalar üçin VPN',
                  trailing: Switch(value: settings.splitTunneling, onChanged: settings.setSplitTunneling),
                ),
              ]),
              const SizedBox(height: 16),

              // ── DNS ────────────────────────────────────────────────────────
              _SectionHeader(title: 'DNS'),
              _SettingsCard(children: [
                _InlineTextField(
                  icon: Icons.dns_rounded,
                  iconColor: AppTheme.primaryBlue,
                  label: 'Esasy DNS',
                  controller: _primaryDnsCtrl,
                  keyboardType: TextInputType.url,
                  hint: '8.8.8.8',
                  onChanged: settings.setPrimaryDns,
                ),
                _Divider(),
                _InlineTextField(
                  icon: Icons.dns_outlined,
                  iconColor: const Color(0xFF6E6E93),
                  label: 'Goşmaça DNS',
                  controller: _secondaryDnsCtrl,
                  keyboardType: TextInputType.url,
                  hint: '1.1.1.1',
                  onChanged: settings.setSecondaryDns,
                ),
              ]),
              const SizedBox(height: 16),

              // ── Fragment ────────────────────────────────────────────────────
              _SectionHeader(title: 'Fragment (Bölek)'),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.call_split_rounded,
                  iconColor: const Color(0xFF9C59FF),
                  title: 'Fragment',
                  subtitle: 'DPI engelleme üçin TCP bölekle',
                  trailing: Switch(
                    value: settings.enableFragment,
                    onChanged: settings.setEnableFragment,
                  ),
                ),
                if (settings.enableFragment) ...[
                  _Divider(),
                  _InlineTextField(
                    icon: Icons.straighten_rounded,
                    iconColor: const Color(0xFF9C59FF),
                    label: 'Uzynlyk (Bytes)',
                    controller: _fragmentLengthCtrl,
                    hint: '100-200',
                    onChanged: settings.setFragmentLength,
                  ),
                  _Divider(),
                  _InlineTextField(
                    icon: Icons.timelapse_rounded,
                    iconColor: const Color(0xFF9C59FF),
                    label: 'Aralyk (ms)',
                    controller: _fragmentIntervalCtrl,
                    hint: '10-20',
                    onChanged: settings.setFragmentInterval,
                  ),
                ],
              ]),
              const SizedBox(height: 16),

              // ── Mux ─────────────────────────────────────────────────────────
              _SectionHeader(title: 'Mux (Köpugurlylyk)'),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.merge_type_rounded,
                  iconColor: const Color(0xFF00B09B),
                  title: 'Mux',
                  subtitle: 'Birikme çaltlygyny artdyr',
                  trailing: Switch(value: settings.enableMux, onChanged: settings.setEnableMux),
                ),
                if (settings.enableMux) ...[
                  _Divider(),
                  _InlineTextField(
                    icon: Icons.format_list_numbered_rounded,
                    iconColor: const Color(0xFF00B09B),
                    label: 'Birikme Sany',
                    controller: _muxConcurrencyCtrl,
                    hint: '8',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n > 0) settings.setMuxConcurrency(n);
                    },
                  ),
                ],
              ]),
              const SizedBox(height: 16),

              // ── Barada ───────────────────────────────────────────────────────
              _SectionHeader(title: 'Barada'),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppTheme.primaryBlue,
                  title: 'Wersiýa',
                  trailing: Text('1.0.0', style: Theme.of(context).textTheme.bodySmall),
                ),
                _Divider(),
                _SettingsTile(
                  icon: Icons.shield_outlined,
                  iconColor: AppTheme.connected,
                  title: 'Gizlinlik Syýasaty',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {},
                ),
              ]),
              const SizedBox(height: 16),

              // ── Log Görüntüleyici ─────────────────────────────────────────────
              _SectionHeader(title: 'Günlük (Log)'),
              _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.terminal_rounded,
                  iconColor: const Color(0xFF82AAFF),
                  title: 'VPN Logları',
                  subtitle: 'Xray ve bağlantı kayıtlarını görüntüle',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LogScreen()),
                  ),
                ),
              ]),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

// ── Inline text field tile ─────────────────────────────────────────────────────

class _InlineTextField extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String> onChanged;

  const _InlineTextField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: subtitle != null
          ? Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
          : null,
      trailing: trailing,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1, thickness: 0.5, indent: 66,
      color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
    );
  }
}
