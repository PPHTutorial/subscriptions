import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subscriptions/core/currency/currency_conversion_service.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../domain/email_subscription_match.dart';

class EmailScanResultsScreen extends ConsumerStatefulWidget {
  const EmailScanResultsScreen({
    super.key,
    required this.matches,
  });

  final List<EmailSubscriptionMatch> matches;

  @override
  ConsumerState<EmailScanResultsScreen> createState() =>
      _EmailScanResultsScreenState();
}

class _EmailScanResultsScreenState
    extends ConsumerState<EmailScanResultsScreen> {
  // Filter to only show high confidence matches (>= 70%)
  List<EmailSubscriptionMatch> get _filteredMatches {
    return widget.matches.where((match) => match.confidence >= 0.7).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  @override
  Widget build(BuildContext context) {
    final filteredMatches = _filteredMatches;
    final lowConfidenceCount = widget.matches.length - filteredMatches.length;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Scan Results'),
        actions: [
          if (filteredMatches.isNotEmpty)
            TextButton.icon(
              onPressed: () => _addAllSubscriptions(filteredMatches),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Add All'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    SizedBox(width: ResponsiveHelper.spacing(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan Summary',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(4)),
                          Text(
                            'Found ${widget.matches.length} potential subscription(s)',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (lowConfidenceCount > 0) ...[
                  SizedBox(height: ResponsiveHelper.spacing(12)),
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .errorContainer
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(8)),
                        Expanded(
                          child: Text(
                            '$lowConfidenceCount subscription(s) with low confidence (<70%) are hidden',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onErrorContainer,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Results List
          Expanded(
            child: filteredMatches.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(16)),
                        Text(
                          'No High Confidence Matches',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(8)),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveHelper.spacing(32),
                          ),
                          child: Text(
                            widget.matches.isEmpty
                                ? 'No subscriptions found in scanned emails.'
                                : 'All found subscriptions have confidence below 70%. Try scanning more emails or check your email content.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
                    itemCount: filteredMatches.length,
                    itemBuilder: (context, index) {
                      final match = filteredMatches[index];
                      return _SubscriptionMatchCard(
                        match: match,
                        onAdd: () => _addSubscription(match),
                      );
                    },
                  ),
          ),

          SizedBox(height: ResponsiveHelper.spacing(20)),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Future<void> _addSubscription(EmailSubscriptionMatch match) async {
    final notifier = ref.read(subscriptionControllerProvider.notifier);
    await notifier.addSubscription(match.toSubscription());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${match.serviceName} added to subscriptions'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              // TODO: Implement undo functionality
            },
          ),
        ),
      );
    }
  }

  Future<void> _addAllSubscriptions(
      List<EmailSubscriptionMatch> matches) async {
    final notifier = ref.read(subscriptionControllerProvider.notifier);
    int added = 0;

    for (final match in matches) {
      await notifier.addSubscription(match.toSubscription());
      added++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $added subscription(s)'),
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

class _SubscriptionMatchCard extends StatelessWidget {
  const _SubscriptionMatchCard({
    required this.match,
    required this.onAdd,
  });

  final EmailSubscriptionMatch match;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final confidencePercent = (match.confidence * 100).toInt();
    final confidenceColor = match.confidence >= 0.9
        ? Colors.green
        : match.confidence >= 0.7
            ? Colors.orange
            : Colors.red;

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(16)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.serviceName,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(4)),
                        Text(
                          match.category?.name.toUpperCase() ?? 'OTHER',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Confidence Badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveHelper.spacing(12),
                      vertical: ResponsiveHelper.spacing(6),
                    ),
                    decoration: BoxDecoration(
                      color: confidenceColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: confidenceColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified,
                          size: 16,
                          color: confidenceColor,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(4)),
                        Text(
                          '$confidencePercent%',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: confidenceColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveHelper.spacing(16)),

              // Cost and Billing
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.attach_money,
                      label: 'Cost',
                      value:
                          '${match.currencyCode} ${match.cost.toStringAsFixed(2)}',
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(16)),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.calendar_today,
                      label: 'Billing',
                      value: match.billingCycle.name.toUpperCase(),
                    ),
                  ),
                ],
              ),

              SizedBox(height: ResponsiveHelper.spacing(12)),

              // Renewal Date

              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.event,
                      label: 'Renewal Date',
                      value: _formatDate(match.renewalDate),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(16)),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons.attach_money,
                      label: 'Cost (12 months)',
                      value:
                          '${match.currencyCode} ${((match.cost * 12).toStringAsFixed(2))}',
                    ),
                  ),
                ],
              ),

              if (match.emailSubject != null) ...[
                SizedBox(height: ResponsiveHelper.spacing(12)),
                _InfoItem(
                  icon: Icons.email,
                  label: 'From Email',
                  value: match.emailSubject!,
                  maxLines: 2,
                ),
              ],

              SizedBox(height: ResponsiveHelper.spacing(16)),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
              ),
              SizedBox(height: ResponsiveHelper.spacing(12)),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _MatchDetailDialog(match: match),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else if (difference.inDays > 0) {
      return 'In ${difference.inDays} days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(width: ResponsiveHelper.spacing(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(2)),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchDetailDialog extends ConsumerWidget {
  const _MatchDetailDialog({required this.match});

  final EmailSubscriptionMatch match;
  String _formatCost(String currencyCode, double cost) {
    // Format based on currency
    if (currencyCode == 'USD' ||
        currencyCode == 'CAD' ||
        currencyCode == 'AUD') {
      return '\$${cost.toStringAsFixed(2)}';
    } else if (currencyCode == 'EUR') {
      return '€${cost.toStringAsFixed(2)}';
    } else if (currencyCode == 'GBP') {
      return '£${cost.toStringAsFixed(2)}';
    } else if (currencyCode == 'JPY' || currencyCode == 'KRW') {
      return '${currencyCode} ${cost.toStringAsFixed(0)}';
    } else {
      // For other currencies, show code and amount
      return '${currencyCode} ${cost.toStringAsFixed(2)}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      insetPadding:
          EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(24)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(24)),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.serviceName,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(4)),
                        Text(
                          'Subscription Details',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      label: 'Service Name',
                      value: match.serviceName,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      label: 'Cost',
                      value: _formatCost(match.currencyCode, match.cost),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      label: 'Billing Cycle',
                      value: match.billingCycle.name.toUpperCase(),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      label: 'Renewal Date',
                      value: _formatDate(match.renewalDate),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _DetailRow(
                      label: 'Confidence',
                      value: '${(match.confidence * 100).toInt()}%',
                    ),
                    if (match.category != null) ...[
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      _DetailRow(
                        label: 'Category',
                        value: match.category!.name.toUpperCase(),
                      ),
                    ],
                    if (match.paymentMethod != null) ...[
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      _DetailRow(
                        label: 'Payment Method',
                        value: match.paymentMethod!,
                      ),
                    ],
                    if (match.emailSubject != null) ...[
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      _DetailRow(
                        label: 'Email Subject',
                        value: match.emailSubject!,
                      ),
                    ],
                    if (match.emailDate != null) ...[
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      _DetailRow(
                        label: 'Email Date',
                        value: _formatFullDate(match.emailDate!),
                      ),
                    ],
                    if (match.notes != null && match.notes!.isNotEmpty) ...[
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      _DetailRow(
                        label: 'Notes',
                        value: match.notes!,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
              child: ElevatedButton.icon(
                onPressed: () async {
                  final notifier =
                      ref.read(subscriptionControllerProvider.notifier);
                  await notifier.addSubscription(match.toSubscription());
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('${match.serviceName} added to subscriptions'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Subscription'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: ResponsiveHelper.spacing(16),
                  ),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(4)),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}
