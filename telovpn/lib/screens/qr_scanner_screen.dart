import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/vpn_provider.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _scanned = false;
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('QR Kod Skan Et',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, state, child) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.first;
              final rawValue = barcode.rawValue;
              if (rawValue == null) return;

              // Check if it's a valid VPN config
              if (rawValue.startsWith('vless://') ||
                  rawValue.startsWith('vmess://') ||
                  rawValue.startsWith('trojan://') ||
                  rawValue.startsWith('ss://')) {
                setState(() => _scanned = true);
                controller.stop();

                final vpn = Provider.of<VpnProvider>(context, listen: false);
                final success = vpn.addServerFromConfig(rawValue);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AlertDialog(
                    title: Text(success ? 'Goşuldy!' : 'Ýalňyşlyk'),
                    content: Text(
                      success
                          ? 'Serwer üstünlikli goşuldy.'
                          : 'QR kod nädogry VPN sazlamasy.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: const Text('Bolýar'),
                      ),
                      if (!success)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() => _scanned = false);
                            controller.start();
                          },
                          child: const Text('Täzeden Synan'),
                        ),
                    ],
                  ),
                );
              }
            },
          ),

          // Scanner overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryBlue, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Corner decorations
                  ..._buildCorners(),
                ],
              ),
            ),
          ),

          // Bottom hint
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Text(
              'VLESS / VMESS / Trojan / Shadowsocks\nQR kodyny skaner üçin tutdur',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thickness = 3.0;
    const color = AppTheme.primaryBlue;

    return [
      // Top-left
      Positioned(
        top: 0, left: 0,
        child: Container(
          width: size, height: thickness,
          color: color,
        ),
      ),
      Positioned(
        top: 0, left: 0,
        child: Container(
          width: thickness, height: size,
          color: color,
        ),
      ),
      // Top-right
      Positioned(
        top: 0, right: 0,
        child: Container(
          width: size, height: thickness,
          color: color,
        ),
      ),
      Positioned(
        top: 0, right: 0,
        child: Container(
          width: thickness, height: size,
          color: color,
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0, left: 0,
        child: Container(
          width: size, height: thickness,
          color: color,
        ),
      ),
      Positioned(
        bottom: 0, left: 0,
        child: Container(
          width: thickness, height: size,
          color: color,
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          width: size, height: thickness,
          color: color,
        ),
      ),
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          width: thickness, height: size,
          color: color,
        ),
      ),
    ];
  }
}
