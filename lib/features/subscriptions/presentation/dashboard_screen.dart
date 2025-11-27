import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/subscription_controller.dart';
import '../domain/subscription.dart';
import 'widgets/insight_card.dart';
import 'widgets/subscription_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.onAddTap});

  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionsAsync = ref.watch(subscriptionControllerProvider);

    return subscriptionsAsync.when(
      data: (subscriptions) {
        if (subscriptions.isEmpty) {
          return _EmptyState(onAddTap: onAddTap);
        }

        final monthlySpend = _calculateMonthlySpend(subscriptions);
        final trialCount = subscriptions.where((s) => s.isTrial).length;
        final upcoming = _upcomingRenewals(subscriptions);
        final inactive =
            subscriptions.where((s) => s.autoRenew == false).length;

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
                          value: '\$${monthlySpend.toStringAsFixed(2)}',
                          subtitle: 'Across ${subscriptions.length} services',
                          icon: Icons.stacked_bar_chart_rounded,
                        ),
                        InsightCard(
                          title: 'Upcoming',
                          value: '${upcoming.length}',
                          subtitle: 'Next 30 days',
                          icon: Icons.event_available_rounded,
                          gradient: const [
                            Color(0xFF25D9B5),
                            Color(0xFF1FB99B),
                          ],
                        ),
                        InsightCard(
                          title: 'Trials live',
                          value: '$trialCount',
                          subtitle: 'Don’t miss cancellations',
                          icon: Icons.flash_on_rounded,
                          gradient: const [
                            Color(0xFFFF7A8A),
                            Color(0xFFF15D70),
                          ],
                        ),
                        InsightCard(
                          title: 'Manual payments',
                          value: '$inactive',
                          subtitle: 'Need hands-on renewals',
                          icon: Icons.handshake_rounded,
                          gradient: const [
                            Color(0xFF3AA9FF),
                            Color(0xFF2F82F4),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Upcoming renewals',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    ...upcoming.map(
                      (subscription) => SubscriptionCard(
                        subscription: subscription,
                        onTap: onAddTap,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'All subscriptions',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: index == subscriptions.length - 1 ? 32 : 16,
                    ),
                    child: SubscriptionCard(
                      subscription: subscriptions[index],
                    ),
                  );
                },
                childCount: subscriptions.length,
              ),
            ),
          ],
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

  double _calculateMonthlySpend(List<Subscription> subscriptions) {
    double total = 0;
    for (final subscription in subscriptions) {
      final normalized = switch (subscription.billingCycle) {
        BillingCycle.weekly => subscription.cost * 4.3,
        BillingCycle.monthly => subscription.cost,
        BillingCycle.quarterly => subscription.cost / 3,
        BillingCycle.yearly => subscription.cost / 12,
        BillingCycle.custom => subscription.cost,
      };
      total += normalized;
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
                  color: Colors.black54,
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
