import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'interstitial_ad_service.dart';
import 'rewarded_ad_service.dart';
import 'rewarded_interstitial_ad_service.dart';
import 'app_open_ad_service.dart';

/// Helper class for managing ads during navigation and user actions
class AdNavigationHelper {
  static final InterstitialAdService _interstitialService =
      InterstitialAdService();
  static final RewardedAdService _rewardedService = RewardedAdService();
  static final RewardedInterstitialAdService _rewardedInterstitialService =
      RewardedInterstitialAdService();
  static final AppOpenAdService _appOpenAdService = AppOpenAdService();

  /// Preload ads on app start
  static Future<void> preloadAds() async {
    await Future.wait([
      _interstitialService.loadAd(),
      _rewardedService.loadAd(),
      _rewardedInterstitialService.loadAd(),
      _appOpenAdService.loadAd(),
    ]);
  }

  /// Show interstitial ad before navigation, then execute callback
  static Future<void> showInterstitialBeforeNavigation(
    BuildContext context,
    VoidCallback onComplete,
  ) async {
    if (_interstitialService.isLoaded) {
      await _interstitialService.show();
      // Reload for next time
      _interstitialService.loadAd();
    }
    if (context.mounted) {
      onComplete();
    }
  }

  /// Show rewarded ad with callback for reward
  static Future<void> showRewardedAd({
    required BuildContext context,
    required Function(RewardItem) onRewardEarned,
    VoidCallback? onAdDismissed,
  }) async {
    final shown = await _rewardedService.show(
      onUserEarnedReward: (reward) {
        onRewardEarned(reward);
        // Reload for next time
        _rewardedService.loadAd();
      },
    );
    if (!shown && context.mounted) {
      // If ad not shown, try to load and show rewarded interstitial as fallback
      await _rewardedInterstitialService.show(
        onUserEarnedReward: (reward) {
          onRewardEarned(reward);
          _rewardedInterstitialService.loadAd();
        },
      );
    }
    if (context.mounted && onAdDismissed != null) {
      onAdDismissed();
    }
  }

  /// Show rewarded interstitial ad
  static Future<void> showRewardedInterstitialAd({
    required BuildContext context,
    required Function(RewardItem) onRewardEarned,
  }) async {
    await _rewardedInterstitialService.show(
      onUserEarnedReward: (reward) {
        onRewardEarned(reward);
        _rewardedInterstitialService.loadAd();
      },
    );
  }

  /// Show app open ad (typically called on app resume)
  static Future<void> showAppOpenAd() async {
    await _appOpenAdService.show();
  }

  /// Navigate with interstitial ad
  static Future<void> navigateWithInterstitial(
    BuildContext context,
    Widget destination,
  ) async {
    await showInterstitialBeforeNavigation(
      context,
      () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => destination),
        );
      },
    );
  }

  /// Push replacement with interstitial ad
  static Future<void> pushReplacementWithInterstitial(
    BuildContext context,
    Widget destination,
  ) async {
    await showInterstitialBeforeNavigation(
      context,
      () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => destination),
        );
      },
    );
  }

  /// Show modal bottom sheet with interstitial ad
  static Future<void> showModalBottomSheetWithInterstitial(
    BuildContext context,
    Widget Function(BuildContext) builder,
  ) async {
    await showInterstitialBeforeNavigation(
      context,
      () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: builder,
        );
      },
    );
  }

  /// Dispose all ad services
  static void dispose() {
    _interstitialService.dispose();
    _rewardedService.dispose();
    _rewardedInterstitialService.dispose();
    _appOpenAdService.dispose();
  }
}
