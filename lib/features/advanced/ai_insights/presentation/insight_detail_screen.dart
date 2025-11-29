import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/currency/currency_conversion_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/domain/subscription.dart';
import '../data/ai_insights_service.dart';
import '../data/insights_dataset.dart';
import 'alternatives_screen.dart';

class InsightDetailScreen extends ConsumerWidget {
  const InsightDetailScreen({
    super.key,
    required this.insight,
    required this.allSubscriptions,
  });

  final Insight insight;
  final List<Subscription> allSubscriptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (insight.type) {
      case InsightType.alternative:
        if (insight.subscriptions.isNotEmpty) {
          return AlternativesScreen(
            subscription: insight.subscriptions.first,
          );
        }
        break;
      case InsightType.waste:
        return _WasteDetailScreen(
          subscriptions: insight.subscriptions,
          allSubscriptions: allSubscriptions,
        );
      case InsightType.overlap:
        return _OverlapDetailScreen(
          subscriptions: insight.subscriptions,
          allSubscriptions: allSubscriptions,
        );
      case InsightType.budget:
        return _BudgetDetailScreen(
          allSubscriptions: allSubscriptions,
        );
      case InsightType.usage:
        return _UsageDetailScreen(
          subscriptions: insight.subscriptions,
          allSubscriptions: allSubscriptions,
        );
    }

    // Fallback
    return Scaffold(
      appBar: AppBar(title: Text(insight.title)),
      body: Center(child: Text(insight.message)),
    );
  }
}

/// Waste Detail Screen - Shows inactive subscriptions
class _WasteDetailScreen extends StatelessWidget {
  _WasteDetailScreen({
    required this.subscriptions,
    required this.allSubscriptions,
  });

  final List<Subscription> subscriptions;
  final List<Subscription> allSubscriptions;

  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  @override
  Widget build(BuildContext context) {
    // Note: Currency conversion should be done, but since this is a StatelessWidget,
    // we'll calculate it synchronously. The actual conversion happens in the AI insights service.
    // For display, we'll use the normalized amounts and format with base currency.
    final totalWaste = subscriptions.fold<double>(
      0,
      (sum, s) => sum + _normalizeToMonthly(s.cost, s.billingCycle),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inactive Subscriptions'),
      ),
      body: ListView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
        children: [
          // Summary card
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
              child: Column(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(12)),
                  Text(
                    '${subscriptions.length} Inactive Subscription${subscriptions.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(8)),
                  Text(
                    'Potential Monthly Savings',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer
                              .withOpacity(0.8),
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(4)),
                  Text(
                    _formatCurrency(totalWaste),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(8)),
                  Text(
                    'Yearly: ${_formatCurrency(totalWaste * 12)}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onTertiaryContainer
                              .withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(20)),
          Text(
            'Inactive Subscriptions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(16)),
          ...subscriptions
              .map((sub) => _WasteSubscriptionCard(subscription: sub)),
        ],
      ),
    );
  }

  double _normalizeToMonthly(double cost, BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return cost * 4.3;
      case BillingCycle.monthly:
        return cost;
      case BillingCycle.quarterly:
        return cost / 3;
      case BillingCycle.yearly:
        return cost / 12;
      case BillingCycle.custom:
        return cost;
    }
  }

  String _formatCurrency(double amount) {
    return _currencyService.formatCurrency(
      amount: amount,
      currencyCode: _currencyService.baseCurrency,
    );
  }
}

class _WasteSubscriptionCard extends StatelessWidget {
  _WasteSubscriptionCard({required this.subscription});

