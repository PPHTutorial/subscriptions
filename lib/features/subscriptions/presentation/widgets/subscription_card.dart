import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/currency/currency_conversion_service.dart';
import '../../../../core/currency/currency_preferences_provider.dart';
import '../../application/subscription_controller.dart';
import '../../domain/subscription.dart';
import '../subscription_details_screen.dart';
import 'add_subscription_sheet.dart';

class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.onTap,
  });

  final Subscription subscription;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use dark version of primary color for card background
    final cardColor =
        colorScheme.secondaryContainer; // _darkenColor(colorScheme.primary);

    // Text color - use onPrimary for contrast with dark primary background
    final textColor = colorScheme.onSurface;

    // Check if subscription is upcoming (5 days or less)
    final daysUntilRenewal = _daysUntilRenewal(subscription);
    final isUpcoming = daysUntilRenewal != null && daysUntilRenewal <= 5;

    return GestureDetector(
      onTap: onTap ??
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SubscriptionDetailsScreen(
                  subscription: subscription,
                ),
              ),
            );
          },
      onLongPress: () => _showCardMenu(context, ref),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.1),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: textColor.withOpacity(0.12),
                      child: Text(
                        subscription.serviceName.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isUpcoming)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colorScheme.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cardColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subscription.serviceName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: textColor,
                                  ),
                        ),
                      ),
                      if (isUpcoming)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                size: 14,
                                color: colorScheme.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                daysUntilRenewal == 0
                                    ? 'Today'
                                    : daysUntilRenewal == 1
                                        ? 'Tomorrow'
                                        : '$daysUntilRenewal days',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    subscription.autoRenew
                        ? Icons.autorenew_rounded
                        : Icons.sync_disabled_rounded,
                    color: textColor,
                  ),
                  onPressed: () => ref
                      .read(subscriptionControllerProvider.notifier)
                      .toggleAutoRenew(
                        subscription.id,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<double>(
                        future: _getConvertedCost(subscription, ref),
                        builder: (context, snapshot) {
                          final currencyService =
                              ref.read(currencyConversionServiceProvider);
                          final convertedCost = snapshot.data;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                convertedCost != null
                                    ? currencyService.formatCurrency(
                                        amount: convertedCost,
                                        currencyCode:
                                            currencyService.baseCurrency,
                                      )
                                    : '${subscription.currencyCode} ${subscription.cost.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: textColor,
                                      fontSize: 24,
                                    ),
                              ),
                              // Always show original currency and amount in faint color
                              Text(
                                '${subscription.currencyCode} ${subscription.cost.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: textColor.withOpacity(0.4),
                                    ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subscription.billingLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: textColor.withOpacity(0.7),
                            ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Renews',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textColor.withOpacity(0.6),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(subscription.renewalDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: textColor,
                          ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildChip(
                  context,
                  icon: Icons.category_rounded,
                  label: subscription.category.name,
                  color: textColor,
                ),
                _buildChip(
                  context,
                  icon: Icons.payment_rounded,
                  label: subscription.paymentMethod,
                  color: textColor,
                ),
                if (subscription.isTrial)
                  _buildChip(
                    context,
                    icon: Icons.bolt_rounded,
                    label: 'Free trial',
                    color: textColor,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<double> _getConvertedCost(
      Subscription subscription, WidgetRef ref) async {
    final currencyService = ref.read(currencyConversionServiceProvider);
    return await currencyService.convertToBase(
      amount: subscription.cost,
      fromCurrency: subscription.currencyCode,
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('dd MMM, yyyy').format(date);

  int? _daysUntilRenewal(Subscription subscription) {
    final now = DateTime.now();
    final renewal = subscription.renewalDate;
    if (renewal.isBefore(now)) return null;
    final difference = renewal.difference(now);
    return difference.inDays;
  }

  void _showCardMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_rounded),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SubscriptionDetailsScreen(
                        subscription: subscription,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editSubscription(context, ref);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteSubscription(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editSubscription(BuildContext context, WidgetRef ref) async {
    // Get latest subscription from provider
    final subscriptionsAsync = ref.read(subscriptionControllerProvider);
    final currentSub = subscriptionsAsync.when(
      data: (subscriptions) => subscriptions.firstWhere(
        (s) => s.id == subscription.id,
        orElse: () => subscription,
      ),
      loading: () => subscription,
      error: (_, __) => subscription,
    );

    final notifier = ref.read(subscriptionControllerProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSubscriptionSheet(
        subscription: currentSub,
        onSubmit: (updated) async {
          try {
            await notifier.updateSubscription(updated);
            if (context.mounted) Navigator.of(context).pop();
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteSubscription(BuildContext context, WidgetRef ref) async {
    // Get latest subscription from provider
    final subscriptionsAsync = ref.read(subscriptionControllerProvider);
    final currentSub = subscriptionsAsync.when(
      data: (subscriptions) => subscriptions.firstWhere(
        (s) => s.id == subscription.id,
        orElse: () => subscription,
      ),
      loading: () => subscription,
      error: (_, __) => subscription,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text(
          'Are you sure you want to delete ${currentSub.serviceName}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final notifier = ref.read(subscriptionControllerProvider.notifier);
        await notifier.removeSubscription(currentSub.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }
}
