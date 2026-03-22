import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Backgrounds
  static const Color bgDeep  = Color(0xFF050A14);
  static const Color bgPanel = Color(0xFF08101E);
  static const Color bgCard  = Color(0xFF0D1828);
  static const Color bgHover = Color(0xFF111F35);

  // Accent
  static const Color accent    = Color(0xFF00D4FF);
  static const Color accentDim = Color(0xFF0090B8);

  // Semantic
  static const Color success = Color(0xFF00FF88);
  static const Color danger  = Color(0xFFFF3366);
  static const Color warning = Color(0xFFFFAA00);

  // Text
  static const Color textPrimary = Color(0xFFE8F4FF);
  static const Color textSecond  = Color(0xFF6A8BAA);
  static const Color textMuted   = Color(0xFF2E4560);

  // Border
  static const Color border = Color(0xFF1A2E45);

  // Radii
  static const double rXs = 6.0;
  static const double rSm = 10.0;
  static const double rMd = 16.0;
  static const double rLg = 24.0;

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDeep,
      fontFamily: 'SpaceMono',
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: success,
        error: danger,
        surface: bgCard,
        onSurface: textPrimary,
      ),
      dividerColor: border,
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20, letterSpacing: 2),
        bodyLarge:  TextStyle(color: textPrimary, fontSize: 13),
        bodyMedium: TextStyle(color: textSecond,  fontSize: 11),
        bodySmall:  TextStyle(color: textMuted,   fontSize: 10),
        labelSmall: TextStyle(color: textMuted,   fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgCard,
        contentTextStyle: const TextStyle(color: textPrimary, fontSize: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rSm),
          side: const BorderSide(color: border),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
      ),
    );
  }
}
