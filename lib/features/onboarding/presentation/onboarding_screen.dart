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
      title: 'Smart Reminders',
      description:
          'Get notified before your subscriptions renew. Set custom reminders so you\'re always in control.',
      icon: Icons.notifications_active_rounded,
      color: const Color(0xFF3AA9FF),
    ),
    OnboardingPage(
      title: 'Automatic Detection',
      description:
          'Scan emails, SMS, and receipts to automatically add subscriptions. Save time with smart detection.',
      icon: Icons.auto_awesome_rounded,
      color: const Color(0xFF25D9B5),
    ),
    OnboardingPage(
      title: 'Analytics & Insights',
      description:
          'See your spending patterns, detect waste, and get AI-powered suggestions to save money.',
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
      final statuses = await _permissionService.requestAllPermissions();

      // Log which permissions were granted/denied (for debugging)
      // You can check statuses to see which permissions were granted

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
              padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                  ),
                  child: _isRequestingPermissions
                      ? SizedBox(
                          height: ResponsiveHelper.spacing(20),
                          width: ResponsiveHelper.spacing(20),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _currentPage == _pages.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
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
      margin: EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(4)),
      width: isActive ? ResponsiveHelper.width(24) : ResponsiveHelper.width(8),
      height: ResponsiveHelper.height(8),
      decoration: BoxDecoration(
        color: isActive
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primary.withOpacity(0.3),
        borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(4)),
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
