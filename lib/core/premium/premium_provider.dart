import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'premium_service.dart';

/// Provider for premium service
final premiumServiceProvider = Provider<PremiumService>((ref) {
  return PremiumService();
});

/// Provider for premium status
final premiumStatusProvider = StreamProvider<bool>((ref) async* {
  final service = ref.read(premiumServiceProvider);

  // Initial check
  yield await service.isPremium();

  // Periodically check (every 30 seconds)
  while (true) {
    await Future.delayed(const Duration(seconds: 30));
    yield await service.isPremium();
  }
});

/// Provider for premium tier
final premiumTierProvider = FutureProvider<PremiumTier?>((ref) async {
  final service = ref.read(premiumServiceProvider);
  return await service.getPremiumTier();
});
