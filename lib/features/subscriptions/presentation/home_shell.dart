import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subscriptions/core/responsive/responsive_helper.dart';

import '../../../core/ads/ad_navigation_helper.dart';
import '../../../core/feedback/rating_service.dart';
import '../../../core/feedback/subscription_feedback_dialog.dart';
import '../../../core/navigation/double_back_exit.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/premium/premium_restrictions.dart';
import '../../../core/premium/premium_provider.dart';
import '../../../core/premium/premium_screen.dart';
import '../../advanced/cloud_sync/data/cloud_sync_provider.dart';
import '../../advanced/cloud_sync/presentation/cloud_sync_screen.dart';
import '../../advanced/email_scanner/presentation/email_scanner_screen.dart';
import '../../advanced/receipt_ocr/presentation/receipt_upload_screen.dart';
import '../../advanced/sms_scanner/presentation/sms_scanner_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/subscription_controller.dart';
import '../domain/subscription.dart';
import '../presentation/widgets/sort_filter_bar.dart';
import 'dashboard_screen.dart';
import 'subscriptions_screen.dart';
import 'widgets/add_subscription_sheet.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  SortOption _sortOption = SortOption.renewalDate;
  bool _showTrialsOnly = false;
  SubscriptionCategory? _selectedCategory;
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final _ratingService = RatingService();
  bool _hasCheckedFeedback = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Check for navigation arguments after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        if (args['tabIndex'] != null) {
          setState(() => _index = args['tabIndex'] as int);
        }
        if (args['category'] != null) {
          final categoryName = args['category'] as String;
          try {
            setState(() {
              _selectedCategory = SubscriptionCategory.values
                  .firstWhere((c) => c.name == categoryName);
            });
          } catch (e) {
            // Category not found, ignore
          }
        }
        if (args['searchQuery'] != null) {
          final query = args['searchQuery'] as String;
          setState(() {
            _searchQuery = query;
            _searchController.text = query;
            if (query.isNotEmpty) {
              _isSearchExpanded = true;
            }
          });
        }
      }
    });
    Future.microtask(
      () => ref.read(notificationServiceProvider).requestPermissions(),
    );
    // Show app open ad when navigating to this screen
    Future.microtask(() => AdNavigationHelper.showAppOpenAd());
    // Check if we should show feedback dialog after a delay
    Future.delayed(const Duration(seconds: 3), _checkAndShowFeedback);
  }

  Future<void> _checkAndShowFeedback() async {
    if (_hasCheckedFeedback || !mounted) return;
    _hasCheckedFeedback = true;

    // Check if we should show the prompt
    final shouldShow = await _ratingService.shouldShowPrompt();
    if (!shouldShow) return;

    // Check if user has subscriptions (only show if they have some)
    final subscriptionsAsync = ref.read(subscriptionControllerProvider);
    final subscriptions = subscriptionsAsync.maybeWhen(
      data: (subs) => subs,
      orElse: () => <Subscription>[],
    );

    // Only show if user has at least one subscription
    if (subscriptions.isEmpty) return;

    // Wait a bit more to ensure UI is fully loaded
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Show the feedback dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SubscriptionFeedbackDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(onAddTap: _openCreateSheet),
      SubscriptionsScreen(
        onAddTap: _openCreateSheet,
        sortOption: _sortOption,
        onSortChanged: (option) => setState(() => _sortOption = option),
        showTrialsOnly: _showTrialsOnly,
        onTrialsFilterChanged: (value) =>
            setState(() => _showTrialsOnly = value),
        selectedCategory: _selectedCategory,
        onCategoryChanged: (category) =>
            setState(() => _selectedCategory = category),
        searchQuery: _searchQuery,
      ),
      const SettingsScreen(),
    ];

    // Build title with category if on subscriptions tab
    String getTitle() {
      if (_index == 1 && _selectedCategory != null) {
        return _selectedCategory!.displayName;
      }
      return ['Overview', 'Subscriptions', 'Settings'][_index];
    }

    return DoubleBackExit(
      child: Scaffold(
        extendBody:
            false, // Changed to false so content doesn't hide behind bottom nav
        extendBodyBehindAppBar:
            false, // Ensure AppBar doesn't extend behind status bar
        appBar: AppBar(
          title: _isSearchExpanded && _index == 1
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.spacing(16),
                    ),
                    hintText: 'Search services, payment methods...',
                    border: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                    hintStyle: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.trim());
                  },
                )
              : Text(getTitle()),
          leading: _isSearchExpanded && _index == 1
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    setState(() {
                      _isSearchExpanded = false;
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          actions: [
            if (_isSearchExpanded && _index == 1)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Close search',
                onPressed: () {
                  setState(() {
                    _isSearchExpanded = false;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              ),
            if (_index == 1 && !_isSearchExpanded) ...[
              // Search icon - expands to search field
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search',
                onPressed: () {
                  setState(() {
                    _isSearchExpanded = true;
                  });
                },
              ),
              // Sort menu for subscriptions screen
              PopupMenuButton<SortOption>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: 'Sort',
                initialValue: _sortOption,
                onSelected: (option) => setState(() => _sortOption = option),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: SortOption.renewalDate,
                    child: Row(
                      children: [
                        Icon(Icons.event_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Renewal date'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: SortOption.price,
                    child: Row(
                      children: [
                        Icon(Icons.attach_money_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Price'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: SortOption.category,
                    child: Row(
                      children: [
                        Icon(Icons.category_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Category'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: SortOption.name,
                    child: Row(
                      children: [
                        Icon(Icons.sort_by_alpha_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Name'),
                      ],
                    ),
                  ),
                ],
              ),
              // Filter button for subscriptions screen
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                tooltip: 'Filter',
                onPressed: () => _showFilterDialog(context),
              ),
            ],
            if (!_isSearchExpanded || _index != 1) ...[
              // Sign-in button for overview screen (index 0)
              if (_index == 0)
                Consumer(
                  builder: (context, ref, _) {
                    final signedInAsync = ref.watch(cloudSyncSignedInProvider);
                    return signedInAsync.when(
                      data: (isSignedIn) {
                        if (!isSignedIn) {
                          return IconButton(
                            icon: const Icon(Icons.login_rounded),
                            tooltip: 'Sign in with Google',
                            onPressed: () => _handleSignIn(context, ref),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              // Premium status indicator
              Consumer(
                builder: (context, ref, _) {
                  final premiumStatus =
                      ref.watch(premiumStatusProvider).maybeWhen(
                            data: (premium) => premium,
                            orElse: () => false,
                          );
                  if (premiumStatus) {
                    return IconButton(
                      icon: const Icon(Icons.star_rounded),
                      tooltip: 'Premium Active',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const PremiumScreen(),
                          ),
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              IconButton(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add subscription',
                onPressed: _openCreateSheet,
              ),
            ],
          ],
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: tabs[_index],
        ),
        bottomNavigationBar: _buildNavBar(context),
        /* floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add subscription'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, */
      ),
    );
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    bool tempShowTrialsOnly = _showTrialsOnly;
    SubscriptionCategory? tempSelectedCategory = _selectedCategory;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          insetPadding:
              EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(28)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(8)),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.filter_list_rounded,
                          color: Theme.of(context).colorScheme.onPrimary,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter Subscriptions',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(4)),
                            Text(
                              'Customize your subscription view',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withOpacity(0.7),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
                // Content - Static Trials Only filter
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    ResponsiveHelper.spacing(20),
                    ResponsiveHelper.spacing(20),
                    ResponsiveHelper.spacing(20),
                    ResponsiveHelper.spacing(12),
                  ),
                  child: _FilterOptionCard(
                    title: 'Trials Only',
                    subtitle: 'Show only trial subscriptions',
                    icon: Icons.flash_on_rounded,
                    isSelected: tempShowTrialsOnly,
                    onTap: () {
                      setDialogState(() {
                        tempShowTrialsOnly = !tempShowTrialsOnly;
                      });
                    },
                  ),
                ),
                // Scrollable Category section
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.spacing(20),
                        ),
                        child: Text(
                          'Category',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(12)),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // All categories option
                              _CategoryOption(
                                title: 'All',
                                subtitle: 'Show all categories',
                                isSelected: tempSelectedCategory == null,
                                onTap: () {
                                  setDialogState(() {
                                    tempSelectedCategory = null;
                                  });
                                },
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(8)),
                              // Individual category options
                              ...SubscriptionCategory.values.map(
                                (category) => Padding(
                                  padding: EdgeInsets.only(
                                    bottom: ResponsiveHelper.spacing(8),
                                  ),
                                  child: _CategoryOption(
                                    title: category.displayName,
                                    isSelected:
                                        tempSelectedCategory == category,
                                    onTap: () {
                                      setDialogState(() {
                                        tempSelectedCategory = category;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(8)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveHelper.spacing(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(12)),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _showTrialsOnly = tempShowTrialsOnly;
                              _selectedCategory = tempSelectedCategory;
                            });
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveHelper.spacing(14),
                            ),
                          ),
                          child: const Text('Apply Filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color:
            theme.bottomNavigationBarTheme.backgroundColor?.withOpacity(0.95) ??
                Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(top: ResponsiveHelper.spacing(8)),
        child: BottomNavigationBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          currentIndex: _index,
          onTap: (value) => setState(() => _index = value),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_graph_rounded),
              label: 'Overview',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.credit_card_rounded),
              label: 'Subscriptions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    // Show dialog to choose between manual input and advanced options
    final choice = await showDialog<AddSubscriptionChoice>(
      context: context,
      builder: (context) => const _AddSubscriptionDialog(),
    );

    if (choice == null || !mounted) return;

    final notifier = ref.read(subscriptionControllerProvider.notifier);

    switch (choice) {
      case AddSubscriptionChoice.manual:
        // Check subscription limit before opening sheet
        final currentSubscriptions =
            ref.read(subscriptionControllerProvider).maybeWhen(
                  data: (subs) => subs,
                  orElse: () => <Subscription>[],
                );

        final canAdd = await PremiumRestrictions.canAddSubscription(
          ref,
          currentSubscriptions.length,
        );

        if (!canAdd) {
          // Show restriction dialog
          if (mounted) {
            await _showSubscriptionLimitDialog(context);
          }
          return;
        }

        // Show interstitial ad before opening the sheet
        await AdNavigationHelper.showModalBottomSheetWithInterstitial(
          context,
          (_) => AddSubscriptionSheet(
            onSubmit: (subscription) async {
              try {
                // Check again before actually adding
                final currentSubs =
                    ref.read(subscriptionControllerProvider).maybeWhen(
                          data: (subs) => subs,
                          orElse: () => <Subscription>[],
                        );

                final canStillAdd =
                    await PremiumRestrictions.canAddSubscription(
                  ref,
                  currentSubs.length,
                );

                if (!canStillAdd) {
                  if (mounted) {
                    await _showSubscriptionLimitDialog(context);
                  }
                  return;
                }

                await notifier.addSubscription(subscription);
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to add subscription: $e')),
                  );
                }
              }
            },
          ),
        );
        break;
      case AddSubscriptionChoice.receipt:
        // Check premium restriction
        final isReceiptRestricted = await PremiumRestrictions.isRestricted(
          ref,
          RestrictionType.advancedFeatures,
        );
        if (isReceiptRestricted) {
          if (mounted) {
            await _showPremiumRequiredDialog(context);
          }
          return;
        }
        await AdNavigationHelper.navigateWithInterstitial(
          context,
          const ReceiptUploadScreen(),
        );
        break;
      case AddSubscriptionChoice.sms:
        // Check premium restriction
        final isSmsRestricted = await PremiumRestrictions.isRestricted(
          ref,
          RestrictionType.advancedFeatures,
        );
        if (isSmsRestricted) {
          if (mounted) {
            await _showPremiumRequiredDialog(context);
          }
          return;
        }
        await AdNavigationHelper.navigateWithInterstitial(
          context,
          const SmsScannerScreen(),
        );
        break;
      case AddSubscriptionChoice.email:
        // Check premium restriction
        final isEmailRestricted = await PremiumRestrictions.isRestricted(
          ref,
          RestrictionType.advancedFeatures,
        );
        if (isEmailRestricted) {
          if (mounted) {
            await _showPremiumRequiredDialog(context);
          }
          return;
        }
        await AdNavigationHelper.navigateWithInterstitial(
          context,
          const EmailScannerScreen(),
        );
        break;
    }
  }

  Future<void> _handleSignIn(BuildContext context, WidgetRef ref) async {
    final service = ref.read(cloudSyncServiceProvider);
    if (service == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud Sync is not available'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Attempt sign-in
      final credential = await service.signInWithGoogle();

      // Close loading dialog

      print('credential: ${credential.user?.email}');
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (credential.user != null) {
        // Refresh the state
        ref.invalidate(cloudSyncSignedInProvider);
        ref.invalidate(cloudSyncUserEmailProvider);

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully signed in!'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Navigate to Cloud Sync screen after successful login
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CloudSyncScreen(),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign-in was canceled'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (mounted) {
        final errorMessage = _getSignInErrorMessage(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Details',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CloudSyncScreen(),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  String _getSignInErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('apiException: 10') ||
        errorString.contains('developer_error')) {
      return 'Google Sign-In Error: Please add your SHA-1 fingerprint to Firebase Console. See FIREBASE_SETUP.md for instructions.';
    }

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    if (errorString.contains('sign_in_failed')) {
      return 'Sign-in failed. Please check your Firebase configuration.';
    }

    return 'Sign-in error: ${error.toString()}';
  }

  Future<void> _showPremiumRequiredDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star_outline_rounded),
            SizedBox(width: 12),
            Expanded(child: Text('Premium Feature')),
          ],
        ),
        content: const Text(
          'This feature is available for Premium users only. Upgrade to unlock all advanced features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PremiumScreen(),
                ),
              );
            },
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSubscriptionLimitDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded),
            SizedBox(width: 12),
            Expanded(child: Text('Subscription Limit Reached')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve reached the free limit of ${PremiumRestrictions.maxFreeSubscriptions} subscriptions.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Upgrade to Premium to add unlimited subscriptions and unlock all features.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PremiumScreen(),
                ),
              );
            },
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }
}

enum AddSubscriptionChoice {
  manual,
  receipt,
  sms,
  email,
}

class _AddSubscriptionDialog extends StatelessWidget {
  const _AddSubscriptionDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      insetPadding:
          EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(16)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
                SizedBox(width: ResponsiveHelper.spacing(12)),
                Text(
                  'Add Subscription',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(24)),
            Text(
              'Choose how you want to add a subscription',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(20)),
            _OptionTile(
              icon: Icons.edit_rounded,
              title: 'Manual Input',
              subtitle: 'Enter subscription details manually',
              color: const Color(0xFFF5F5F5),
              onTap: () =>
                  Navigator.of(context).pop(AddSubscriptionChoice.manual),
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            _OptionTile(
              icon: Icons.receipt_long_rounded,
              title: 'Receipt/Invoice Upload',
              subtitle: 'Scan receipt or invoice using OCR',
              color: const Color(0xFFF5F5F5),
              onTap: () =>
                  Navigator.of(context).pop(AddSubscriptionChoice.receipt),
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            _OptionTile(
              icon: Icons.sms_rounded,
              title: 'SMS Scanner',
              subtitle: 'Detect subscriptions from SMS alerts',
              color: const Color(0xFFF5F5F5),
              onTap: () => Navigator.of(context).pop(AddSubscriptionChoice.sms),
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            _OptionTile(
              icon: Icons.email_rounded,
              title: 'Email Scanner',
              subtitle: 'Scan emails for subscription receipts',
              color: const Color(0xFFF5F5F5),
              onTap: () =>
                  Navigator.of(context).pop(AddSubscriptionChoice.email),
            ),
            SizedBox(height: ResponsiveHelper.spacing(20)),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOptionCard extends StatelessWidget {
  const _FilterOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(10)),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 24,
              ),
            ),
            SizedBox(width: ResponsiveHelper.spacing(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(4)),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(0.7)
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withOpacity(0.7),
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.4),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveHelper.spacing(16),
          vertical: ResponsiveHelper.spacing(14),
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : null,
                        ),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: ResponsiveHelper.spacing(2)),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                    .withOpacity(0.7)
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withOpacity(0.6),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: ResponsiveHelper.spacing(12)),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.4),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: ResponsiveHelper.spacing(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(4)),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}