  final Subscription subscription;

  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  @override
  Widget build(BuildContext context) {
    final daysSinceRenewal =
        DateTime.now().difference(subscription.renewalDate).inDays;
    final monthlyCost =
        _normalizeToMonthly(subscription.cost, subscription.billingCycle);

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.serviceName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(4)),
                      Text(
                        '${_formatCurrency(monthlyCost)}/month',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(12),
                    vertical: ResponsiveHelper.spacing(6),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$daysSinceRenewal days overdue',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
                SizedBox(width: ResponsiveHelper.spacing(8)),
                Text(
                  'Last renewal: ${_formatDate(subscription.renewalDate)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                      ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(8)),
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(8)),
                  Expanded(
                    child: Text(
                      'This subscription appears to be inactive. Consider canceling to save ${_formatCurrency(monthlyCost)} per month.',
                      style: Theme.of(context).textTheme.bodyMedium,
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

  double _normalizeToMonthly(double cost, BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return cost * 4.3;
      case BillingCycle.monthly:
        return cost;
      case BillingCycle.quarterly:
        return cost / 3;
      case BillingCycle.yearly:
        return cost / 12;
      case BillingCycle.custom:
        return cost;
    }
  }

  String _formatCurrency(double amount) {
    return _currencyService.formatCurrency(
      amount: amount,
      currencyCode: _currencyService.baseCurrency,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Overlap Detail Screen - Shows overlapping services
class _OverlapDetailScreen extends StatelessWidget {
  _OverlapDetailScreen({
    required this.subscriptions,
    required this.allSubscriptions,
  });

  final List<Subscription> subscriptions;
  final List<Subscription> allSubscriptions;

  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  @override
  Widget build(BuildContext context) {
    final groupName = _getGroupName(subscriptions.first.serviceName);
    final totalCost = subscriptions.fold<double>(
      0,
      (sum, s) => sum + _normalizeToMonthly(s.cost, s.billingCycle),
    );
    final potentialSavings =
        totalCost * ((subscriptions.length - 1) / subscriptions.length);

    return Scaffold(
      appBar: AppBar(
        title: Text('Overlapping $groupName Services'),
      ),
      body: ListView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
        children: [
          // Summary card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
              child: Column(
                children: [
                  Icon(
                    Icons.layers_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(12)),
                  Text(
                    '${subscriptions.length} Similar Services',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(8)),
                  Text(
                    'Total Monthly Cost',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(4)),
                  Text(
                    _formatCurrency(totalCost),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(16)),
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.savings_rounded,
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(8)),
                        Text(
                          'Potential Savings: ${_formatCurrency(potentialSavings)}/month',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(20)),
          Text(
            'Overlapping Services',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(8)),
          Text(
            'These services offer similar features. Consider consolidating to one service.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(16)),
          ...subscriptions
              .map((sub) => _OverlapSubscriptionCard(subscription: sub)),
        ],
      ),
    );
  }

  String _getGroupName(String serviceName) {
    final group = InsightsDataset.getOverlappingGroup(serviceName);
    if (group != null) {
      return group
          .split('_')
          .map((word) => word[0].toUpperCase() + word.substring(1))
          .join(' ');
    }
    return 'Service';
  }

  double _normalizeToMonthly(double cost, BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return cost * 4.3;
      case BillingCycle.monthly:
        return cost;
      case BillingCycle.quarterly:
        return cost / 3;
      case BillingCycle.yearly:
        return cost / 12;
      case BillingCycle.custom:
        return cost;
    }
  }

  String _formatCurrency(double amount) {
    return _currencyService.formatCurrency(
      amount: amount,
      currencyCode: _currencyService.baseCurrency,
    );
  }
}

class _OverlapSubscriptionCard extends StatelessWidget {
  _OverlapSubscriptionCard({required this.subscription});

  final Subscription subscription;

  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  @override
  Widget build(BuildContext context) {
    final monthlyCost =
        _normalizeToMonthly(subscription.cost, subscription.billingCycle);

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.subscriptions_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          subscription.serviceName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
            '${subscription.category.displayName} • ${subscription.billingCycle.name}'),
        trailing: Text(
          _formatCurrency(monthlyCost),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }

  double _normalizeToMonthly(double cost, BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return cost * 4.3;
      case BillingCycle.monthly:
        return cost;
      case BillingCycle.quarterly:
        return cost / 3;
      case BillingCycle.yearly:
        return cost / 12;
      case BillingCycle.custom:
        return cost;
    }
  }

  String _formatCurrency(double amount) {
    return _currencyService.formatCurrency(
      amount: amount,
      currencyCode: _currencyService.baseCurrency,
    );
  }
}

/// Budget Detail Screen - Shows budget breakdown
class _BudgetDetailScreen extends StatelessWidget {
  _BudgetDetailScreen({required this.allSubscriptions});

  final List<Subscription> allSubscriptions;

  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  @override
  Widget build(BuildContext context) {
    double monthlySpend = 0;
    final categorySpending = <SubscriptionCategory, double>{};

    for (final sub in allSubscriptions) {
      final normalized = _normalizeToMonthly(sub.cost, sub.billingCycle);
      monthlySpend += normalized;
      categorySpending[sub.category] =
          (categorySpending[sub.category] ?? 0) + normalized;
    }

    final yearlySpend = monthlySpend * 12;
    final sortedCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Breakdown'),
      ),
      body: ListView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
        children: [
          // Summary card
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(12)),
                  Text(
                    'Total Monthly Spending',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withOpacity(0.8),
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(4)),
                  Text(
                    _formatCurrency(monthlySpend),
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(12)),
                  Text(
                    'Yearly: ${_formatCurrency(yearlySpend)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(20)),
          Text(
            'Spending by Category',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(16)),
          ...sortedCategories.map(
            (entry) => _CategorySpendingCard(
              category: entry.key,
              amount: entry.value,
              total: monthlySpend,
            ),
          ),
        ],
      ),
    );
  }

  double _normalizeToMonthly(double cost, BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return cost * 4.3;
      case BillingCycle.monthly:
        return cost;
      case BillingCycle.quarterly:
        return cost / 3;
      case BillingCycle.yearly:
        return cost / 12;
      case BillingCycle.custom:
        return cost;
    }
  }

