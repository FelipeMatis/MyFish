import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF071A1D);
  static const card = Color(0xFF10282B);
  static const cardSoft = Color(0xFF173538);
  static const accent = Color(0xFF35C6A0);
  static const accent2 = Color(0xFF168A82);
  static const textPrimary = Color(0xFFE9F5F2);
  static const textSecondary = Color(0xFFA8C1BC);

  static final dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    useMaterial3: true,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: accent2,
      surface: card,
      onSurface: textPrimary,
      onPrimary: bg,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
    ),
    cardTheme: CardThemeData(
      color: cardSoft,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardSoft,
      hintStyle: const TextStyle(color: textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: accent.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.selected) ? accent : textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
