import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF0B8F6A);
  static const primaryDark = Color(0xFF075E54);
  static const debt = Color(0xFFE5484D);
  static const paid = Color(0xFF12A150);
  static const advance = Color(0xFF2F80ED);

  // Fond et bulles du "chat", inspirés de WhatsApp
  static const chatBgLight = Color(0xFFEFEAE2);
  static const chatBgDark = Color(0xFF0B141A);
  static const purchaseBubbleLight = Color(0xFFFFFFFF);
  static const purchaseBubbleDark = Color(0xFF202C33);
  static const paymentBubbleLight = Color(0xFFD9FDD3);
  static const paymentBubbleDark = Color(0xFF005C4B);
  static const dateChipLight = Color(0xFFE1F3FB);
  static const dateChipDark = Color(0xFF182229);
}

class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF111B21) : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF1F2C34) : AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
