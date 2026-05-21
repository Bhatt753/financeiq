import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const bg        = Color(0xFF0F172A);
  static const surface   = Color(0xFF1E293B);
  static const surface2  = Color(0xFF0F172A);
  static const card      = Color(0xFF1E293B);

  // Accents
  static const green     = Color(0xFF4ADE80);
  static const greenDark = Color(0xFF16A34A);
  static const red       = Color(0xFFEF4444);
  static const amber     = Color(0xFFF59E0B);
  static const indigo    = Color(0xFF6366F1);
  static const cyan      = Color(0xFF06B6D4);

  // Text
  static const text      = Color(0xFFF1F5F9);
  static const textSub   = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF475569);

  // Borders
  static const border    = Color(0xFF334155);
  static const divider   = Color(0xFF1E293B);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      background: AppColors.bg,
      surface: AppColors.surface,
      primary: AppColors.green,
      secondary: AppColors.indigo,
      error: AppColors.red,
      onBackground: AppColors.text,
      onSurface: AppColors.text,
      onPrimary: Color(0xFF0F172A),
    ),
    cardTheme: CardTheme(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: AppColors.text),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.green,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.green, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textSub),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: const Color(0xFF0F172A),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        elevation: 0,
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 28),
      headlineMedium: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 22),
      titleLarge: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 15),
      bodyLarge: TextStyle(color: AppColors.text, fontSize: 15),
      bodyMedium: TextStyle(color: AppColors.textSub, fontSize: 13),
      labelSmall: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}
