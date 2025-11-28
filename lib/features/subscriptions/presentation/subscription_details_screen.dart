import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(subscription.serviceName),
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
                            subscription.serviceName.characters.first
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
                                subscription.serviceName,
                                style: theme.textTheme.headlineSmall,
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(4)),
                              Text(
                                subscription.category.name.toUpperCase(),
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
                    _DetailRow(
                      icon: Icons.attach_money_rounded,
                      label: 'Cost',
                      value:
                          '${subscription.currencyCode} ${subscription.cost.toStringAsFixed(2)}',
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      icon: Icons.repeat_rounded,
                      label: 'Billing Cycle',
                      value: subscription.billingLabel,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Renewal Date',
                      value: DateFormat('EEEE, MMMM dd, yyyy')
                          .format(subscription.renewalDate),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      icon: Icons.payment_rounded,
                      label: 'Payment Method',
                      value: subscription.paymentMethod,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      icon: subscription.autoRenew
                          ? Icons.autorenew_rounded
                          : Icons.sync_disabled_rounded,
                      label: 'Auto Renew',
                      value: subscription.autoRenew ? 'Enabled' : 'Disabled',
                    ),
                    if (subscription.isTrial) ...[
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      _DetailRow(
                        icon: Icons.bolt_rounded,
                        label: 'Trial Status',
                        value: subscription.trialEndsOn != null
                            ? 'Ends ${DateFormat('MMM dd, yyyy').format(subscription.trialEndsOn!)}'
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
                        children: subscription.reminderDays.map((days) {
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
            if (subscription.notes != null &&
                subscription.notes!.isNotEmpty) ...[
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
                        subscription.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editSubscription(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(subscriptionControllerProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSubscriptionSheet(
        subscription: subscription,
        onSubmit: (updated) async {
          await notifier.updateSubscription(updated);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _deleteSubscription(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Subscription'),
        content: Text(
          'Are you sure you want to delete ${subscription.serviceName}? This action cannot be undone.',
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
      final notifier = ref.read(subscriptionControllerProvider.notifier);
      await notifier.removeSubscription(subscription.id);
      if (context.mounted) Navigator.of(context).pop();
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
