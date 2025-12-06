import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/permissions/permission_service.dart';
import '../../../core/responsive/responsive_helper.dart';
import '../../subscriptions/presentation/home_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final PermissionService _permissionService = PermissionService();
  int _currentPage = 0;
  bool _isRequestingPermissions = false;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to Subscriptions',
      description:
          'Track and manage all your subscriptions in one place. Never miss a renewal or waste money on unused services.',
      icon: Icons.subscriptions_rounded,
      color: const Color(0xFF6247EA),
    ),
    OnboardingPage(
      title: 'Track Everything',
      description:
          'Add subscriptions manually or let the app detect them automatically. Organize by category, set billing cycles, and track renewal dates.',
      icon: Icons.dashboard_rounded,
      color: const Color(0xFF3AA9FF),
    ),
    OnboardingPage(
      title: 'Smart Reminders',
      description:
          'Get notified before your subscriptions renew. Set custom reminders so you\'re always in control and never miss a payment.',
      icon: Icons.notifications_active_rounded,
      color: const Color(0xFF25D9B5),
    ),
    OnboardingPage(
      title: 'Email Scanning',
      description:
          'Connect your email (Gmail, Outlook, Yahoo, iCloud, ProtonMail, or custom) and automatically scan receipts to find subscriptions.',
      icon: Icons.email_rounded,
      color: const Color(0xFFFF6B6B),
    ),
    OnboardingPage(
      title: 'SMS Scanning',
      description:
          'Scan SMS messages from banks and mobile money services to automatically detect subscription payments and renewals.',
      icon: Icons.sms_rounded,
      color: const Color(0xFF4ECDC4),
    ),
    OnboardingPage(
      title: 'Receipt & Barcode',
      description:
          'Take a photo of receipts or scan barcodes to extract subscription details instantly. Works with invoices and payment confirmations.',
      icon: Icons.qr_code_scanner_rounded,
      color: const Color(0xFF95E1D3),
    ),
    OnboardingPage(
      title: 'Cloud Sync',
      description:
          'Sync your subscriptions across all devices with Firebase. Your data is safe, secure, and accessible anywhere.',
      icon: Icons.cloud_sync_rounded,
      color: const Color(0xFFF38181),
    ),
    OnboardingPage(
      title: 'AI Insights & Analytics',
      description:
          'See your spending patterns, detect waste, get AI-powered suggestions, and discover similar subscriptions to save money.',
      icon: Icons.insights_rounded,
      color: const Color(0xFFFFB347),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    setState(() => _isRequestingPermissions = true);

    try {
      // Request all permissions with proper error handling
      await _permissionService.requestAllPermissions();

      // Mark onboarding as completed regardless of permission results
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } catch (e) {
      // Even if permissions fail, complete onboarding
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeShell()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingPermissions = false);
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text('Skip'),
                ),
              ),
            ),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _OnboardingPageWidget(page: _pages[index]);
                },
              ),
            ),

            // Page indicator
            Padding(
              padding:
                  EdgeInsets.symmetric(vertical: ResponsiveHelper.spacing(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _PageIndicator(
                    isActive: index == _currentPage,
                  ),
                ),
              ),
            ),

            // Next/Get Started button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveHelper.spacing(20),
                vertical: ResponsiveHelper.spacing(16),
              ),
              child: Row(
                children: [
                  // Back button (show on pages after first)
                  if (_currentPage > 0)
                    TextButton.icon(
                      onPressed: _isRequestingPermissions
                          ? null
                          : () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.spacing(16),
                          vertical: ResponsiveHelper.spacing(12),
                        ),
                      ),
                    ),
                  if (_currentPage > 0)
                    SizedBox(width: ResponsiveHelper.spacing(8)),
                  // Next/Get Started button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isRequestingPermissions ? null : _nextPage,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveHelper.spacing(16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveHelper.spacing(12),
                          ),
                        ),
                        elevation: 2,
                      ),
                      icon: _isRequestingPermissions
                          ? SizedBox(
                              height: ResponsiveHelper.spacing(20),
                              width: ResponsiveHelper.spacing(20),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              _currentPage == _pages.length - 1
                                  ? Icons.check_circle_outline
                                  : Icons.arrow_forward,
                            ),
                      label: Text(
                        _isRequestingPermissions
                            ? 'Setting up...'
                            : _currentPage == _pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                        style: TextStyle(
                          fontSize: ResponsiveHelper.fontSize(16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageWidget extends StatelessWidget {
  const _OnboardingPageWidget({required this.page});

  final OnboardingPage page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(ResponsiveHelper.spacing(32)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: ResponsiveHelper.width(120),
            height: ResponsiveHelper.width(120),
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: ResponsiveHelper.width(60),
              color: page.color,
            ),
          ),

          SizedBox(height: ResponsiveHelper.spacing(40)),

          // Title
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: page.color,
                ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: ResponsiveHelper.spacing(16)),

          // Description
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(3)),
      width: isActive ? ResponsiveHelper.width(32) : ResponsiveHelper.width(8),
      height: ResponsiveHelper.height(8),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(4)),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
