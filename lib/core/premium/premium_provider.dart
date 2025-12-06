import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'premium_service.dart';

/// Provider for premium service
final premiumServiceProvider = Provider<PremiumService>((ref) {
  return PremiumService();
});

/// Provider for premium status
/// Validates subscription status periodically to prevent overuse
final premiumStatusProvider = StreamProvider<bool>((ref) async* {
  final service = ref.read(premiumServiceProvider);

  // Ensure service is initialized
  await service.initialize();

  // Initial check with validation
  yield await service.isPremium();

  // Periodically check subscription status
  // Check every 5 minutes to catch expired subscriptions
  while (true) {
    await Future.delayed(const Duration(minutes: 5));

    // Validate with store every hour, otherwise just check local expiry
    final isPremium = await service.isPremium();
    yield isPremium;

    // If premium expired, ensure restrictions are enforced immediately
    if (!isPremium) {
      // Force a refresh to ensure UI updates
      ref.invalidateSelf();
    }
  }
});

/// Provider for premium tier
final premiumTierProvider = FutureProvider<PremiumTier?>((ref) async {
  final service = ref.read(premiumServiceProvider);
  return await service.getPremiumTier();
});
