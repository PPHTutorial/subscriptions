import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scan SMS Messages',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(12)),
                    Text(
                      'Scan your SMS messages for subscription-related transactions. '
                      'This feature works best with bank alerts and mobile money notifications.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    if (!_hasPermission)
                      ElevatedButton(
                        onPressed: _requestPermission,
                        child: const Text('Grant SMS Permission'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _isScanning ? null : _scanMessages,
                        child: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Scan Messages'),
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
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: ListTile(
        title: Text(match.serviceName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${match.currencyCode} ${match.cost.toStringAsFixed(2)}'),
            Text('Confidence: ${(match.confidence * 100).toStringAsFixed(0)}%'),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onAdd,
          child: const Text('Add'),
        ),
      ),
    );
  }
}
