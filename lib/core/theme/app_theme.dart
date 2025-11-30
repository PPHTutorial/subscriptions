import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../responsive/responsive_helper.dart';
import 'theme_provider.dart';

class AppTheme {
  static ColorScheme _getColorScheme(
      AppColorScheme scheme, Brightness brightness) {
    switch (scheme) {
      case AppColorScheme.purple:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF6247EA), // Primary Purple
          brightness: brightness,
          primary: const Color(0xFF6247EA),
          secondary: brightness == Brightness.dark
              ? const Color(0xFF7E57C2) // Deep Amethyst for dark
              : const Color(0xFFCE93D8), // Soft Lavender for light
        );
      case AppColorScheme.blue:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF3AA9FF),
          brightness: brightness,
          primary: const Color(0xFF3AA9FF),
          secondary: const Color(0xFF25D9B5),
        );
      case AppColorScheme.green:
        return ColorScheme.fromSeed(
          seedColor: const Color(0xFF209B26),
          brightness: brightness,
          primary: const Color(0xFF0DA014),
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
    }
  }

  static ThemeData build(ThemeState themeState, BuildContext context) {
    final colorScheme =
        _getColorScheme(themeState.colorScheme, themeState.brightness);

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
      // Use surfaceVariant for scaffold background to adapt to color scheme
      scaffoldBackgroundColor: colorScheme.surfaceVariant,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: colorScheme.brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: colorScheme.brightness == Brightness.dark
              ? Brightness.dark
              : Brightness.light,
          systemNavigationBarColor: colorScheme.surface,
          systemNavigationBarIconBrightness:
              colorScheme.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Use surface for input field backgrounds to adapt to color scheme
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(16)),
          borderSide: BorderSide(
            color: colorScheme.outline,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(16)),
          borderSide: BorderSide(
            color: colorScheme.outline,
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
          color: colorScheme.onSurface.withOpacity(0.4),
        ),
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.7),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
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
        checkmarkColor: colorScheme.onPrimary,
        // Use surfaceVariant for chip backgrounds - generated from seed color
        backgroundColor: colorScheme.surfaceVariant.withOpacity(0.5),
        deleteIconColor: colorScheme.onSurfaceVariant,
        disabledColor: colorScheme.surfaceVariant.withOpacity(0.3),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onPrimary,
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
        // Use surface for card backgrounds - generated from seed color
        color: colorScheme.surface,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.all(ResponsiveHelper.spacing(8)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(24)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      dividerTheme: DividerThemeData(
        // Use outline for dividers - generated from seed color
        color: colorScheme.outline,
        thickness: 1,
        space: 1,
      ),
      dividerColor: colorScheme.outline,
    );
  }
}
