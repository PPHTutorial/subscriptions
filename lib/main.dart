import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/ads/ad_service.dart';
import 'core/ads/ad_navigation_helper.dart';
import 'core/ads/app_open_ad_service.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/responsive/responsive_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/onboarding/data/onboarding_repository.dart';
import 'features/onboarding/presentation/onboarding_screen.dart';
import 'features/subscriptions/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase if configured
  if (AppConfig.isFirebaseConfigured && AppConfig.enableCloudSync) {
    try {
      await AppConfig.initializeFirebase();
      print('Firebase initialized successfully - Cloud Sync enabled');
    } catch (e) {
      // Firebase initialization failed - app will work in offline mode
      // Log error but don't crash the app
      print('Firebase initialization failed: $e');
      print(
          'App will continue in offline mode. Cloud Sync will be unavailable.');
    }
  } else {
    print(
        'Firebase not configured or Cloud Sync disabled - running in offline mode');
  }

  final notificationService = LocalNotificationService();
  await notificationService.initialize();

  // Initialize ads
  await AdService.initialize();
  // Preload ads for better performance
  AdNavigationHelper.preloadAds();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const SubscriptionsApp(),
    ),
  );
}

class SubscriptionsApp extends ConsumerStatefulWidget {
  const SubscriptionsApp({super.key});

  @override
  ConsumerState<SubscriptionsApp> createState() => _SubscriptionsAppState();
}

class _SubscriptionsAppState extends ConsumerState<SubscriptionsApp>
    with WidgetsBindingObserver {
  final _onboardingRepository = OnboardingRepository();
  final _appOpenAdService = AppOpenAdService();
  bool _isLoading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboardingStatus();
    _loadAppOpenAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appOpenAdService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appOpenAdService.show();
    }
  }

  Future<void> _loadAppOpenAd() async {
    await _appOpenAdService.loadAd();
  }

  Future<void> _checkOnboardingStatus() async {
    final isCompleted = await _onboardingRepository.isOnboardingCompleted();
    setState(() {
      _showOnboarding = !isCompleted;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: AppTheme.build(themeState, context).colorScheme.primary,
            ),
          ),
        ),
      );
    }

    return ScreenUtilInit(
      designSize: const Size(
        ResponsiveHelper.designWidth,
        ResponsiveHelper.designHeight,
      ),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // Build theme to get system UI overlay style
        final theme = AppTheme.build(themeState, context);
        final darkTheme = AppTheme.build(themeState, context);

        return MaterialApp(
          title: 'Subscriptions',
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: darkTheme,
          themeMode: themeState.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: _showOnboarding ? const OnboardingScreen() : const HomeShell(),
          routes: {
            '/home': (context) => const HomeShell(),
          },
          builder: (context, widget) {
            final mediaQuery = MediaQuery.of(context);
            final isDark = themeState.brightness == Brightness.dark;

            // Wrap with AnnotatedRegion to apply system UI overlay style
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                // Status bar
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    isDark ? Brightness.dark : Brightness.light,
                // Navigation bar (Android)
                systemNavigationBarColor:
                    isDark ? const Color(0xFF1E293B) : Colors.white,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  textScaleFactor: ResponsiveHelper.textScaleFactor(context),
                  // Ensure safe area is properly considered
                  padding: mediaQuery.padding,
                  viewInsets: mediaQuery.viewInsets,
                ),
                child: widget!,
              ),
            );
          },
        );
      },
    );
  }
}
