import 'package:flutter/material.dart';
import '../../domain/subscription.dart';

class AnalyticsSection extends StatelessWidget {
  const AnalyticsSection({
    super.key,
    required this.subscriptions,
  });

  final List<Subscription> subscriptions;

  @override
  Widget build(BuildContext context) {
    final inactive = _detectInactiveSubscriptions();
    final inflation = _calculateInflation();

    if (inactive.isEmpty && inflation == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics & Insights',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (inactive.isNotEmpty) ...[
              _buildInactiveSection(context, inactive),
              const SizedBox(height: 16),
            ],
            if (inflation != null) ...[
              _buildInflationSection(context, inflation),
            ],
          ],
        ),
      ),
    );
  }

  List<Subscription> _detectInactiveSubscriptions() {
    // Subscriptions that haven't been renewed in 90+ days and are past due
    final now = DateTime.now();
    return subscriptions.where((sub) {
      if (!sub.isPastDue) return false;
      final daysSinceRenewal = now.difference(sub.renewalDate).inDays;
      return daysSinceRenewal > 90;
    }).toList();
  }

  double? _calculateInflation() {
    // Simple inflation: compare average cost of subscriptions
    // This is a simplified version - in a real app, you'd track historical data
    if (subscriptions.length < 2) return null;

    // For demo, we'll show a placeholder - real implementation would track over time
    // Would need historical data to calculate actual inflation
    return null;
  }

  Widget _buildInactiveSection(
      BuildContext context, List<Subscription> inactive) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.tertiary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Inactive Subscriptions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${inactive.length} subscription${inactive.length == 1 ? '' : 's'} may be inactive (past due 90+ days)',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
        const SizedBox(height: 8),
        ...inactive.take(3).map((sub) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 6,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sub.serviceName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildInflationSection(BuildContext context, double inflation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Subscription Trends',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Track subscription costs over time to identify price increases',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
      ],
    );
  }
}
