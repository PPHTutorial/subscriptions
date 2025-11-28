import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../data/email_scanner_service.dart';
import '../domain/email_provider.dart';
import '../domain/email_subscription_match.dart';

class EmailScannerScreen extends ConsumerStatefulWidget {
  const EmailScannerScreen({super.key});

  @override
  ConsumerState<EmailScannerScreen> createState() => _EmailScannerScreenState();
}

class _EmailScannerScreenState extends ConsumerState<EmailScannerScreen> {
  final _permissionService = PermissionService();
  EmailProvider? _selectedProvider;
  EmailScannerService? _scannerService;
  bool _isAuthenticated = false;
  bool _isScanning = false;
  List<EmailSubscriptionMatch> _matches = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Scanner'),
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
                      'Connect Email Account',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    _ProviderButton(
                      provider: EmailProvider.gmail,
                      selected: _selectedProvider == EmailProvider.gmail,
                      onTap: () => _selectProvider(EmailProvider.gmail),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(12)),
                    _ProviderButton(
                      provider: EmailProvider.outlook,
                      selected: _selectedProvider == EmailProvider.outlook,
                      onTap: () => _selectProvider(EmailProvider.outlook),
                    ),
                    if (_selectedProvider != null) ...[
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      ElevatedButton(
                        onPressed: _isAuthenticated ? null : _authenticate,
                        child: Text(_isAuthenticated ? 'Connected' : 'Connect'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isAuthenticated) ...[
              SizedBox(height: ResponsiveHelper.spacing(20)),
              ElevatedButton(
                onPressed: _isScanning ? null : _scanEmails,
                child: _isScanning
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Scan Emails'),
              ),
            ],
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

  void _selectProvider(EmailProvider provider) {
    setState(() {
      _selectedProvider = provider;
      _scannerService = EmailScannerService(provider);
      _isAuthenticated = false;
      _matches = [];
    });
  }

  Future<void> _authenticate() async {
    if (_scannerService == null) return;

    // Request all permissions when email scanner is accessed
    await _permissionService.requestAllPermissions();

    try {
      final success = await _scannerService!.authenticate();
      setState(() => _isAuthenticated = success);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication failed. Please check API keys.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _scanEmails() async {
    if (_scannerService == null) return;

    setState(() => _isScanning = true);

    try {
      final matches = await _scannerService!.scanEmails(maxResults: 50);
      setState(() {
        _matches = matches;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error scanning emails: $e')),
        );
      }
    }
  }

  Future<void> _addSubscription(EmailSubscriptionMatch match) async {
    final notifier = ref.read(subscriptionControllerProvider.notifier);
    await notifier.addSubscription(match.toSubscription());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription added')),
      );
    }
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final EmailProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(12)),
      child: Container(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(12)),
        ),
        child: Row(
          children: [
            Text(provider.icon, style: const TextStyle(fontSize: 24)),
            SizedBox(width: ResponsiveHelper.spacing(12)),
            Expanded(
              child: Text(
                provider.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
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

  final EmailSubscriptionMatch match;
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
