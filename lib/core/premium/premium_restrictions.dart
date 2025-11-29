import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/dev_config.dart';
import 'premium_provider.dart';

/// Restrictions for free users
class PremiumRestrictions {
  /// Maximum subscriptions for free users
  static const int maxFreeSubscriptions = 10;

  /// Maximum reminders for free users
  static const int maxFreeReminders = 3;

  /// Check if a feature is restricted
  static Future<bool> isRestricted(
    WidgetRef ref,
    RestrictionType type,
  ) async {
    // Bypass restrictions in dev mode
    if (DevConfig.isDevModeEnabled) return false;

    final premiumStatus = await ref.read(premiumStatusProvider.future);
    if (premiumStatus) return false; // Premium users have no restrictions

    switch (type) {
      case RestrictionType.subscriptionLimit:
      case RestrictionType.advancedFeatures:
      case RestrictionType.cloudSync:
      case RestrictionType.exportData:
      case RestrictionType.customCategories:
        return true; // Restricted for free users
      case RestrictionType.none:
        return false;
    }
  }

  /// Check if user can add more subscriptions
  static Future<bool> canAddSubscription(
    WidgetRef ref,
    int currentCount,
  ) async {
    if (DevConfig.isDevModeEnabled) return true;

    final premiumStatus = await ref.read(premiumStatusProvider.future);
    if (premiumStatus) return true;

    return currentCount < maxFreeSubscriptions;
  }

  /// Get remaining subscription slots for free users
  static Future<int> getRemainingSlots(
    WidgetRef ref,
    int currentCount,
  ) async {
    if (DevConfig.isDevModeEnabled) return 999;

    final premiumStatus = await ref.read(premiumStatusProvider.future);
    if (premiumStatus) return 999;

    return (maxFreeSubscriptions - currentCount).clamp(0, maxFreeSubscriptions);
  }
}

enum RestrictionType {
  none,
  subscriptionLimit,
  advancedFeatures,
  cloudSync,
  exportData,
  customCategories,
}