  String _formatCurrency(double amount) {
    return _currencyService.formatCurrency(
      amount: amount,
      currencyCode: _currencyService.baseCurrency,
    );
  }
}

class _CategorySpendingCard extends StatelessWidget {
  _CategorySpendingCard({
    required this.category,
    required this.amount,
    required this.total,
  });

  final SubscriptionCategory category;
  final double amount;
  final double total;

  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  @override
  Widget build(BuildContext context) {
    final percentage = (amount / total * 100).toStringAsFixed(1);

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category.displayName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  _formatCurrency(amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(8)),
            LinearProgressIndicator(
              value: amount / total,
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            SizedBox(height: ResponsiveHelper.spacing(4)),
            Text(
              '$percentage% of total spending',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return _currencyService.formatCurrency(
      amount: amount,
      currencyCode: _currencyService.baseCurrency,
    );
  }
}

/// Usage Detail Screen - Shows expensive subscriptions
class _UsageDetailScreen extends StatelessWidget {
  _UsageDetailScreen({
    required this.subscriptions,
    required this.allSubscriptions,
  });

  final List<Subscription> subscriptions;
  final List<Subscription> allSubscriptions;

  @override
  Widget build(BuildContext context) {
    final sortedSubs = subscriptions.toList()
      ..sort((a, b) => _normalizeToMonthly(b.cost, b.billingCycle)
          .compareTo(_normalizeToMonthly(a.cost, a.billingCycle)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('High-Value Subscriptions'),
      ),
      body: ListView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
        children: [
          // Summary card
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
              child: Column(
                children: [
                  Icon(
                    Icons.trending_up_rounded,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(12)),
                  Text(
                    '${subscriptions.length} High-Value Subscription${subscriptions.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(8)),
                  Text(
                    'These subscriptions represent significant value. Ensure you\'re getting the most out of them.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer
                              .withOpacity(0.8),
                        ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(20)),
          Text(
            'Subscriptions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(16)),
          ...sortedSubs.map((sub) => _UsageSubscriptionCard(subscription: sub)),
        ],
      ),
    );
  }

  double _normalizeToMonthly(double cost, BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return cost * 4.3;
      case BillingCycle.monthly:
        return cost;
      case BillingCycle.quarterly:
        return cost / 3;
      case BillingCycle.yearly:
        return cost / 12;
      case BillingCycle.custom:
        return cost;
    }
  }
}

class _UsageSubscriptionCard extends StatelessWidget {
  _UsageSubscriptionCard({required this.subscription});

  final Subscription subscription;

  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  @override
  Widget build(BuildContext context) {
    final monthlyCost =
        _normalizeToMonthly(subscription.cost, subscription.billingCycle);
    final yearlyCost = monthlyCost * 12;

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subscription.serviceName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(4)),
                      Text(
                        subscription.category.displayName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(12),
                    vertical: ResponsiveHelper.spacing(6),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatCurrency(monthlyCost),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.calendar_today_rounded,
                    label: 'Billing',
                    value: subscription.billingCycle.name,
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(8)),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Yearly',
                    value: _formatCurrency(yearlyCost),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _normalizeToMonthly(double cost, BillingCycle cycle) {
    switch (cycle) {
      case BillingCycle.weekly:
        return cost * 4.3;
      case BillingCycle.monthly:
        return cost;
      case BillingCycle.quarterly:
        return cost / 3;
      case BillingCycle.yearly:
        return cost / 12;
      case BillingCycle.custom:
        return cost;
    }
  }

  String _formatCurrency(double amount) {
    return _currencyService.formatCurrency(
      amount: amount,
      currencyCode: _currencyService.baseCurrency,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ResponsiveHelper.spacing(10)),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              SizedBox(width: ResponsiveHelper.spacing(4)),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveHelper.spacing(4)),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
