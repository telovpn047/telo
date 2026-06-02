import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _autoConnect = false;
  bool _splitTunneling = false;
  bool _killSwitch = false;
  String _selectedProtocol = 'AUTO';

  // DNS
  String _primaryDns = '8.8.8.8';
  String _secondaryDns = '1.1.1.1';

  // Fragment
  bool _enableFragment = false;
  String _fragmentLength = '100-200';
  String _fragmentInterval = '10-20';

  // Mux
  bool _enableMux = false;
  int _muxConcurrency = 8;

  ThemeMode get themeMode => _themeMode;
  bool get autoConnect => _autoConnect;
  bool get splitTunneling => _splitTunneling;
  bool get killSwitch => _killSwitch;
  String get selectedProtocol => _selectedProtocol;

  String get primaryDns => _primaryDns;
  String get secondaryDns => _secondaryDns;

  bool get enableFragment => _enableFragment;
  String get fragmentLength => _fragmentLength;
  String get fragmentInterval => _fragmentInterval;

  bool get enableMux => _enableMux;
  int get muxConcurrency => _muxConcurrency;

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
    _primaryDns = prefs.getString('primaryDns') ?? '8.8.8.8';
    _secondaryDns = prefs.getString('secondaryDns') ?? '1.1.1.1';
    _enableFragment = prefs.getBool('enableFragment') ?? false;
    _fragmentLength = prefs.getString('fragmentLength') ?? '100-200';
    _fragmentInterval = prefs.getString('fragmentInterval') ?? '10-20';
    _enableMux = prefs.getBool('enableMux') ?? false;
    _muxConcurrency = prefs.getInt('muxConcurrency') ?? 8;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', mode == ThemeMode.light ? 'light' : mode == ThemeMode.dark ? 'dark' : 'system');
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

  Future<void> setPrimaryDns(String value) async {
    _primaryDns = value.trim().isEmpty ? '8.8.8.8' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('primaryDns', _primaryDns);
    notifyListeners();
  }

  Future<void> setSecondaryDns(String value) async {
    _secondaryDns = value.trim().isEmpty ? '1.1.1.1' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('secondaryDns', _secondaryDns);
    notifyListeners();
  }

  Future<void> setEnableFragment(bool value) async {
    _enableFragment = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableFragment', value);
    notifyListeners();
  }

  Future<void> setFragmentLength(String value) async {
    _fragmentLength = value.trim().isEmpty ? '100-200' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fragmentLength', _fragmentLength);
    notifyListeners();
  }

  Future<void> setFragmentInterval(String value) async {
    _fragmentInterval = value.trim().isEmpty ? '10-20' : value.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fragmentInterval', _fragmentInterval);
    notifyListeners();
  }

  Future<void> setEnableMux(bool value) async {
    _enableMux = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableMux', value);
    notifyListeners();
  }

  Future<void> setMuxConcurrency(int value) async {
    _muxConcurrency = value.clamp(1, 64);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('muxConcurrency', _muxConcurrency);
    notifyListeners();
  }
}
