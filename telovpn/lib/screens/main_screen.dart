import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ServersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkNavBg : AppTheme.lightNavBg,
          border: Border(
            top: BorderSide(
              color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 72,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield_rounded,
                  color: AppTheme.primaryBlue),
              label: 'Baş Sahypa',
            ),
            NavigationDestination(
              icon: Icon(Icons.dns_outlined),
              selectedIcon:
                  Icon(Icons.dns_rounded, color: AppTheme.primaryBlue),
              label: 'Serwerler',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded,
                  color: AppTheme.primaryBlue),
              label: 'Sazlamalar',
            ),
          ],
        ),
      ),
    );
  }
}
