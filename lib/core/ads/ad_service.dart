import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Service for managing all AdMob ad types
class AdService {
  static bool _initialized = false;

  // Test ad unit IDs - Replace with your actual ad unit IDs from AdMob Console
  static const String _bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // Test Banner ID
  static const String _interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712'; // Test Interstitial ID
  static const String _rewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917'; // Test Rewarded ID
  static const String _rewardedInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/5354046379'; // Test Rewarded Interstitial ID
  static const String _nativeAdUnitId =
      'ca-app-pub-3940256099942544/2247696110'; // Test Native ID
  static const String _appOpenAdUnitId =
      'ca-app-pub-3940256099942544/3419835294'; // Test App Open ID

  static Future<void> initialize() async {
    if (_initialized) return;

    await MobileAds.instance.initialize();
    _initialized = true;
  }

  // Getters for ad unit IDs
  static String get bannerAdUnitId => _bannerAdUnitId;
  static String get interstitialAdUnitId => _interstitialAdUnitId;
  static String get rewardedAdUnitId => _rewardedAdUnitId;
  static String get rewardedInterstitialAdUnitId =>
      _rewardedInterstitialAdUnitId;
  static String get nativeAdUnitId => _nativeAdUnitId;
  static String get appOpenAdUnitId => _appOpenAdUnitId;
}
