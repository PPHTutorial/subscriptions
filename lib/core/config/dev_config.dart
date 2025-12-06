import 'package:flutter/foundation.dart';

class DevConfig {
  static const bool enableDevMode = true; // Set to true for testing

  static bool get _effectiveDevMode => kDebugMode ? enableDevMode : false;

  static bool get isDevModeEnabled => _effectiveDevMode;

  static bool get shouldShowAds {
    // In release builds, always show ads (dev mode is disabled)
    if (kReleaseMode) return true;
    // In debug builds, check if dev mode is enabled
    return !isDevModeEnabled;
  }

  static bool get shouldApplyRestrictions {
    if (kReleaseMode) return true;
    return !isDevModeEnabled;
  }
}
