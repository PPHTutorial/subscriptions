import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// Service for managing Rewarded Interstitial Ads
class RewardedInterstitialAdService {
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isLoading = false;

  /// Load a rewarded interstitial ad
  Future<void> loadAd() async {
    if (_isLoading || _rewardedInterstitialAd != null) return;

    _isLoading = true;
    await RewardedInterstitialAd.load(
      adUnitId: AdService.rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _isLoading = false;
          _setFullScreenContentCallback();
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _rewardedInterstitialAd = null;
        },
      ),
    );
  }

  void _setFullScreenContentCallback() {
    _rewardedInterstitialAd?.fullScreenContentCallback =
        FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        // Hide status bar when ad is shown
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
      },
      onAdDismissedFullScreenContent: (ad) {
        // Restore status bar when ad is dismissed
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
        ad.dispose();
        _rewardedInterstitialAd = null;
        // Optionally reload for next time
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        // Restore status bar if ad fails to show
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: SystemUiOverlay.values,
        );
        ad.dispose();
        _rewardedInterstitialAd = null;
      },
    );
  }

  /// Show the rewarded interstitial ad
  /// Returns true if ad was shown, false otherwise
  Future<bool> show({
    required Function(RewardItem) onUserEarnedReward,
  }) async {
    if (_rewardedInterstitialAd != null) {
      // Hide status bar before showing ad
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      await _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          onUserEarnedReward(reward);
        },
      );
      return true;
    } else {
      // Try to load if not loaded
      await loadAd();
      return false;
    }
  }

  /// Dispose the ad
  void dispose() {
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
  }

  /// Check if ad is loaded
  bool get isLoaded => _rewardedInterstitialAd != null;
}
