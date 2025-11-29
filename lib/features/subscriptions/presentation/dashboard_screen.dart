import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/ads/native_ad_widget.dart';
import '../../../../core/currency/currency_conversion_service.dart';
import '../../../../core/currency/currency_preferences_provider.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../advanced/ai_insights/data/ai_insights_service.dart';
import '../../advanced/ai_insights/presentation/ai_insights_screen.dart';
import '../../advanced/cloud_sync/data/cloud_sync_provider.dart';
import '../../advanced/cloud_sync/data/cloud_sync_service.dart';
import '../../advanced/cloud_sync/presentation/cloud_sync_screen.dart';
import '../../../core/premium/premium_restrictions.dart';
import '../../../core/premium/premium_provider.dart';
import '../../../core/premium/premium_screen.dart';
import '../application/subscription_controller.dart';
import '../domain/subscription.dart';
import 'widgets/analytics_section.dart';
import 'widgets/insight_card.dart';
import 'widgets/subscription_card.dart';
import '../../../core/config/dev_config.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionControllerProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final currencyService = ref.watch(currencyConversionServiceProvider);

    return subscriptionsAsync.when(
      data: (subscriptions) {
        if (subscriptions.isEmpty) {
          return _EmptyState(onAddTap: onAddTap);
        }

        return FutureBuilder<double>(
          future: _calculateMonthlySpend(subscriptions, currencyService),
          builder: (context, monthlySpendSnapshot) {
            final monthlySpend = monthlySpendSnapshot.data ?? 0.0;
            final trialCount = subscriptions.where((s) => s.isTrial).length;
            final upcoming = _upcomingRenewals(subscriptions);
            final topExpensive = _getTopExpensive(subscriptions);
            final paidSubscriptions =
                subscriptions.where((s) => !s.isTrial).length;
            final trialSubscriptions =
                subscriptions.where((s) => s.isTrial).length;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GridView(
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1,
                          ),
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            InsightCard(
                              title: 'Monthly total',
                              value: currencyService.formatCurrency(
                                amount: monthlySpend,
                                currencyCode: baseCurrency,
                              ),
                              subtitle:
                                  'Across ${subscriptions.length} services',
                              icon: Icons.stacked_bar_chart_rounded,
                            ),
                            InsightCard(
                              title: 'Upcoming',
                              value: '${upcoming.length}',
                              subtitle: 'Next 30 days',
                              icon: Icons.event_available_rounded,
                              gradient: [
                                Theme.of(context).colorScheme.secondary,
                                Theme.of(context).colorScheme.tertiary,
                              ],
                            ),
                            InsightCard(
                              title: 'Trials live',
                              value: '$trialCount',
                              subtitle: '$trialSubscriptions total',
                              icon: Icons.flash_on_rounded,
                              gradient: [
                                Theme.of(context).colorScheme.tertiary,
                                Theme.of(context).colorScheme.primary,
                              ],
                            ),
                            InsightCard(
                              title: 'Paid subs',
                              value: '$paidSubscriptions',
                              subtitle: 'Active subscriptions',
                              icon: Icons.credit_card_rounded,
                              gradient: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Upcoming renewals',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (topExpensive.isNotEmpty)
                              TextButton.icon(
                                onPressed: () => _showTopExpensive(
                                    context, ref, topExpensive),
                                icon: const Icon(Icons.trending_up_rounded,
                                    size: 18),
                                label: const Text('Top 5'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...upcoming.map(
                          (subscription) => SubscriptionCard(
                            subscription: subscription,
                            onTap: onAddTap,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _SubscriptionLimitCard(subscriptions: subscriptions),
                        _CloudSyncSection(subscriptions: subscriptions),
                        _AiInsightsSection(subscriptions: subscriptions),
                        const SizedBox(height: 24),
                        AnalyticsSection(subscriptions: subscriptions),
                        const SizedBox(height: 24),
                        Text(
                          'All subscriptions',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(4)),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Show native ad every 4 items
                      if (index > 0 && index % 4 == 0) {
                        return Column(
                          children: [
                            const NativeAdWidget(),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: ResponsiveHelper.spacing(8),
                                horizontal: ResponsiveHelper.spacing(16),
                              ),
                              child: SubscriptionCard(
                                subscription:
                                    subscriptions[index - (index ~/ 4)],
                              ),
                            ),
                          ],
                        );
                      }
                      // Adjust index for native ads
                      final adjustedIndex = index - (index ~/ 4);
                      if (adjustedIndex >= subscriptions.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveHelper.spacing(8),
                          horizontal: ResponsiveHelper.spacing(16),
                        ),
                        child: SubscriptionCard(
                          subscription: subscriptions[adjustedIndex],
                        ),
                      );
                    },
                    childCount: subscriptions.length +
                        (subscriptions.length > 0
                            ? (subscriptions.length ~/ 4)
                            : 0),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: ResponsiveHelper.spacing(8),
                    ),
                    child: const BannerAdWidget(),
                  ),
                ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 36),
            const SizedBox(height: 12),
            Text(error.toString()),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(subscriptionControllerProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate monthly spend with currency conversion to base currency
  Future<double> _calculateMonthlySpend(
    List<Subscription> subscriptions,
    CurrencyConversionService currencyService,
  ) async {
    double total = 0;
    for (final subscription in subscriptions) {
      // Normalize to monthly cost
      final normalized = switch (subscription.billingCycle) {
        BillingCycle.weekly => subscription.cost * 4.3,
        BillingCycle.monthly => subscription.cost,
        BillingCycle.quarterly => subscription.cost / 3,
        BillingCycle.yearly => subscription.cost / 12,
        BillingCycle.custom => subscription.cost,
      };

      // Convert to base currency
      final convertedAmount = await currencyService.convertToBase(
        amount: normalized,
        fromCurrency: subscription.currencyCode,
      );

      total += convertedAmount;
    }
    return total;
  }

  List<Subscription> _upcomingRenewals(List<Subscription> subscriptions) {
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 30));

    final upcoming = subscriptions.where((subscription) {
      return subscription.renewalDate.isAfter(now) &&
          subscription.renewalDate.isBefore(horizon);
    }).toList();

    upcoming.sort((a, b) => a.renewalDate.compareTo(b.renewalDate));
    return upcoming.take(4).toList();
  }

  List<Subscription> _getTopExpensive(List<Subscription> subscriptions) {
    final sorted = List<Subscription>.from(subscriptions)
      ..sort((a, b) => b.cost.compareTo(a.cost));
    return sorted.take(5).toList();
  }

  void _showTopExpensive(
      BuildContext context, WidgetRef ref, List<Subscription> topExpensive) {
    final baseCurrency = ref.read(baseCurrencyProvider);
    final currencyService = ref.read(currencyConversionServiceProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top 5 Expensive Subscriptions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: ResponsiveHelper.spacing(16)),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _getTopExpensiveWithConversion(
                topExpensive,
                currencyService,
                baseCurrency,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snapshot.data ?? [];
                return Column(
                  children: items
                      .map((item) => Padding(
                            padding: EdgeInsets.only(
                                bottom: ResponsiveHelper.spacing(12)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name'] as String,
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      currencyService.formatCurrency(
                                        amount: item['converted'] as double,
                                        currencyCode: baseCurrency,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (item['original'] != item['converted'])
                                      Text(
                                        '${item['originalCurrency']} ${(item['original'] as double).toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.6),
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            SizedBox(height: ResponsiveHelper.spacing(16)),
          ],
        ),
      ),
    );
  }

  /// Get top expensive subscriptions with converted amounts
  Future<List<Map<String, dynamic>>> _getTopExpensiveWithConversion(
    List<Subscription> subscriptions,
    CurrencyConversionService currencyService,
    String baseCurrency,
  ) async {
    final List<Map<String, dynamic>> results = [];

    for (final sub in subscriptions) {
      final converted = await currencyService.convertToBase(
        amount: sub.cost,
        fromCurrency: sub.currencyCode,
      );

      results.add({
        'name': sub.serviceName,
        'original': sub.cost,
        'originalCurrency': sub.currencyCode,
        'converted': converted,
      });
    }

    // Sort by converted amount (descending)
    results.sort((a, b) =>
        (b['converted'] as double).compareTo(a['converted'] as double));

    return results;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMMM');
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.subscriptions_rounded, size: 52),
          ),
          const SizedBox(height: 24),
          Text(
            'No subscriptions yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Add your first plan to see spending insights, timelines, and reminders for ${formatter.format(DateTime.now())}.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddTap,
            icon: const Icon(Icons.add),
            label: const Text('Add subscription'),
          ),
        ],
      ),
    );
  }
}

