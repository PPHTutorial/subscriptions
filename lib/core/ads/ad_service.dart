import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service for managing all AdMob ad types
class AdService {
  static bool _initialized = false;

  // Test ad unit IDs (used in debug mode)
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/5354046379';
  static const String _testNativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _testAppOpenAdUnitId =
      'ca-app-pub-3940256099942544/3419835294';

  // Production ad unit IDs (used in release mode)
  static const String _productionBannerAdUnitId =
      'ca-app-pub-9043208558525567/4244138978'; // subswatcher_banner
  static const String _productionInterstitialAdUnitId =
      'ca-app-pub-9043208558525567/2931057302'; // subswatcher_interstitial
  static const String _productionRewardedAdUnitId =
      'ca-app-pub-9043208558525567/5741161273'; // subswatcher_rewarded
  static const String _productionRewardedInterstitialAdUnitId =
      'ca-app-pub-9043208558525567/6260036028'; // subswatcher_rewarded_interstitial
  static const String _productionNativeAdUnitId =
      'ca-app-pub-9043208558525567/1733525700'; // subswatcher_native
  static const String _productionAppOpenAdUnitId =
      'ca-app-pub-9043208558525567/2209002573'; // subswatcher_app_open

  // App ID: ca-app-pub-9043208558525567~1478374833

  static Future<void> initialize() async {
    if (_initialized) return;

    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // Getters for ad unit IDs - returns test IDs in debug, production IDs in release
  static String get bannerAdUnitId =>
      kDebugMode ? _testBannerAdUnitId : _productionBannerAdUnitId;
  static String get interstitialAdUnitId =>
      kDebugMode ? _testInterstitialAdUnitId : _productionInterstitialAdUnitId;
  static String get rewardedAdUnitId =>
      kDebugMode ? _testRewardedAdUnitId : _productionRewardedAdUnitId;
  static String get rewardedInterstitialAdUnitId => kDebugMode
      ? _testRewardedInterstitialAdUnitId
      : _productionRewardedInterstitialAdUnitId;
  static String get nativeAdUnitId =>
      kDebugMode ? _testNativeAdUnitId : _productionNativeAdUnitId;
  static String get appOpenAdUnitId =>
      kDebugMode ? _testAppOpenAdUnitId : _productionAppOpenAdUnitId;
}
