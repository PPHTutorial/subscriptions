import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ad_service.dart';

/// Service for managing App Open Ads
class AppOpenAdService {
  AppOpenAd? _appOpenAd;
  bool _isLoading = false;
  bool _isShowingAd = false;

  /// Load an app open ad
  Future<void> loadAd() async {
    if (_isLoading || _appOpenAd != null) return;

    _isLoading = true;
    await AppOpenAd.load(
      adUnitId: AdService.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isLoading = false;
          _setFullScreenContentCallback();
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  void _setFullScreenContentCallback() {
    _appOpenAd?.fullScreenContentCallback = FullScreenContentCallback(
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
        _appOpenAd = null;
        _isShowingAd = false;
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
        _appOpenAd = null;
        _isShowingAd = false;
      },
    );
  }

  /// Show the app open ad
  Future<void> show() async {
    if (_appOpenAd != null && !_isShowingAd) {
      _isShowingAd = true;
      // Hide status bar before showing ad
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
      await _appOpenAd!.show();
    } else if (!_isLoading) {
      // Try to load if not loaded
      await loadAd();
    }
  }

  /// Dispose the ad
  void dispose() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _isShowingAd = false;
  }

  /// Check if ad is loaded
  bool get isLoaded => _appOpenAd != null;

  /// Check if ad is currently showing
  bool get isShowing => _isShowingAd;
}