class _AiInsightsSection extends ConsumerWidget {
  const _AiInsightsSection({required this.subscriptions});

  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subscriptions.isEmpty) {
      return const SizedBox.shrink();
    }

    final insightsService = AiInsightsService();

    return FutureBuilder<List<Insight>>(
      future: insightsService.generateAiInsights(subscriptions),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
              child: Row(
                children: [
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(16)),
                  Text(
                    'Analyzing your subscriptions...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        final insights = snapshot.data ?? [];

        if (insights.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show top 3 insights
        final topInsights = insights.take(3).toList();

        return Card(
          margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(12)),
                        Text(
                          'AI Insights',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    if (insights.length > 3)
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AiInsightsScreen(),
                            ),
                          );
                        },
                        child: const Text('View All'),
                      ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(16)),
                ...topInsights.map((insight) => _DashboardInsightCard(
                      insight: insight,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AiInsightsScreen(),
                          ),
                        );
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CloudSyncSection extends ConsumerStatefulWidget {
  const _CloudSyncSection({required this.subscriptions});

  final List<Subscription> subscriptions;

  @override
  ConsumerState<_CloudSyncSection> createState() => _CloudSyncSectionState();
}

class _CloudSyncSectionState extends ConsumerState<_CloudSyncSection> {
  bool _autoSyncEnabled = false;
  bool _isLoadingAutoSync = true;

  @override
  void initState() {
    super.initState();
    _loadAutoSyncPreference();
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

  Future<void> _loadAutoSyncPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
      _isLoadingAutoSync = false;
    });
  }

  Future<void> _toggleAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', value);
    setState(() {
      _autoSyncEnabled = value;
    });

    // If enabling auto sync and user is signed in, perform initial sync
    if (value) {
      final service = ref.read(cloudSyncServiceProvider);
      if (service != null && service.isSignedIn) {
        _performAutoSync(service);
      }
    }
  }

  Future<void> _performAutoSync(CloudSyncService service) async {
    try {
      await service.syncSubscriptions(widget.subscriptions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto sync completed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto sync failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedInAsync = ref.watch(cloudSyncSignedInProvider);
    final userEmailAsync = ref.watch(cloudSyncUserEmailProvider);
    final service = ref.watch(cloudSyncServiceProvider);

    // Don't show if Cloud Sync is not available
    if (service == null) {
      return const SizedBox.shrink();
    }

    return signedInAsync.when(
      data: (isSignedIn) {
        if (isSignedIn) {
          // User is signed in - show user details and auto sync
          return Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cloud Sync',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(4)),
                            userEmailAsync.when(
                              data: (email) => Text(
                                email ?? 'Signed in',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withOpacity(0.8),
                                    ),
                              ),
                              loading: () => const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_rounded),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CloudSyncScreen(),
                            ),
                          );
                        },
                        tooltip: 'Cloud Sync Settings',
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(16)),
                  SwitchListTile(
                    title: const Text('Auto Sync'),
                    subtitle: const Text(
                      'Automatically sync your subscriptions to the cloud',
                    ),
                    value: _autoSyncEnabled,
                    onChanged: _isLoadingAutoSync
                        ? null
                        : (value) => _toggleAutoSync(value),
                    secondary: Icon(
                      Icons.sync_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    activeColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(8)),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final service = ref.read(cloudSyncServiceProvider);
                            if (service != null && service.isSignedIn) {
                              await _performAutoSync(service);
                            }
                          },
                          icon: const Icon(Icons.cloud_upload_rounded),
                          label: const Text('Backup Now'),
                        ),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(12)),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CloudSyncScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings_rounded),
                          label: const Text('Settings'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
      loading: () => Card(
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (error, _) => const SizedBox.shrink(),
    );
  }
}

