import 'package:flutter/material.dart';
import '../responsive/responsive_helper.dart';
import 'theme_provider.dart';

class AppTheme {
  static ColorScheme _getColorScheme(
      AppColorScheme scheme, Brightness brightness) {
    switch (scheme) {
      case AppColorScheme.purple:
        if (brightness == Brightness.dark) {
          return ColorScheme(
            brightness: brightness,
            primary: const Color(0xFF6247EA), // Primary Purple
            onPrimary: Colors.white,
            secondary: const Color(0xFF7E57C2), // Deep Amethyst
            onSecondary: Colors.white,
            tertiary: const Color(0xFFE040FB), // Electric Purple / Neon Violet
            onTertiary: Colors.white,
            error: const Color(0xFFB00020),
            onError: Colors.white,
            surface: const Color(0xFF1E293B),
            onSurface: const Color(0xFFE2E8F0),
            surfaceVariant: const Color(0xFF334155),
            onSurfaceVariant: const Color(0xFFCBD5E1),
            outline: const Color(0xFF64748B).withOpacity(0.2),
            shadow: Colors.black,
            inverseSurface: const Color(0xFFE2E8F0),
            onInverseSurface: const Color(0xFF0F172A),
            inversePrimary: const Color(0xFF6247EA),
          );
        } else {
          return ColorScheme(
            brightness: brightness,
            primary: const Color(0xFF6247EA), // Primary Purple
            onPrimary: Colors.white,
            secondary: const Color(0xFFCE93D8), // Soft Lavender
            onSecondary: const Color(0xFF1A1A1A),
            tertiary: const Color(0xFFF06292), // Vibrant Magenta / Pink-Purple
            onTertiary: Colors.white,
            error: const Color(0xFFB00020),
            onError: Colors.white,
            surface: Colors.white,
            onSurface: const Color(0xFF0F172A),
            surfaceVariant: const Color(0xFFF5F6FB),
            onSurfaceVariant: const Color(0xFF475569),
            outline: const Color(0xFFCBD5E1).withOpacity(0.3),
            shadow: Colors.black,
            inverseSurface: const Color(0xFF0F172A),
            onInverseSurface: Colors.white,
            inversePrimary: const Color(0xFF6247EA),
          );
        }
      case AppColorScheme.blue:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF3AA9FF),
          brightness: brightness,
          primary: const Color(0xFF3AA9FF),
          secondary: const Color(0xFF25D9B5),
        );
      case AppColorScheme.green:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF25D9B5),
          brightness: brightness,
          primary: const Color(0xFF25D9B5),
          secondary: const Color(0xFF6247EA),
        );
      case AppColorScheme.pink:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A8A),
          brightness: brightness,
          primary: const Color(0xFFFF7A8A),
          secondary: const Color(0xFFFFB347),
        );
      case AppColorScheme.orange:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB347),
          brightness: brightness,
          primary: const Color(0xFFFFB347),
          secondary: const Color(0xFFFF7A8A),
        );
      case AppColorScheme.teal:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF25D9B5),
          brightness: brightness,
          primary: const Color(0xFF25D9B5),
          secondary: const Color(0xFF3AA9FF),
        );
      case AppColorScheme.yellow:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: brightness,
          primary: const Color(0xFFFFD700),
          secondary: const Color(0xFFFFA500),
        );
      case AppColorScheme.red:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFB00020),
          brightness: brightness,
          primary: const Color(0xFFB00020),
          secondary: const Color(0xFFFF5252),
        );
      case AppColorScheme.gray:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF808080),
          brightness: brightness,
          primary: const Color(0xFF808080),
          secondary: const Color(0xFFA0A0A0),
        );
      case AppColorScheme.brown:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B4513),
          brightness: brightness,
          primary: const Color(0xFF8B4513),
          secondary: const Color(0xFFA0522D),
        );
      case AppColorScheme.black:
        return ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: brightness,
          primary: Colors.black,
          secondary: Colors.grey,
        );
      case AppColorScheme.white:
        return ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: brightness,
          primary: Colors.grey,
          secondary: Colors.black,
        );
      case AppColorScheme.yellow:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFD700),
          brightness: brightness,
          primary: const Color(0xFFFFD700),
          secondary: const Color(0xFFFFA500),
        );
      case AppColorScheme.red:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFFB00020),
          brightness: brightness,
          primary: const Color(0xFFB00020),
          secondary: const Color(0xFFFF5252),
        );
      case AppColorScheme.gray:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF808080),
          brightness: brightness,
          primary: const Color(0xFF808080),
          secondary: const Color(0xFFA0A0A0),
        );
      case AppColorScheme.brown:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B4513),
          brightness: brightness,
          primary: const Color(0xFF8B4513),
          secondary: const Color(0xFFA0522D),
        );
      case AppColorScheme.black:
        return ColorScheme.fromSeed(
          seedColor: Colors.black,
          brightness: brightness,
          primary: Colors.black,
          secondary: Colors.grey,
        );
      case AppColorScheme.white:
        return ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: brightness,
          primary: Colors.grey,
          secondary: Colors.black,
        );
    }
  }

  static ThemeData build(ThemeState themeState, BuildContext context) {
    final colorScheme =
        _getColorScheme(themeState.colorScheme, themeState.brightness);
    final isDark = themeState.brightness == Brightness.dark;
    final neutral = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    // Responsive text sizes using ScreenUtil
    final textTheme = TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: ResponsiveHelper.fontSize(32),
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: ResponsiveHelper.fontSize(28),
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displaySmall: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: ResponsiveHelper.fontSize(24),
        letterSpacing: -0.5,
        height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: ResponsiveHelper.fontSize(22),
        height: 1.3,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: ResponsiveHelper.fontSize(20),
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: ResponsiveHelper.fontSize(18),
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: ResponsiveHelper.fontSize(20),
        height: 1.4,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: ResponsiveHelper.fontSize(16),
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: ResponsiveHelper.fontSize(14),
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontSize: ResponsiveHelper.fontSize(16),
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: ResponsiveHelper.fontSize(14),
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: ResponsiveHelper.fontSize(12),
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: ResponsiveHelper.fontSize(14),
        height: 1.4,
      ),
      labelMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: ResponsiveHelper.fontSize(12),
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: ResponsiveHelper.fontSize(10),
        height: 1.3,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F6FB),
      textTheme: textTheme.apply(
        bodyColor: neutral,
        displayColor: neutral,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F6FB),
        foregroundColor: neutral,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: neutral),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(16)),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF64748B).withOpacity(0.2)
                : const Color(0xFFCBD5E1).withOpacity(0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(16)),
          borderSide: BorderSide(
            color: isDark
                ? const Color(0xFF64748B).withOpacity(0.2)
                : const Color(0xFFCBD5E1).withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(16)),
          borderSide: BorderSide(
            color: colorScheme.primary.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.spacing(18),
          vertical: ResponsiveHelper.spacing(16),
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
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveHelper.spacing(16),
            horizontal: ResponsiveHelper.spacing(20),
          ),
          minimumSize: Size(
            ResponsiveHelper.width(120),
            ResponsiveHelper.height(48),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(18)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(24)),
        ),
        selectedColor: colorScheme.primary,
        selectedShadowColor: Colors.transparent,
        checkmarkColor: Colors.white,
        backgroundColor: isDark
            ? const Color(0xFF334155).withOpacity(0.5)
            : const Color(0xFFF1F5F9),
        deleteIconColor:
            isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
        disabledColor: isDark
            ? const Color(0xFF1E293B).withOpacity(0.3)
            : const Color(0xFFF1F5F9).withOpacity(0.5),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.spacing(12),
          vertical: ResponsiveHelper.spacing(8),
        ),
        elevation: 0,
        pressElevation: 2,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        margin: EdgeInsets.all(ResponsiveHelper.spacing(8)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(24)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: neutral.withOpacity(0.6),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? const Color(0xFF64748B).withOpacity(0.15)
            : const Color(0xFFCBD5E1).withOpacity(0.4),
        thickness: 1,
        space: 1,
      ),
      dividerColor: isDark
          ? const Color(0xFF64748B).withOpacity(0.15)
          : const Color(0xFFCBD5E1).withOpacity(0.4),
    );
  }
}
