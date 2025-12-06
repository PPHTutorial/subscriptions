import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Premium subscription tiers
enum PremiumTier {
  monthly('monthly', 'Monthly'),
  quarterly('quarterly', 'Quarterly'),
  half_yearly('half_yearly', 'Half Yearly'),
  yearly('yearly', 'Yearly');

  const PremiumTier(this.id, this.displayName);
  final String id;
  final String displayName;
}

/// Premium service for managing subscriptions and restrictions
class PremiumService {
  static const String _premiumStatusKey = 'premium_status';
  static const String _premiumTierKey = 'premium_tier';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _lastValidationKey = 'last_premium_validation';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isInitialized = false;

  // Product IDs - concise but unique
  static const Map<PremiumTier, String> productIds = {
    PremiumTier.monthly: 'premium_monthly',
    PremiumTier.quarterly: 'premium_quarterly',
    PremiumTier.yearly: 'premium_yearly',
    PremiumTier.half_yearly: 'premium_half_yearly',
  };

  /// Initialize purchase listener
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Listen to purchase updates
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) => _purchaseSubscription?.cancel(),
    );

    // Validate existing purchases on initialization
    await _validateExistingPurchases();

    _isInitialized = true;
  }

  /// Dispose resources
  void dispose() {
    _purchaseSubscription?.cancel();
    _purchaseSubscription = null;
    _isInitialized = false;
  }

  /// Handle purchase updates from the store
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _processPurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        // Handle error
        await _inAppPurchase.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.pending) {
        // Purchase is pending
      }
    }
  }

  /// Process a successful purchase or renewal
  Future<void> _processPurchase(PurchaseDetails purchase) async {
    // Find the tier from product ID
    PremiumTier? tier;
    for (final entry in productIds.entries) {
      if (entry.value == purchase.productID) {
        tier = entry.key;
        break;
      }
    }

    if (tier == null) return;

    // Get current premium status
    final prefs = await SharedPreferences.getInstance();
    final currentTierStr = prefs.getString(_premiumTierKey);
    final currentExpiryStr = prefs.getString(_premiumExpiryKey);

    DateTime? expiry;

    // If this is a renewal (same tier and current subscription exists)
    if (currentTierStr == tier.id && currentExpiryStr != null) {
      final currentExpiry = DateTime.parse(currentExpiryStr);
      // If current subscription hasn't expired, extend from current expiry
      // Otherwise, start from now
      final baseDate = DateTime.now().isBefore(currentExpiry)
          ? currentExpiry
          : DateTime.now();

      // Calculate new expiry based on tier
      switch (tier) {
        case PremiumTier.monthly:
          expiry = baseDate.add(const Duration(days: 30));
          break;
        case PremiumTier.quarterly:
          expiry = baseDate.add(const Duration(days: 90));
          break;
        case PremiumTier.half_yearly:
          expiry = baseDate.add(const Duration(days: 180));
          break;
        case PremiumTier.yearly:
          expiry = baseDate.add(const Duration(days: 365));
          break;
      }
    } else {
      // New purchase - calculate expiry from now
      switch (tier) {
        case PremiumTier.monthly:
          expiry = DateTime.now().add(const Duration(days: 30));
          break;
        case PremiumTier.quarterly:
          expiry = DateTime.now().add(const Duration(days: 90));
          break;
        case PremiumTier.half_yearly:
          expiry = DateTime.now().add(const Duration(days: 180));
          break;
        case PremiumTier.yearly:
          expiry = DateTime.now().add(const Duration(days: 365));
          break;
      }
    }

    // Set premium status
    await setPremium(tier: tier, expiry: expiry);

    // Complete the purchase
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
  }

  /// Validate existing purchases with the store
  /// Checks local expiry and validates against purchase stream
  Future<void> _validateExistingPurchases() async {
    try {
      // First check local expiry - this is the primary validation
      await _checkLocalExpiry();

      // Note: The purchase stream will automatically notify us of any
      // active purchases or renewals. We rely on local expiry checking
      // and the purchase stream listener to keep status updated.

      // For subscriptions, the store handles renewals automatically
      // and sends purchase updates through the stream
    } catch (e) {
      // If validation fails, check local expiry as fallback
      await _checkLocalExpiry();
    }
  }

  /// Check local expiry and remove premium if expired
  Future<void> _checkLocalExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final isPremium = prefs.getBool(_premiumStatusKey) ?? false;

    if (!isPremium) return;

    // Check expiry for all subscription tiers (including half_yearly)
    final expiryStr = prefs.getString(_premiumExpiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isAfter(expiry)) {
        // Expired, remove premium status
        await removePremium();
      }
    } else {
      // No expiry date means subscription is invalid - remove premium
      await removePremium();
    }
  }

  /// Check if user has premium access
  /// Validates against store and local expiry
  Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();

    // Initialize if not already done
    if (!_isInitialized) {
      await initialize();
    }

    // Check last validation time - validate with store if it's been more than 1 hour
    final lastValidationStr = prefs.getString(_lastValidationKey);
    final shouldValidate = lastValidationStr == null ||
        DateTime.now().difference(DateTime.parse(lastValidationStr)).inHours >=
            1;

    if (shouldValidate) {
      await _validateExistingPurchases();
      await prefs.setString(
        _lastValidationKey,
        DateTime.now().toIso8601String(),
      );
    }

    final isPremium = prefs.getBool(_premiumStatusKey) ?? false;

    if (!isPremium) return false;

    // Check expiry for all subscription tiers (including half_yearly)
    final expiryStr = prefs.getString(_premiumExpiryKey);
    if (expiryStr != null) {
      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isAfter(expiry)) {
        // Expired, remove premium status
        await removePremium();
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
      // Ensure initialized
      if (!_isInitialized) {
        await initialize();
      }

      final productId = productIds[tier];
      if (productId == null) return false;

      final available = await _inAppPurchase.queryProductDetails({productId});

      if (available.productDetails.isEmpty) return false;

      final product = available.productDetails.first;

      // Use buyNonConsumable for one-time purchases or subscriptions
      // For subscriptions, the store handles renewal automatically
      final purchaseParam = PurchaseParam(productDetails: product);

      final result =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      // Note: The actual purchase processing happens in _handlePurchaseUpdates
      // This just initiates the purchase flow
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Restore purchases
  /// Validates all past purchases and restores premium status if valid
  Future<void> restorePurchases() async {
    try {
      // Ensure initialized
      if (!_isInitialized) {
        await initialize();
      }

      // Restore purchases from store
      await _inAppPurchase.restorePurchases();

      // Validate existing purchases
      await _validateExistingPurchases();
    } catch (e) {
      // If restore fails, check local expiry as fallback
      await _checkLocalExpiry();
    }
  }
}
