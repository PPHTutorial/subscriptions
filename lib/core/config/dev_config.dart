import 'package:flutter/foundation.dart';

/// Development configuration for testing
///
/// Set `enableDevMode` to true to bypass all restrictions and ads for testing
class DevConfig {
  /// Enable dev mode to bypass restrictions and ads
  /// Only works in debug mode
  static const bool enableDevMode = true; // Set to true for testing

  /// Check if dev mode is enabled
  /// Only returns true if both enableDevMode is true AND app is in debug mode
  static bool get isDevModeEnabled => kDebugMode && enableDevMode;

  /// Check if ads should be shown
  /// Returns false if dev mode is enabled
  static bool get shouldShowAds => !isDevModeEnabled;

  /// Check if restrictions should be applied
  /// Returns false if dev mode is enabled
  static bool get shouldApplyRestrictions => !isDevModeEnabled;
}
