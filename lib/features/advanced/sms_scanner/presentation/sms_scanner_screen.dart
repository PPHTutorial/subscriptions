import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../data/sms_scanner_service.dart';

class SmsScannerScreen extends ConsumerStatefulWidget {
  const SmsScannerScreen({super.key});

  @override
  ConsumerState<SmsScannerScreen> createState() => _SmsScannerScreenState();
}

class _SmsScannerScreenState extends ConsumerState<SmsScannerScreen> {
  final _scannerService = SmsScannerService();
  final _permissionService = PermissionService();
  bool _hasPermission = false;
  bool _isScanning = false;
  List<SubscriptionMatch> _matches = [];

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _scannerService.hasPermission();
    setState(() => _hasPermission = hasPermission);
  }

  Future<void> _requestPermission() async {
    // Request all permissions when SMS scanner is accessed
    await _permissionService.requestAllPermissions();

    // Then check SMS permission specifically
    final granted = await _scannerService.requestPermission();
    setState(() => _hasPermission = granted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS permission is required to scan messages'),
        ),
      );
    }
  }

  Future<void> _scanMessages() async {
    if (!_hasPermission) {
      await _requestPermission();
      return;
    }

    setState(() => _isScanning = true);

    try {
      final matches = await _scannerService.scanExistingMessages(limit: 100);
      setState(() {
        _matches = matches;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addSubscription(SubscriptionMatch match) async {
    final notifier = ref.read(subscriptionControllerProvider.notifier);
    await notifier.addSubscription(match.toSubscription());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription added')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Scanner'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(16)),
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.sms_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SMS Scanner',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(4)),
                              Text(
                                'Detect subscriptions from SMS',
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
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(20)),
                    Text(
                      'Automatically scan your SMS messages for subscription-related transactions. '
                      'Works with bank alerts, mobile money notifications, and payment confirmations.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(20)),
                    Wrap(
                      spacing: ResponsiveHelper.spacing(8),
                      runSpacing: ResponsiveHelper.spacing(8),
                      children: [
                        _InfoChip(
                          icon: Icons.notifications_active_rounded,
                          label: 'Real-time detection',
                        ),
                        _InfoChip(
                          icon: Icons.account_balance_rounded,
                          label: 'Bank alerts',
                        ),
                        _InfoChip(
                          icon: Icons.mobile_friendly_rounded,
                          label: 'Mobile money',
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(20)),
                    if (!_hasPermission)
                      ElevatedButton.icon(
                        onPressed: _requestPermission,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: const Text('Grant SMS Permission'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : _scanMessages,
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.search_rounded),
                        label:
                            Text(_isScanning ? 'Scanning...' : 'Scan Messages'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_matches.isNotEmpty) ...[
              SizedBox(height: ResponsiveHelper.spacing(24)),
              Text(
                'Found ${_matches.length} subscription(s)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: ResponsiveHelper.spacing(12)),
              ..._matches.map((match) => _MatchCard(
                    match: match,
                    onAdd: () => _addSubscription(match),
                  )),
            ],
            SizedBox(height: ResponsiveHelper.spacing(20)),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.match,
    required this.onAdd,
  });

  final SubscriptionMatch match;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(16)),
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
                        match.serviceName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(8)),
                      Row(
                        children: [
                          Icon(
                            Icons.attach_money_rounded,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(4)),
                          Text(
                            '${match.currencyCode} ${match.cost.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: Icon(
                    Icons.add_circle_rounded,
                    color: colorScheme.primary,
                    size: 32,
                  ),
                  tooltip: 'Add subscription',
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(16)),
            Divider(height: 1),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            Row(
              children: [
                Expanded(
                  child: _DetailItem(
                    icon: Icons.repeat_rounded,
                    label: 'Billing Cycle',
                    value: match.billingCycle.name[0].toUpperCase() +
                        match.billingCycle.name.substring(1),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(12)),
                Expanded(
                  child: _DetailItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Renewal Date',
                    value: DateFormat('MMM dd, yyyy').format(match.renewalDate),
                  ),
                ),
              ],
            ),
            if (match.paymentMethod != null &&
                match.paymentMethod!.isNotEmpty) ...[
              SizedBox(height: ResponsiveHelper.spacing(12)),
              _DetailItem(
                icon: Icons.payment_rounded,
                label: 'Payment Method',
                value: match.paymentMethod!,
              ),
            ],
            SizedBox(height: ResponsiveHelper.spacing(12)),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(10),
                    vertical: ResponsiveHelper.spacing(6),
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(6)),
                      Text(
                        '${(match.confidence * 100).toStringAsFixed(0)}% confidence',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'From SMS',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
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

class _DetailItem extends StatelessWidget {
  const _DetailItem({
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 24,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        SizedBox(width: ResponsiveHelper.spacing(8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(2)),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveHelper.spacing(10),
        vertical: ResponsiveHelper.spacing(6),
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.primary,
          ),
          SizedBox(width: ResponsiveHelper.spacing(6)),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
