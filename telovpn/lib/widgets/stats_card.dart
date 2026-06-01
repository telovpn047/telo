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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.arrow_downward_rounded,
              iconColor: AppTheme.connected,
              label: 'Ýüklenme',
              speed: stats.formattedDownloadSpeed,
              total: stats.formattedDownload,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
          ),
          Expanded(
            child: _StatItem(
              icon: Icons.arrow_upward_rounded,
              iconColor: AppTheme.primaryBlue,
              label: 'Ýüklemek',
              speed: stats.formattedUploadSpeed,
              total: stats.formattedUpload,
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

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.speed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
