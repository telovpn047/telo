import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoConnect = false;
  bool _splitTunneling = false;
  bool _killSwitch = false;
  String _selectedProtocol = 'AUTO';

  ThemeMode get themeMode => _themeMode;
  bool get autoConnect => _autoConnect;
  bool get splitTunneling => _splitTunneling;
  bool get killSwitch => _killSwitch;
  String get selectedProtocol => _selectedProtocol;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themePref = prefs.getString('theme') ?? 'system';
    _themeMode = themePref == 'light'
        ? ThemeMode.light
        : themePref == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;
    _autoConnect = prefs.getBool('autoConnect') ?? false;
    _splitTunneling = prefs.getBool('splitTunneling') ?? false;
    _killSwitch = prefs.getBool('killSwitch') ?? false;
    _selectedProtocol = prefs.getString('protocol') ?? 'AUTO';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'theme',
        mode == ThemeMode.light
            ? 'light'
            : mode == ThemeMode.dark
                ? 'dark'
                : 'system');
    notifyListeners();
  }

  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoConnect', value);
    notifyListeners();
  }

  Future<void> setSplitTunneling(bool value) async {
    _splitTunneling = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('splitTunneling', value);
    notifyListeners();
  }

  Future<void> setKillSwitch(bool value) async {
    _killSwitch = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('killSwitch', value);
    notifyListeners();
  }

  Future<void> setProtocol(String protocol) async {
    _selectedProtocol = protocol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('protocol', protocol);
    notifyListeners();
  }
}
