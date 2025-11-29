import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium subscription tiers
enum PremiumTier {
  monthly('monthly', 'Monthly'),
  quarterly('quarterly', 'Quarterly'),
  yearly('yearly', 'Yearly'),
  lifetime('lifetime', 'Lifetime');

  const PremiumTier(this.id, this.displayName);
  final String id;
  final String displayName;
}

/// Premium service for managing subscriptions and restrictions
class PremiumService {
  static const String _premiumStatusKey = 'premium_status';
  static const String _premiumTierKey = 'premium_tier';
  static const String _premiumExpiryKey = 'premium_expiry';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Product IDs - concise but unique
  static const Map<PremiumTier, String> productIds = {
    PremiumTier.monthly: 'premium_monthly',
    PremiumTier.quarterly: 'premium_quarterly',
    PremiumTier.yearly: 'premium_yearly',
    PremiumTier.lifetime: 'premium_lifetime',
  };

  /// Check if user has premium access
  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool(_premiumStatusKey) ?? false;

    if (!isPremium) return false;

    // Check if lifetime (no expiry)
    final tier = prefs.getString(_premiumTierKey);
    if (tier == PremiumTier.lifetime.id) return true;

    // Check expiry for subscription tiers
    final expiryStr = prefs.getString(_premiumExpiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isAfter(expiry)) {
        // Expired, remove premium status
        await prefs.setBool(_premiumStatusKey, false);
        return false;
      }
    }

    return true;
  }

  /// Get current premium tier
  Future<PremiumTier?> getPremiumTier() async {
    final prefs = await SharedPreferences.getInstance();
    final tierStr = prefs.getString(_premiumTierKey);
    if (tierStr == null) return null;

    return PremiumTier.values.firstWhere(
      (tier) => tier.id == tierStr,
      orElse: () => PremiumTier.monthly,
    );
  }

  /// Set premium status (for testing or after purchase)
  Future<void> setPremium({
    required PremiumTier tier,
    DateTime? expiry,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumStatusKey, true);
    await prefs.setString(_premiumTierKey, tier.id);

    if (expiry != null) {
      await prefs.setString(_premiumExpiryKey, expiry.toIso8601String());
    } else if (tier == PremiumTier.lifetime) {
      // Lifetime has no expiry
      await prefs.remove(_premiumExpiryKey);
    }
  }

  /// Remove premium status
  Future<void> removePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumStatusKey, false);
    await prefs.remove(_premiumTierKey);
    await prefs.remove(_premiumExpiryKey);
  }

  /// Purchase a premium tier
  Future<bool> purchasePremium(PremiumTier tier) async {
    try {
      final productId = productIds[tier];
      if (productId == null) return false;

      final available = await _inAppPurchase.queryProductDetails({productId});

      if (available.productDetails.isEmpty) return false;

      final product = available.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);

      final result =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }
}