class _DashboardInsightCard extends StatelessWidget {
  const _DashboardInsightCard({
    required this.insight,
    required this.onTap,
  });

  final Insight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color borderColor;
    Color iconContainerColor;
    Color iconColor;
    Color titleColor;
    IconData icon = Icons.info_rounded;

    switch (insight.severity) {
      case InsightSeverity.high:
        backgroundColor = colorScheme.tertiaryContainer;
        borderColor = colorScheme.tertiary;
        iconContainerColor = colorScheme.tertiary;
        iconColor = colorScheme.onTertiaryContainer;
        titleColor = colorScheme.onTertiaryContainer;
        icon = Icons.warning_rounded;
        break;
      case InsightSeverity.medium:
        backgroundColor = colorScheme.primaryContainer;
        borderColor = colorScheme.primary;
        iconContainerColor = colorScheme.primary;
        iconColor = colorScheme.onPrimaryContainer;
        titleColor = colorScheme.onPrimaryContainer;
        icon = Icons.info_rounded;
        break;
      case InsightSeverity.low:
        backgroundColor = colorScheme.secondaryContainer;
        borderColor = colorScheme.secondary;
        iconContainerColor = colorScheme.secondary;
        iconColor = colorScheme.onSecondaryContainer;
        titleColor = colorScheme.onSecondaryContainer;
        icon = Icons.lightbulb_rounded;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(8)),
              decoration: BoxDecoration(
                color: iconContainerColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            SizedBox(width: ResponsiveHelper.spacing(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(4)),
                  Text(
                    insight.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: titleColor.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: titleColor.withOpacity(0.6),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to show remaining subscription slots
class _SubscriptionLimitCard extends ConsumerWidget {
  const _SubscriptionLimitCard({required this.subscriptions});

  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final premiumStatus = ref.watch(premiumStatusProvider).maybeWhen(
          data: (premium) => premium,
          orElse: () => false,
        );

    // If premium, don't show the limit card
    if (premiumStatus || DevConfig.isDevModeEnabled) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<int>(
      future: PremiumRestrictions.getRemainingSlots(
        ref,
        subscriptions.length,
      ),
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? 0;
        final currentCount = subscriptions.length;
        final maxCount = PremiumRestrictions.maxFreeSubscriptions;
        final percentage = currentCount / maxCount;

        return Card(
          color: percentage >= 0.8
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.surfaceVariant,
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: percentage >= 0.8
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(12)),
                    Expanded(
                      child: Text(
                        'Subscription Limit',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: percentage >= 0.8
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(12)),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$currentCount / $maxCount subscriptions',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: percentage >= 0.8
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(4)),
                          Text(
                            remaining > 0
                                ? '$remaining slot${remaining > 1 ? 's' : ''} remaining'
                                : 'Limit reached',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: percentage >= 0.8
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer
                                          .withOpacity(0.8)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
                    if (remaining == 0)
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const PremiumScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.star_rounded),
                        label: const Text('Upgrade'),
                      ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(12)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 8,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      percentage >= 0.8
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
