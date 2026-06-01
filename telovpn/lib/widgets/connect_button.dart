import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/vpn_server.dart';
import '../theme/app_theme.dart';

class ConnectButton extends StatefulWidget {
  final VpnStatus status;
  final VoidCallback onPressed;

  const ConnectButton({
    super.key,
    required this.status,
    required this.onPressed,
  });

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Color get _statusColor {
    switch (widget.status) {
      case VpnStatus.connected:
        return AppTheme.connected;
      case VpnStatus.connecting:
      case VpnStatus.disconnecting:
        return AppTheme.connecting;
      case VpnStatus.error:
        return AppTheme.disconnected;
      default:
        return AppTheme.primaryBlue;
    }
  }

  String get _label {
    switch (widget.status) {
      case VpnStatus.connected:
        return 'Birikdirmegi\nKes';
      case VpnStatus.connecting:
        return 'Birikdirilýär...';
      case VpnStatus.disconnecting:
        return 'Kesilýär...';
      default:
        return 'Birikdir';
    }
  }

  IconData get _icon {
    switch (widget.status) {
      case VpnStatus.connected:
        return Icons.power_settings_new_rounded;
      case VpnStatus.connecting:
      case VpnStatus.disconnecting:
        return Icons.sync_rounded;
      default:
        return Icons.power_settings_new_rounded;
    }
  }

  bool get _isLoading =>
      widget.status == VpnStatus.connecting ||
      widget.status == VpnStatus.disconnecting;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring (only when connected)
          if (widget.status == VpnStatus.connected)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) => Container(
                width: 190 + _pulseController.value * 20,
                height: 190 + _pulseController.value * 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.connected
                        .withOpacity(0.15 * (1 - _pulseController.value)),
                    width: 2,
                  ),
                ),
              ),
            ),

          // Connecting spinning ring
          if (_isLoading)
            AnimatedBuilder(
              animation: _ringController,
              builder: (_, __) => Transform.rotate(
                angle: _ringController.value * 6.28,
                child: Container(
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        _statusColor.withOpacity(0),
                        _statusColor,
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Background circle
          Container(
            width: 156,
            height: 156,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            ),
          ),

          // Main button
          GestureDetector(
            onTap: _isLoading ? null : widget.onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: widget.status == VpnStatus.connected
                      ? [AppTheme.connected, Color(0xFF2EBD5A)]
                      : [AppTheme.primaryBlue, AppTheme.accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _statusColor.withOpacity(0.4),
                    blurRadius: widget.status == VpnStatus.connected ? 30 : 20,
                    spreadRadius:
                        widget.status == VpnStatus.connected ? 4 : 0,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _isLoading
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Icon(
                          _icon,
                          color: Colors.white,
                          size: 36,
                        ),
                  const SizedBox(height: 6),
                  Text(
                    _label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
