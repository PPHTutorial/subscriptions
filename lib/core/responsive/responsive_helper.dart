import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ResponsiveHelper {
  // Design dimensions (base design size)
  static const double designWidth = 375.0;
  static const double designHeight = 812.0;

  static void init(BuildContext context) {
    ScreenUtil.init(
      context,
      designSize: Size(designWidth, designHeight),
      minTextAdapt: true,
      splitScreenMode: true,
    );
  }

  // Responsive font sizes
  // Uses ScreenUtil if initialized, otherwise returns the size as-is
  static double fontSize(double size) {
    try {
      return size.sp;
    } catch (e) {
      // If ScreenUtil not initialized, return size as-is
      return size;
    }
  }

  // Responsive spacing
  // Uses ScreenUtil if initialized, otherwise returns the size as-is
  static double spacing(double size) {
    try {
      return size.w;
    } catch (e) {
      // If ScreenUtil not initialized, return size as-is
      return size;
    }
  }

  // Responsive height
  // Uses ScreenUtil if initialized, otherwise returns the size as-is
  static double height(double size) {
    try {
      return size.h;
    } catch (e) {
      // If ScreenUtil not initialized, return size as-is
      return size;
    }
  }

  // Responsive width
  // Uses ScreenUtil if initialized, otherwise returns the size as-is
  static double width(double size) {
    try {
      return size.w;
    } catch (e) {
      // If ScreenUtil not initialized, return size as-is
      return size;
    }
  }

  // Screen width (safe area aware)
  // Uses MediaQuery to get actual screen width considering safe area
  static double screenWidth(BuildContext? context) {
    if (context != null) {
      final mediaQuery = MediaQuery.of(context);
      // Return the actual screen width from MediaQuery
      return mediaQuery.size.width;
    }

    try {
      return 1.sw;
    } catch (e) {
      // If ScreenUtil not initialized, return default design width
      return designWidth;
    }
  }

  // Screen height (safe area aware)
  // Uses MediaQuery to get actual screen height considering safe area
  static double screenHeight(BuildContext? context) {
    if (context != null) {
      final mediaQuery = MediaQuery.of(context);
      // Return the actual screen height from MediaQuery
      return mediaQuery.size.height;
    }

    try {
      return 1.sh;
    } catch (e) {
      // If ScreenUtil not initialized, return default design height
      return designHeight;
    }
  }

  // Safe area top padding (status bar, notch, etc.)
  static double safeAreaTop(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding.top;
  }

  // Safe area bottom padding (home indicator, navigation bar, etc.)
  static double safeAreaBottom(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding.bottom;
  }

  // Safe area left padding
  static double safeAreaLeft(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding.left;
  }

  // Safe area right padding
  static double safeAreaRight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding.right;
  }

  // Available height (screen height minus safe area insets)
  static double availableHeight(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom;
  }

  // Available width (screen width minus safe area insets)
  static double availableWidth(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.size.width -
        mediaQuery.padding.left -
        mediaQuery.padding.right;
  }

  // Get all safe area insets
  static EdgeInsets safeAreaInsets(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return mediaQuery.padding;
  }

  // Check if device is tablet
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 600;
  }

  // Check if device is phone
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  // Get responsive text scale factor
  static double textScaleFactor(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final textScaleFactor = mediaQuery.textScaleFactor;
    // Clamp between 0.8 and 1.2 for better control
    return textScaleFactor.clamp(0.8, 1.2);
  }
}

// Extension for easy responsive text
extension ResponsiveText on TextStyle {
  TextStyle responsive(BuildContext context) {
    final scaleFactor = ResponsiveHelper.textScaleFactor(context);
    return copyWith(
      fontSize: (fontSize ?? 14) * scaleFactor,
      height: height != null ? height! * scaleFactor : null,
    );
  }
}
