import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:subscriptions/core/ads/ad_service.dart';
import 'package:subscriptions/core/config/dev_config.dart';
import 'package:subscriptions/core/premium/premium_provider.dart';
import 'package:subscriptions/core/responsive/responsive_helper.dart';

/// Native ad widget that automatically hides for premium users
/// Uses default AdMob settings with no custom modifications
class NativeAdWidget extends ConsumerStatefulWidget {
  const NativeAdWidget({
    super.key,
  });

  @override
  ConsumerState<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends ConsumerState<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      _hasLoaded = true;
      _checkAndLoadAd();
    }
  }

  Future<void> _checkAndLoadAd() async {
    // Don't load ads in dev mode or for premium users
    if (!DevConfig.shouldShowAds) return;

    final isPremium = await ref.read(premiumStatusProvider.future);
    if (isPremium) return;

    _loadNativeAd();
  }

  void _loadNativeAd() {
    // Use default AdMob template style - required for native ads to render
    // Using default template without any custom colors or styling modifications
    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('Native ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
              _nativeAd = null;
            });
          }
        },
        onAdOpened: (_) {
          print('Native ad opened');
        },
        onAdClosed: (_) {
          print('Native ad closed');
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        // No custom colors or styling - using AdMob defaults
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch premium status
    final premiumStatus = ref.watch(premiumStatusProvider);

    // Don't show if premium or dev mode
    if (!DevConfig.shouldShowAds ||
        (premiumStatus.hasValue && premiumStatus.value == true)) {
      return const SizedBox.shrink();
    }

    if (!_isAdLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // Use default AdMob settings - no custom containers, labels, margins, padding, or decorations
    return SizedBox(
      width: ResponsiveHelper.screenWidth(context),
      height: ResponsiveHelper.screenHeight(context) * 0.45,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
