import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/currency/currency_conversion_service.dart';
import '../../../../core/currency/currency_preferences_provider.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../application/subscription_controller.dart';
import '../domain/subscription.dart';
import 'widgets/add_subscription_sheet.dart';

class SubscriptionDetailsScreen extends ConsumerWidget {
  const SubscriptionDetailsScreen({
    super.key,
    required this.subscription,
  });

  final Subscription subscription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch provider to get real-time updates
    final subscriptionsAsync = ref.watch(subscriptionControllerProvider);
    final currentSubscription = subscriptionsAsync.when(
      data: (subscriptions) => subscriptions.firstWhere(
        (s) => s.id == subscription.id,
        orElse: () => subscription,
      ),
      loading: () => subscription,
      error: (_, __) => subscription,
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSubscription.serviceName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit',
            onPressed: () => _editSubscription(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            tooltip: 'Delete',
            onPressed: () => _deleteSubscription(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main info card
            Card(
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              colorScheme.primary.withOpacity(0.12),
                          child: Text(
                            currentSubscription.serviceName.characters.first
                                .toUpperCase(),
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentSubscription.serviceName,
                                style: theme.textTheme.headlineSmall,
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(4)),
                              Text(
                                currentSubscription.category.name.toUpperCase(),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(24)),
                    Divider(height: 1),
                    SizedBox(height: ResponsiveHelper.spacing(24)),
                    FutureBuilder<double>(
                      future: _getConvertedCost(currentSubscription, ref),
                      builder: (context, snapshot) {
                        final currencyService =
                            ref.read(currencyConversionServiceProvider);
                        final convertedCost = snapshot.data;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailRow(
                              icon: Icons.attach_money_rounded,
                              label: 'Cost',
                              value: convertedCost != null
                                  ? currencyService.formatCurrency(
                                      amount: convertedCost,
                                      currencyCode:
                                          currencyService.baseCurrency,
                                    )
                                  : '${currentSubscription.currencyCode} ${currentSubscription.cost.toStringAsFixed(2)}',
                            ),
                            // Always show original currency and amount in faint color
                            Padding(
                              padding: EdgeInsets.only(
                                left: ResponsiveHelper.spacing(
                                    44), // Align with detail row content
                                top: ResponsiveHelper.spacing(4),
                              ),
                              child: Text(
                                '${currentSubscription.currencyCode} ${currentSubscription.cost.toStringAsFixed(2)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.4),
                                    ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      icon: Icons.repeat_rounded,
                      label: 'Billing Cycle',
                      value: currentSubscription.billingLabel,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Renewal Date',
                      value: DateFormat('EEEE, MMMM dd, yyyy')
                          .format(currentSubscription.renewalDate),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      icon: Icons.payment_rounded,
                      label: 'Payment Method',
                      value: currentSubscription.paymentMethod,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      icon: currentSubscription.autoRenew
                          ? Icons.autorenew_rounded
                          : Icons.sync_disabled_rounded,
                      label: 'Auto Renew',
                      value: currentSubscription.autoRenew
                          ? 'Enabled'
                          : 'Disabled',
                    ),
                    if (currentSubscription.isTrial) ...[
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      _DetailRow(
                        icon: Icons.bolt_rounded,
                        label: 'Trial Status',
                        value: currentSubscription.trialEndsOn != null
                            ? 'Ends ${DateFormat('MMM dd, yyyy').format(currentSubscription.trialEndsOn!)}'
                            : 'Active',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(16)),
            // Reminders card
            Card(
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reminders',
                      style: theme.textTheme.titleLarge,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(12)),
                    if (subscription.reminderDays.isEmpty)
                      Text(
                        'No reminders set',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      )
                    else
                      Wrap(
                        spacing: ResponsiveHelper.spacing(8),
                        runSpacing: ResponsiveHelper.spacing(8),
                        children: currentSubscription.reminderDays.map((days) {
                          return Chip(
                            side: BorderSide(color: colorScheme.outline),
                            label: Text(
                              days == 0
                                  ? 'On renewal day'
                                  : '$days ${days == 1 ? 'day' : 'days'} before',
                            ),
                            avatar: Icon(Icons.notifications_rounded, size: 18),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            if (currentSubscription.notes != null &&
                currentSubscription.notes!.isNotEmpty) ...[
              SizedBox(height: ResponsiveHelper.spacing(16)),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notes',
                        style: theme.textTheme.titleLarge,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(12)),
                      Text(
                        currentSubscription.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: ResponsiveHelper.spacing(20)),
            const BannerAdWidget(),
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

  Future<void> _editSubscription(BuildContext context, WidgetRef ref) async {
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

    if (confirmed == true && context.mounted) {
      try {
        final notifier = ref.read(subscriptionControllerProvider.notifier);
        await notifier.removeSubscription(currentSub.id);
        if (context.mounted) Navigator.of(context).pop();
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        SizedBox(width: ResponsiveHelper.spacing(12)),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
