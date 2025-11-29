import 'premium_service.dart';

/// Premium pricing configuration
class PremiumPricing {
  /// Pricing for each tier (in USD - will be converted to base currency)
  static const Map<PremiumTier, double> pricing = {
    PremiumTier.monthly: 4.99,
    PremiumTier.quarterly: 12.99, // ~3 months, saves ~$2.98
    PremiumTier.yearly: 39.99, // ~12 months, saves ~$19.89
    PremiumTier.lifetime: 99.99, // One-time payment
  };

  /// Get price for a tier
  static double getPrice(PremiumTier tier) {
    return pricing[tier] ?? 0.0;
  }

  /// Get savings percentage for a tier compared to monthly
  static double getSavings(PremiumTier tier) {
    if (tier == PremiumTier.monthly) return 0.0;

    final monthlyPrice = pricing[PremiumTier.monthly]!;
    final tierPrice = pricing[tier]!;

    switch (tier) {
      case PremiumTier.quarterly:
        // 3 months at monthly rate vs quarterly rate
        final monthlyTotal = monthlyPrice * 3;
        return ((monthlyTotal - tierPrice) / monthlyTotal) * 100;
      case PremiumTier.yearly:
        // 12 months at monthly rate vs yearly rate
        final monthlyTotal = monthlyPrice * 12;
        return ((monthlyTotal - tierPrice) / monthlyTotal) * 100;
      case PremiumTier.lifetime:
        // Assume lifetime = 2 years of monthly
        final monthlyTotal = monthlyPrice * 24;
        return ((monthlyTotal - tierPrice) / monthlyTotal) * 100;
      default:
        return 0.0;
    }
  }

  /// Get display price with currency symbol
  static String getDisplayPrice(PremiumTier tier, String currencySymbol) {
    final price = getPrice(tier);
    return '$currencySymbol${price.toStringAsFixed(2)}';
  }
}
