import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// Service for managing Rewarded Ads
class RewardedAdService {
  RewardedAd? _rewardedAd;
  bool _isLoading = false;

  /// Load a rewarded ad
  Future<void> loadAd() async {
    if (_isLoading || _rewardedAd != null) return;

    _isLoading = true;
    await RewardedAd.load(
      adUnitId: AdService.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoading = false;
          _setFullScreenContentCallback();
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  void _setFullScreenContentCallback() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
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
        _rewardedAd = null;
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
        _rewardedAd = null;
      },
    );
  }

  /// Show the rewarded ad
  /// Returns true if ad was shown, false otherwise
  Future<bool> show({
    required Function(RewardItem) onUserEarnedReward,
  }) async {
    if (_rewardedAd != null) {
      // Hide status bar before showing ad
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      await _rewardedAd!.show(
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
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }

  /// Check if ad is loaded
  bool get isLoaded => _rewardedAd != null;
}
