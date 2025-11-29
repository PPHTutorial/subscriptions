import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../data/email_scanner_service.dart';
import '../data/imap_email_scanner_service.dart';
import '../domain/email_provider.dart';
import '../domain/email_subscription_match.dart';

class EmailScannerScreen extends ConsumerStatefulWidget {
  const EmailScannerScreen({super.key});

  @override
  ConsumerState<EmailScannerScreen> createState() => _EmailScannerScreenState();
}

class _EmailScannerScreenState extends ConsumerState<EmailScannerScreen> {
  final _permissionService = PermissionService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _imapServerController = TextEditingController();
  final _imapPortController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  EmailProvider? _selectedProvider;
  EmailScannerService? _scannerService;
  bool _isAuthenticated = false;
  bool _isScanning = false;
  bool _showAdvancedSettings = false;
  List<EmailSubscriptionMatch> _matches = [];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _imapServerController.dispose();
    _imapPortController.dispose();
    _scannerService?.disconnect();
    super.dispose();
  }

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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect Email Account',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(12)),
                      Text(
                        'Enter your email credentials to scan for subscriptions. Credentials are stored securely and never leave your device.',
                        style: Theme.of(context).textTheme.bodySmall,
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
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            hintText: 'your.email@example.com',
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(12)),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password / App Password',
                            hintText: 'Enter your password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(12)),
                        ExpansionTile(
                          title: const Text('Advanced Settings (Custom IMAP)'),
                          children: [
                            TextFormField(
                              controller: _imapServerController,
                              decoration: const InputDecoration(
                                labelText: 'IMAP Server (optional)',
                                hintText: 'imap.example.com',
                                prefixIcon: Icon(Icons.dns),
                              ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(12)),
                            TextFormField(
                              controller: _imapPortController,
                              decoration: const InputDecoration(
                                labelText: 'IMAP Port (optional)',
                                hintText: '993',
                                prefixIcon: Icon(Icons.numbers),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(16)),
                        if (_selectedProvider != null)
                          _ImapInfoCard(provider: _selectedProvider!),
                        SizedBox(height: ResponsiveHelper.spacing(16)),
                        ElevatedButton(
                          onPressed: _isAuthenticated ? null : _authenticate,
                          child:
                              Text(_isAuthenticated ? 'Connected' : 'Connect'),
                        ),
                        if (_isAuthenticated)
                          TextButton(
                            onPressed: _disconnect,
                            child: const Text('Disconnect'),
                          ),
                      ],
                    ],
                  ),
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
            SizedBox(height: ResponsiveHelper.spacing(20)),
            const BannerAdWidget(),
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

      // Pre-fill IMAP settings for known providers
      final settings = ImapEmailScannerService.getImapSettings(provider);
      if (_imapServerController.text.isEmpty) {
        _imapServerController.text = settings['server'] ?? '';
      }
      if (_imapPortController.text.isEmpty) {
        _imapPortController.text = settings['port']?.toString() ?? '993';
      }
    });
  }

  Future<void> _authenticate() async {
    if (_scannerService == null || !_formKey.currentState!.validate()) {
      return;
    }

    // Request all permissions when email scanner is accessed
    await _permissionService.requestAllPermissions();

    setState(() => _isScanning = true);

    try {
      // Set credentials for IMAP connection
      _scannerService!.setCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        customImapServer: _imapServerController.text.trim().isNotEmpty
            ? _imapServerController.text.trim()
            : null,
        customImapPort: _imapPortController.text.trim().isNotEmpty
            ? int.tryParse(_imapPortController.text.trim())
            : null,
        useSsl: true, // Default to SSL
      );

      // Connect using IMAP
      final success = await _scannerService!.authenticate();
      setState(() {
        _isAuthenticated = success;
        _isScanning = false;
      });

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Authentication failed. Please check your email and password. For Gmail, you may need to use an App Password.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully connected to email account'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      await _scannerService?.disconnect();
      setState(() {
        _isAuthenticated = false;
        _matches = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error disconnecting: $e')),
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

class _ImapInfoCard extends StatelessWidget {
  const _ImapInfoCard({required this.provider});

  final EmailProvider provider;

  @override
  Widget build(BuildContext context) {
    final settings = ImapEmailScannerService.getImapSettings(provider);
    final note = settings['note'] as String?;

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: ResponsiveHelper.spacing(8)),
                Text(
                  'IMAP Settings',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(8)),
            Text(
              'Server: ${settings['server']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Port: ${settings['port']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (note != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(4)),
              Text(
                'Note: $note',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
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
