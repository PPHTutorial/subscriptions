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
  static double fontSize(double size) => size.sp;

  // Responsive spacing
  static double spacing(double size) => size.w;

  // Responsive height
  static double height(double size) => size.h;

  // Responsive width
  static double width(double size) => size.w;

  // Screen width
  static double screenWidth() => 1.sw;

  // Screen height
  static double screenHeight() => 1.sh;

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
