import 'package:characters/characters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/subscription_controller.dart';
import '../../domain/subscription.dart';

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
    final color = Color(subscription.accentColor ?? 0xFF6247EA);
    final contrast =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: contrast.withOpacity(0.12),
                  child: Text(
                    subscription.serviceName.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: contrast,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subscription.serviceName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: contrast,
                        ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    subscription.autoRenew
                        ? Icons.autorenew_rounded
                        : Icons.sync_disabled_rounded,
                    color: contrast,
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
                      Text(
                        '${subscription.currencyCode} ${subscription.cost.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: contrast,
                              fontSize: 24,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subscription.billingLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: contrast.withOpacity(0.75),
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
                            color: contrast.withOpacity(0.6),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(subscription.renewalDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: contrast,
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
                  color: contrast,
                ),
                _buildChip(
                  context,
                  icon: Icons.payment_rounded,
                  label: subscription.paymentMethod,
                  color: contrast,
                ),
                if (subscription.isTrial)
                  _buildChip(
                    context,
                    icon: Icons.bolt_rounded,
                    label: 'Free trial',
                    color: contrast,
                  ),
              ],
            ),
          ],
        ),
      ),
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
}
