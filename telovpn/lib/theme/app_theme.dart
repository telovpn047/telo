import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Samsung One UI Colors
  static const Color primaryBlue = Color(0xFF0381FE);
  static const Color primaryBlueDark = Color(0xFF0066CC);
  static const Color accentBlue = Color(0xFF4DAAFF);

  // Light theme colors (Samsung One UI Light)
  static const Color lightBg = Color(0xFFF4F4F4);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF000000);
  static const Color lightSubtext = Color(0xFF767676);
  static const Color lightDivider = Color(0xFFE5E5E5);
  static const Color lightNavBg = Color(0xFFFFFFFF);

  // Dark theme colors (Samsung One UI Dark)
  static const Color darkBg = Color(0xFF161616);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2C2C2C);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkSubtext = Color(0xFF888888);
  static const Color darkDivider = Color(0xFF3A3A3A);
  static const Color darkNavBg = Color(0xFF1E1E1E);

  // Status colors
  static const Color connected = Color(0xFF34C759);
  static const Color disconnected = Color(0xFFFF3B30);
  static const Color connecting = Color(0xFFFF9500);

  static TextTheme _buildTextTheme(Color textColor, Color subtextColor) {
    return TextTheme(
      displayLarge: GoogleFonts.nunito(
        fontSize: 32, fontWeight: FontWeight.w700, color: textColor),
      displayMedium: GoogleFonts.nunito(
        fontSize: 28, fontWeight: FontWeight.w700, color: textColor),
      displaySmall: GoogleFonts.nunito(
        fontSize: 24, fontWeight: FontWeight.w600, color: textColor),
      headlineLarge: GoogleFonts.nunito(
        fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
      headlineMedium: GoogleFonts.nunito(
        fontSize: 20, fontWeight: FontWeight.w600, color: textColor),
      headlineSmall: GoogleFonts.nunito(
        fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
      titleLarge: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
      titleMedium: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
      titleSmall: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w600, color: subtextColor),
      bodyLarge: GoogleFonts.nunito(
        fontSize: 16, fontWeight: FontWeight.w400, color: textColor),
      bodyMedium: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w400, color: textColor),
      bodySmall: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w400, color: subtextColor),
      labelLarge: GoogleFonts.nunito(
        fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
      labelMedium: GoogleFonts.nunito(
        fontSize: 12, fontWeight: FontWeight.w500, color: subtextColor),
      labelSmall: GoogleFonts.nunito(
        fontSize: 10, fontWeight: FontWeight.w500, color: subtextColor),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        onPrimary: Colors.white,
        secondary: accentBlue,
        surface: lightSurface,
        background: lightBg,
        onBackground: lightText,
        onSurface: lightText,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: _buildTextTheme(lightText, lightSubtext),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightText,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: lightText,
        ),
      ),
      cardTheme: CardTheme(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightNavBg,
        indicatorColor: primaryBlue.withOpacity(0.15),
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: lightDivider, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected) ? primaryBlue : Colors.white),
        trackColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected)
                ? primaryBlue.withOpacity(0.5)
                : Colors.grey.shade300),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        onPrimary: Colors.white,
        secondary: accentBlue,
        surface: darkSurface,
        background: darkBg,
        onBackground: darkText,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: _buildTextTheme(darkText, darkSubtext),
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkNavBg,
        indicatorColor: primaryBlue.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: darkDivider, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected) ? primaryBlue : Colors.grey),
        trackColor: MaterialStateProperty.resolveWith((states) =>
            states.contains(MaterialState.selected)
                ? primaryBlue.withOpacity(0.5)
                : Colors.grey.shade700),
      ),
    );
  }
}
