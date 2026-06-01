# TeloVPN 🛡️

**Türkmençe** | Samsung One UI tema | Xray/V2Ray tabanlı Android VPN

## Özellikler
- ✅ VLESS, VMESS, Trojan, Shadowsocks protokolleri
- ✅ Reality, TLS, WebSocket, gRPC desteği  
- ✅ QR kod ile sunucu ekleme
- ✅ URI ile sunucu ekleme (vless://, vmess://, trojan://, ss://)
- ✅ Samsung One UI Light/Dark tema
- ✅ Kill Switch, Auto-connect
- ✅ Trafik istatistikleri
- ✅ Ping ve sunucu yük göstergesi
- ✅ Favoriler sistemi
- ✅ Türkmençe arayüz

## APK Build (GitHub Actions - Tavsiye Edilen)

1. Bu klasörü GitHub'a push et
2. **Actions** sekmesine git → `Build TeloVPN APK`
3. Build tamamlanınca **Artifacts** kısmından APK'yı indir
   - `TeloVPN-Release` → app-release.apk (tüm cihazlar)
   - `TeloVPN-Debug` → test için

> ⚡ GitHub Actions ayrıca Xray binary'lerini ve geoip/geosite dosyalarını otomatik indirir!

## Lokal Build

```bash
# Xray binary'lerini manuel indir
mkdir -p android/app/src/main/assets/xray
# https://github.com/XTLS/Xray-core/releases adresinden indir:
# - xray_arm64 (arm64-v8a cihazlar için)
# - xray_arm   (armeabi-v7a cihazlar için)  
# - geoip.dat
# - geosite.dat

flutter pub get
flutter build apk --release
```

## Proje Yapısı

```
lib/
├── main.dart                    # Giriş noktası
├── models/vpn_server.dart       # Veri modelleri
├── services/
│   ├── vpn_provider.dart        # State management
│   ├── vpn_native_service.dart  # Android köprüsü
│   ├── xray_config_builder.dart # Xray JSON config üretici
│   └── settings_provider.dart  # Ayarlar
├── screens/
│   ├── splash_screen.dart
│   ├── main_screen.dart
│   ├── home_screen.dart         # Ana bağlantı ekranı
│   ├── servers_screen.dart      # Sunucu listesi
│   ├── settings_screen.dart     # Ayarlar
│   └── qr_scanner_screen.dart   # QR tarayıcı
├── widgets/
│   ├── connect_button.dart      # Animasyonlu bağlan butonu
│   ├── stats_card.dart          # Trafik istatistikleri
│   └── server_selector_card.dart
└── theme/app_theme.dart         # Samsung One UI tema

android/
├── app/src/main/
│   ├── kotlin/com/telovpn/app/
│   │   ├── MainActivity.kt      # Flutter + MethodChannel
│   │   ├── TeloVpnService.kt    # VPN servisi + Xray başlatma
│   │   └── BootReceiver.kt      # Auto-connect on boot
│   └── assets/xray/             # Xray binary'leri (build sırasında eklenir)
```

## Gereksinimler
- Flutter 3.22+
- Java 17
- Android minSdk 21 (Android 5.0+)
- Android targetSdk 34

## Lisans
MIT
