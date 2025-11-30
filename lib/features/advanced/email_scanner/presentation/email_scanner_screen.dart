import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../data/email_credentials_storage.dart';
import '../data/imap_email_scanner_service.dart';
import '../domain/email_provider.dart';
import '../domain/email_subscription_match.dart';
import '../domain/email_setup_guide.dart';
import 'email_inbox_screen.dart';

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
  ImapEmailScannerService? _imapEmailScannerService;
  bool _isAuthenticated = false;
  bool _isScanning = false;
  bool _isLoadingEmails = false;
  List<EmailSubscriptionMatch> _matches = [];
  List<Map<String, dynamic>> _emails = [];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _imapServerController.dispose();
    _imapPortController.dispose();
    _imapEmailScannerService?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Email Scanner'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Text(
              'Select Email Provider',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(8)),
            Text(
              'Choose your email provider to scan for subscriptions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(24)),

            // Email Providers Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: EmailProvider.values.length,
              itemBuilder: (context, index) {
                final provider = EmailProvider.values[index];
                return _ProviderGridItem(
                  provider: provider,
                  selected: _selectedProvider == provider,
                  onTap: () => _selectProvider(provider),
                );
              },
            ),

            SizedBox(height: ResponsiveHelper.spacing(24)),

            // Help Button
            OutlinedButton.icon(
              onPressed: () => _showSetupGuide(_selectedProvider),
              icon: const Icon(Icons.help_outline),
              label: const Text('How to setup email account'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveHelper.spacing(24),
                  vertical: ResponsiveHelper.spacing(16),
                ),
              ),
            ),

            SizedBox(height: ResponsiveHelper.spacing(32)),

            // Placeholder Info
            // _PlaceholderInfo(),

            if (_isAuthenticated) ...[
              SizedBox(height: ResponsiveHelper.spacing(20)),
            ],
            SizedBox(height: ResponsiveHelper.spacing(20)),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Future<void> _selectProvider(EmailProvider provider) async {
    setState(() {
      _selectedProvider = provider;
      _imapEmailScannerService = ImapEmailScannerService(provider);
      _isAuthenticated = false;
      _matches = [];
      _emails = [];
    });

    // Clear controllers
    _emailController.clear();
    _passwordController.clear();
    _imapServerController.clear();
    _imapPortController.clear();

    // Check if credentials are already saved
    final hasCredentials =
        await EmailCredentialsStorage.hasCredentials(provider);

    if (hasCredentials) {
      // Load saved credentials into form fields
      final credentials =
          await EmailCredentialsStorage.getCredentials(provider);
      if (credentials != null) {
        _emailController.text = credentials['email'] as String? ?? '';
        _passwordController.text = credentials['password'] as String? ?? '';
        _imapServerController.text =
            credentials['customImapServer'] as String? ?? '';
        _imapPortController.text =
            credentials['customImapPort']?.toString() ?? '';
      }
    } else {
      // Pre-fill IMAP settings for known providers
      final settings = ImapEmailScannerService.getImapSettings(provider);
      _imapServerController.text = settings['server'] ?? '';
      _imapPortController.text = settings['port']?.toString() ?? '993';

      // Auto-fill custom email credentials for testing (Titan Email)
      if (provider == EmailProvider.custom) {
        _emailController.text = 'admin@codeinktechnologies.com';
        _passwordController.text = '123@Beatbacklist';
        if (_imapServerController.text.isEmpty ||
            _imapServerController.text == 'Custom') {
          _imapServerController.text = 'imap.titan.email';
        }
        // Titan Email IMAP uses port 993 (SSL), not 465 (which is SMTP)
        if (_imapPortController.text.isEmpty ||
            _imapPortController.text == '993' ||
            _imapPortController.text == '465') {
          _imapPortController.text = '993';
        }
      }
    }

    // Always show connection dialog
    _showConnectionDialog(provider, autoConnect: hasCredentials);
  }

  void _showConnectionDialog(EmailProvider provider,
      {bool autoConnect = false}) {
    showDialog(
      context: context,
      barrierDismissible:
          !autoConnect, // Prevent dismissing during auto-connect
      builder: (dialogContext) => _ConnectionSettingsDialog(
        provider: provider,
        formKey: _formKey,
        emailController: _emailController,
        passwordController: _passwordController,
        imapServerController: _imapServerController,
        imapPortController: _imapPortController,
        isAuthenticated: _isAuthenticated,
        autoConnect: autoConnect,
        onAuthenticate: () async {
          await _authenticate();
          setState(() {}); // Update parent state
          if (mounted && _isAuthenticated) {
            Navigator.of(dialogContext).pop();
            // Small delay to ensure dialog is closed before navigation
            await Future.delayed(const Duration(milliseconds: 100));
            // Navigate to inbox after successful authentication
            await _navigateToInbox();
          }
        },
        onDisconnect: () async {
          await _disconnect();
          setState(() {}); // Update parent state
          if (mounted) {
            Navigator.of(dialogContext).pop();
          }
        },
      ),
    ).then((_) {
      // Refresh UI when dialog closes
      setState(() {});
    });
  }

  Future<void> _navigateToInbox() async {
    if (_selectedProvider == null || _imapEmailScannerService == null) return;

    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EmailInboxScreen(
            provider: _selectedProvider!,
            imapService: _imapEmailScannerService!,
          ),
        ),
      );
    }
  }

  Future<void> _authenticate() async {
    if (_imapEmailScannerService == null ||
        !_formKey.currentState!.validate()) {
      return;
    }

    // Request all permissions when email scanner is accessed
    await _permissionService.requestAllPermissions();

    setState(() => _isScanning = true);

    try {
      // Set credentials for IMAP connection
      final customServer = _imapServerController.text.trim();
      final customPort = _imapPortController.text.trim();

      _imapEmailScannerService!.setCredentials(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        customImapServer: customServer.isNotEmpty ? customServer : null,
        customImapPort: customPort.isNotEmpty ? int.tryParse(customPort) : null,
        useSsl: true, // Default to SSL (port 465 typically requires SSL)
      );

      // Connect using IMAP
      final success = await _imapEmailScannerService!.connect();
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
        // Save credentials for future use
        await EmailCredentialsStorage.saveCredentials(
          provider: _selectedProvider!,
          email: _emailController.text.trim(),
          password: _passwordController.text,
          customImapServer: customServer.isNotEmpty ? customServer : null,
          customImapPort:
              customPort.isNotEmpty ? int.tryParse(customPort) : null,
          useSsl: true,
        );

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
      await _imapEmailScannerService?.disconnect();

      // Delete saved credentials
      if (_selectedProvider != null) {
        await EmailCredentialsStorage.deleteCredentials(_selectedProvider!);
      }

      setState(() {
        _isAuthenticated = false;
        _matches = [];
        _emails = [];
        _selectedProvider = null;
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

  Future<void> _loadEmails() async {
    if (_imapEmailScannerService == null) return;

    setState(() => _isLoadingEmails = true);

    try {
      final emails =
          await _imapEmailScannerService!.fetchEmails(maxResults: 150);
      setState(() {
        _emails = emails;
        _isLoadingEmails = false;
      });
    } catch (e) {
      setState(() => _isLoadingEmails = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading emails: $e')),
        );
      }
    }
  }

  Future<void> _scanEmails() async {
    if (_imapEmailScannerService == null) return;

    setState(() => _isScanning = true);

    try {
      final matches =
          await _imapEmailScannerService!.scanEmails(maxResults: 50);
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

  void _showEmailDetail(Map<String, dynamic> email) {
    showDialog(
      context: context,
      builder: (context) => _EmailDetailDialog(email: email),
    );
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

  void _showSetupGuide(EmailProvider? provider) {
    showDialog(
      context: context,
      builder: (context) => _EmailProviderSelectionDialog(
        initialProvider: provider,
      ),
    );
  }
}

class _ProviderGridItem extends StatelessWidget {
  const _ProviderGridItem({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final EmailProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(16)),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(ResponsiveHelper.spacing(16)),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withOpacity(0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                provider.iconAsset,
                width: 48,
                height: 48,
              ),
              SizedBox(height: ResponsiveHelper.spacing(12)),
              Text(
                provider.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (selected) ...[
                SizedBox(height: ResponsiveHelper.spacing(8)),
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionSettingsDialog extends Dialog {
  const _ConnectionSettingsDialog({
    required this.provider,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.imapServerController,
    required this.imapPortController,
    required this.isAuthenticated,
    required this.autoConnect,
    required this.onAuthenticate,
    required this.onDisconnect,
  });

  final EmailProvider provider;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController imapServerController;
  final TextEditingController imapPortController;
  final bool isAuthenticated;
  final bool autoConnect;
  final Future<void> Function() onAuthenticate;
  final Future<void> Function() onDisconnect;

  @override
  Widget build(BuildContext context) {
    return _ConnectionSettingsDialogContent(
      provider: provider,
      formKey: formKey,
      emailController: emailController,
      passwordController: passwordController,
      imapServerController: imapServerController,
      imapPortController: imapPortController,
      isAuthenticated: isAuthenticated,
      autoConnect: autoConnect,
      onAuthenticate: onAuthenticate,
      onDisconnect: onDisconnect,
    );
  }
}

class _ConnectionSettingsDialogContent extends StatefulWidget {
  const _ConnectionSettingsDialogContent({
    required this.provider,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.imapServerController,
    required this.imapPortController,
    required this.isAuthenticated,
    required this.autoConnect,
    required this.onAuthenticate,
    required this.onDisconnect,
  });

  final EmailProvider provider;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController imapServerController;
  final TextEditingController imapPortController;
  final bool isAuthenticated;
  final bool autoConnect;
  final Future<void> Function() onAuthenticate;
  final Future<void> Function() onDisconnect;

  @override
  State<_ConnectionSettingsDialogContent> createState() =>
      _ConnectionSettingsDialogContentState();
}

class _ConnectionSettingsDialogContentState
    extends State<_ConnectionSettingsDialogContent> {
  bool _isAuthenticating = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = widget.isAuthenticated;

    // Auto-connect if credentials are already loaded
    if (widget.autoConnect && !_isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoConnect();
      });
    }
  }

  @override
  void didUpdateWidget(_ConnectionSettingsDialogContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAuthenticated != widget.isAuthenticated) {
      _isAuthenticated = widget.isAuthenticated;
    }
  }

  Future<void> _autoConnect() async {
    if (widget.formKey.currentState?.validate() ?? false) {
      setState(() => _isAuthenticating = true);
      await widget.onAuthenticate();
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _isAuthenticated = widget.isAuthenticated;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Container(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      widget.provider.iconAsset,
                      width: 32,
                      height: 32,
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.provider.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(4)),
                        Text(
                          'Connection Settings',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isAuthenticating)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  if (_isAuthenticating)
                    Padding(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(8)),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                child: Form(
                  key: widget.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.autoConnect && _isAuthenticating)
                        Container(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: ResponsiveHelper.spacing(12)),
                              Expanded(
                                child: Text(
                                  'Connecting with saved credentials...',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          widget.autoConnect
                              ? 'Connecting with saved credentials...'
                              : 'Enter your credentials to connect. Credentials are stored securely and never leave your device.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                        ),
                      SizedBox(height: ResponsiveHelper.spacing(24)),
                      TextFormField(
                        controller: widget.emailController,
                        enabled: !_isAuthenticating && !widget.autoConnect,
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          hintText: 'your.email@example.com',
                          prefixIcon: const Icon(Icons.email),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      TextFormField(
                        controller: widget.passwordController,
                        enabled: !_isAuthenticating && !widget.autoConnect,
                        decoration: InputDecoration(
                          labelText: 'Password / App Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      ExpansionTile(
                        title: const Text('Advanced Settings (Custom IMAP)'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveHelper.spacing(16),
                            ),
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: widget.imapServerController,
                                  decoration: InputDecoration(
                                    labelText: 'IMAP Server (optional)',
                                    hintText: 'imap.example.com',
                                    prefixIcon: const Icon(Icons.dns),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                                SizedBox(height: ResponsiveHelper.spacing(12)),
                                TextFormField(
                                  controller: widget.imapPortController,
                                  decoration: InputDecoration(
                                    labelText: 'IMAP Port (optional)',
                                    hintText: '993',
                                    prefixIcon: const Icon(Icons.numbers),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      _ImapInfoCard(provider: widget.provider),
                    ],
                  ),
                ),
              ),
            ),

            // Actions
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isAuthenticated || widget.isAuthenticated) ...[
                    Container(
                      padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          SizedBox(width: ResponsiveHelper.spacing(8)),
                          Text(
                            'Connected',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(12)),
                    OutlinedButton(
                      onPressed: () async {
                        await widget.onDisconnect();
                        if (mounted) {
                          setState(() {
                            _isAuthenticated = false;
                          });
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveHelper.spacing(16),
                        ),
                      ),
                      child: const Text('Disconnect'),
                    ),
                  ] else
                    ElevatedButton(
                      onPressed: (_isAuthenticating || widget.autoConnect)
                          ? null
                          : () async {
                              if (widget.formKey.currentState!.validate()) {
                                setState(() => _isAuthenticating = true);
                                await widget.onAuthenticate();
                                if (mounted) {
                                  setState(() {
                                    _isAuthenticating = false;
                                    _isAuthenticated = widget.isAuthenticated;
                                  });
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveHelper.spacing(16),
                        ),
                      ),
                      child: _isAuthenticating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Connect'),
                    ),
                ],
              ),
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
      color: Theme.of(context).colorScheme.surfaceContainer,
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

class _EmailListItem extends StatelessWidget {
  const _EmailListItem({
    required this.email,
    required this.onTap,
  });

  final Map<String, dynamic> email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subject = email['subject'] as String? ?? 'No Subject';
    final from = email['from'] as String? ?? 'Unknown';
    final date = email['date'] as DateTime?;
    final preview =
        email['body'] as String? ?? email['htmlBody'] as String? ?? '';
    final previewText =
        preview.length > 100 ? '${preview.substring(0, 100)}...' : preview;

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.email),
        ),
        title: Text(
          subject,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: ResponsiveHelper.spacing(4)),
            Text(
              from,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (previewText.isNotEmpty) ...[
              SizedBox(height: ResponsiveHelper.spacing(4)),
              Text(
                previewText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (date != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(4)),
              Text(
                _formatDate(date),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                    ),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _EmailDetailDialog extends StatelessWidget {
  const _EmailDetailDialog({required this.email});

  final Map<String, dynamic> email;

  @override
  Widget build(BuildContext context) {
    final subject = email['subject'] as String? ?? 'No Subject';
    final from = email['from'] as String? ?? 'Unknown';
    final date = email['date'] as DateTime?;
    final body = email['body'] as String? ??
        email['htmlBody'] as String? ??
        'No content';

    return Dialog(
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
                          subject,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(8)),
                        Text(
                          'From: $from',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (date != null) ...[
                          SizedBox(height: ResponsiveHelper.spacing(4)),
                          Text(
                            'Date: ${date.toString().substring(0, 19)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
            const Divider(height: 1),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                child: Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
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
      color: Theme.of(context).colorScheme.surfaceContainer,
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

/// Dialog to select email provider and show setup guide
class _EmailProviderSelectionDialog extends StatefulWidget {
  const _EmailProviderSelectionDialog({this.initialProvider});

  final EmailProvider? initialProvider;

  @override
  State<_EmailProviderSelectionDialog> createState() =>
      _EmailProviderSelectionDialogState();
}

class _EmailProviderSelectionDialogState
    extends State<_EmailProviderSelectionDialog> {
  EmailProvider? _selectedProvider;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.initialProvider;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding:
          EdgeInsets.symmetric(horizontal: ResponsiveHelper.spacing(24)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Setup Guides',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                  ),
                        ),
                        SizedBox(height: ResponsiveHelper.spacing(4)),
                        Text(
                          'Select an email provider to view setup instructions',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withOpacity(0.8),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),

            // Provider Icons Row
            Container(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: EmailProvider.values.map((provider) {
                    final isSelected = _selectedProvider == provider;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.spacing(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedProvider = provider;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding:
                                EdgeInsets.all(ResponsiveHelper.spacing(2)),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                  : Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withOpacity(0.2),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  provider.iconAsset,
                                  width: 25,
                                  height: 25,
                                ),
                                /*  SizedBox(height: ResponsiveHelper.spacing(8)),
                                Text(
                                  provider.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                      ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ), */
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Setup Guide Content
            Expanded(
              child: _selectedProvider != null
                  ? _EmailSetupGuideContent(provider: _selectedProvider!)
                  : Center(
                      child: Padding(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.3),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(16)),
                            Text(
                              'Select an email provider',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(8)),
                            Text(
                              'Choose a provider from above to view setup instructions',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Content widget for email setup guide
class _EmailSetupGuideContent extends StatelessWidget {
  const _EmailSetupGuideContent({required this.provider});

  final EmailProvider provider;

  @override
  Widget build(BuildContext context) {
    final guide = EmailSetupGuide.getGuide(provider);

    return ListView(
      padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
      children: [
        // Provider Header
        Container(
          padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SvgPicture.asset(
                    provider.iconAsset,
                    width: 32,
                    height: 32,
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(12)),
                  Expanded(
                    child: Text(
                      provider.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveHelper.spacing(8)),
              Text(
                guide.overview,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                          .withOpacity(0.8),
                    ),
              ),
            ],
          ),
        ),

        SizedBox(height: ResponsiveHelper.spacing(16)),

        // Server Settings (if available)
        if (guide.serverSettings != null) ...[
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server Settings',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: ResponsiveHelper.spacing(8)),
                ...guide.serverSettings!.entries.map((entry) => Padding(
                      padding:
                          EdgeInsets.only(bottom: ResponsiveHelper.spacing(4)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              '${entry.key}:',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
          SizedBox(height: ResponsiveHelper.spacing(16)),
        ],

        // Setup Steps
        Text(
          'Setup Steps',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: ResponsiveHelper.spacing(16)),
        ...guide.steps.map((step) => _SetupStepCard(
              step: step,
              onUrlTap: step.url != null
                  ? () {
                      // You can add url_launcher here if needed
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Open: ${step.url}\n(URL launcher not configured)'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  : null,
            )),

        // Footer with app password link
        if (guide.appPasswordUrl != null) ...[
          SizedBox(height: ResponsiveHelper.spacing(16)),
          Container(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.link,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: ResponsiveHelper.spacing(8)),
                Expanded(
                  child: Text(
                    'Get App Password',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Open: ${guide.appPasswordUrl}'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text('Open Link'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SetupStepCard extends StatelessWidget {
  const _SetupStepCard({
    required this.step,
    this.onUrlTap,
  });

  final EmailSetupStep step;
  final VoidCallback? onUrlTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(16)),
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${step.stepNumber}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveHelper.spacing(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(8)),
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (onUrlTap != null)
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 20),
                    onPressed: onUrlTap,
                    tooltip: 'Open in browser',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (step.subSteps != null && step.subSteps!.isNotEmpty) ...[
              SizedBox(height: ResponsiveHelper.spacing(12)),
              ...step.subSteps!.asMap().entries.map((entry) => Padding(
                    padding: EdgeInsets.only(
                      left: ResponsiveHelper.spacing(44),
                      bottom: ResponsiveHelper.spacing(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.key + 1}.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(8)),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
