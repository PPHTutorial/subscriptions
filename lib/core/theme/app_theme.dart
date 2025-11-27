import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData build() {
    const seed = Color(0xFF6247EA);
    const secondary = Color(0xFF25D9B5);
    const neutral = Color(0xFF0F172A);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      primary: seed,
      secondary: secondary,
      background: const Color(0xFFF5F6FB),
      surface: Colors.white,
      brightness: Brightness.light,
    );

    final textTheme = const TextTheme(
      displaySmall: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 32,
        letterSpacing: -0.5,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 20,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        height: 1.4,
      ),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.35,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      textTheme: textTheme.apply(
        bodyColor: neutral,
        displayColor: neutral,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.background,
        foregroundColor: neutral,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: neutral),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(
          color: neutral.withOpacity(0.4),
        ),
        labelStyle: TextStyle(
          color: neutral.withOpacity(0.7),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        selectedColor: secondary.withOpacity(0.12),
        backgroundColor: Colors.white,
        labelStyle: textTheme.bodyMedium,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
