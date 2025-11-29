import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/currency/currency_conversion_service.dart';
import '../../../../core/currency/currency_preferences_provider.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/domain/subscription.dart';
import '../data/insights_dataset.dart';

class AlternativesScreen extends ConsumerWidget {
  const AlternativesScreen({
    super.key,
    required this.subscription,
  });

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyService = ref.watch(currencyConversionServiceProvider);
    final alternatives =
        InsightsDataset.getAlternativesForService(subscription.serviceName);

    return FutureBuilder<double>(
      future: _getConvertedMonthlyCost(subscription, currencyService),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final monthlyCost = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Alternative Services'),
          ),
          body: alternatives.isEmpty
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(32)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(16)),
                        Text(
                          'No Alternatives Found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(8)),
                        Text(
                          'We couldn\'t find any alternative services for ${subscription.serviceName}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
                  children: [
                    // Current subscription card
                    Card(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                      child: Padding(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                SizedBox(width: ResponsiveHelper.spacing(8)),
                                Text(
                                  'Current Subscription',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(12)),
                            Text(
                              subscription.serviceName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(4)),
                            Text(
                              '${currencyService.formatCurrency(amount: monthlyCost, currencyCode: currencyService.baseCurrency)}/month',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(20)),
                    Text(
                      'Suggested Alternatives',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    // Sort alternatives by savings (highest first)
                    ...(alternatives.toList()
                          ..sort((a, b) => b.savings.compareTo(a.savings)))
                        .map(
                      (alternative) => _AlternativeCard(
                        alternative: alternative,
                        currentMonthlyCost: monthlyCost,
                        currentServiceName: subscription.serviceName,
                        currencyService: currencyService,
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(20)),
                    const BannerAdWidget(),
                  ],
                ),
        );
      },
    );
  }

  Future<double> _getConvertedMonthlyCost(
    Subscription subscription,
    CurrencyConversionService currencyService,
  ) async {
    final normalizedCost = _normalizeToMonthly(
      subscription.cost,
      subscription.billingCycle,
    );
    return await currencyService.convertToBase(
      amount: normalizedCost,
      fromCurrency: subscription.currencyCode,
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

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({
    required this.alternative,
    required this.currentMonthlyCost,
    required this.currentServiceName,
    required this.currencyService,
  });

  final ServiceAlternative alternative;
  final double currentMonthlyCost;
  final String currentServiceName;
  final CurrencyConversionService currencyService;

  @override
  Widget build(BuildContext context) {
    final estimatedCost = currentMonthlyCost * (1 - alternative.savings);
    final savingsAmount = currentMonthlyCost * alternative.savings;
    final savingsPercent = (alternative.savings * 100).toStringAsFixed(0);

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(8)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alternative.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(4)),
                      Text(
                        'Estimated: ${currencyService.formatCurrency(amount: estimatedCost, currencyCode: currencyService.baseCurrency)}/month',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
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
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Save $savingsPercent%',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(8)),
                  Expanded(
                    child: Text(
                      alternative.reason,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(10)),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Savings',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(4)),
                        Text(
                          currencyService.formatCurrency(
                              amount: savingsAmount,
                              currencyCode: currencyService.baseCurrency),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(12)),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(10)),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yearly Savings',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(4)),
                        Text(
                          currencyService.formatCurrency(
                              amount: savingsAmount * 12,
                              currencyCode: currencyService.baseCurrency),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
