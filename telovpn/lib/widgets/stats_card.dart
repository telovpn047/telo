import 'package:flutter/material.dart';
import '../models/vpn_server.dart';
import '../theme/app_theme.dart';

class StatsCard extends StatelessWidget {
  final VpnStats stats;
  const StatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.connected.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart_rounded,
                    size: 14, color: AppTheme.connected),
              ),
              const SizedBox(width: 8),
              Text('Trafik İstatistikleri',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                width: 6, height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.connected,
                ),
              ),
              const SizedBox(width: 5),
              Text('Canlı', style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.connected, fontWeight: FontWeight.w600)),
            ]),
          ),
          Divider(
            height: 20, thickness: 0.5,
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
            indent: 20, endIndent: 20,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.arrow_downward_rounded,
                    iconColor: AppTheme.connected,
                    label: 'Ýüklenme',
                    speed: stats.formattedDownloadSpeed,
                    total: stats.formattedDownload,
                    gradientColors: [
                      AppTheme.connected.withOpacity(0.15),
                      AppTheme.connected.withOpacity(0.05),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1, height: 60,
                  color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatItem(
                    icon: Icons.arrow_upward_rounded,
                    iconColor: AppTheme.primaryBlue,
                    label: 'Ýüklemek',
                    speed: stats.formattedUploadSpeed,
                    total: stats.formattedUpload,
                    gradientColors: [
                      AppTheme.primaryBlue.withOpacity(0.15),
                      AppTheme.primaryBlue.withOpacity(0.05),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String speed;
  final String total;
  final List<Color> gradientColors;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.speed,
    required this.total,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: iconColor, size: 13),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 10),
          Text(
            speed,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Jemi: $total',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
