import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// Service for managing Interstitial Ads
class InterstitialAdService {
  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  /// Load an interstitial ad
  Future<void> loadAd() async {
    if (_isLoading || _interstitialAd != null) return;

    _isLoading = true;
    await InterstitialAd.load(
      adUnitId: AdService.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
          _setFullScreenContentCallback();
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  void _setFullScreenContentCallback() {
    _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
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
        _interstitialAd = null;
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
        _interstitialAd = null;
      },
    );
  }

  /// Show the interstitial ad
  Future<void> show() async {
    if (_interstitialAd != null) {
      // Hide status bar before showing ad
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      await _interstitialAd!.show();
    } else {
      // Try to load if not loaded
      await loadAd();
    }
  }

  /// Dispose the ad
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  /// Check if ad is loaded
  bool get isLoaded => _interstitialAd != null;
}
