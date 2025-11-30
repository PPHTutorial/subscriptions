import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../data/email_credentials_storage.dart';
import '../data/imap_email_scanner_service.dart';
import '../domain/email_provider.dart';
import 'email_scan_results_screen.dart';

class EmailInboxScreen extends ConsumerStatefulWidget {
  const EmailInboxScreen({
    super.key,
    required this.provider,
    required this.imapService,
  });

  final EmailProvider provider;
  final ImapEmailScannerService imapService;

  @override
  ConsumerState<EmailInboxScreen> createState() => _EmailInboxScreenState();
}

class _EmailInboxScreenState extends ConsumerState<EmailInboxScreen> {
  bool _isLoadingEmails = false;
  bool _isScanning = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectAndLoad();
  }

  Future<void> _connectAndLoad() async {
    setState(() {
      _isLoadingEmails = true;
      _isScanning = true;
    });
    try {
      // Check if already connected
      if (!widget.imapService.isConnected) {
        // Ensure credentials are loaded from storage if needed
        await _loadCredentialsIfNeeded();

        // Add timeout to prevent infinite loading
        final connected = await widget.imapService.connect().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception(
                'Connection timeout. Please check your internet connection.');
          },
        );

        if (!connected) {
          setState(() {
            _isConnected = false;
            _isLoadingEmails = false;
            _isScanning = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to connect to email server'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
      setState(() => _isConnected = true);
      // Skip loading emails, go straight to scanning
      await _scanEmails();
    } catch (e) {
      setState(() {
        _isConnected = false;
        _isLoadingEmails = false;
        _isScanning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _loadCredentialsIfNeeded() async {
    // Check if credentials are already set in the service
    // If not, load them from storage
    final credentials =
        await EmailCredentialsStorage.getCredentials(widget.provider);
    if (credentials == null) {
      throw Exception(
        'No saved credentials found. Please connect from the email scanner screen first.',
      );
    }

    final email = credentials['email'] as String?;
    final password = credentials['password'] as String?;
    final customImapServer = credentials['customImapServer'] as String?;
    final customImapPort = credentials['customImapPort'] as int?;
    final useSsl = credentials['useSsl'] as bool?;

    if (email == null || password == null) {
      throw Exception(
          'Invalid credentials. Please reconnect from the email scanner screen.');
    }

    widget.imapService.setCredentials(
      email: email,
      password: password,
      customImapServer: customImapServer,
      customImapPort: customImapPort,
      useSsl: useSsl,
    );
  }

  Future<void> _ensureConnected() async {
    if (!widget.imapService.isConnected) {
      try {
        final connected = await widget.imapService.connect();
        if (connected) {
          setState(() => _isConnected = true);
        } else {
          throw Exception('Failed to connect to email server');
        }
      } catch (e) {
        throw Exception('Connection error: $e');
      }
    } else {
      setState(() => _isConnected = true);
    }
  }

  Future<void> _scanEmails() async {
    setState(() => _isScanning = true);
    try {
      await _ensureConnected();
      debugPrint('Starting email scan from today...');

      // Scan from today going back (most recent first)
      // Set since to 60 days ago to ensure we get recent emails
      final sinceDate = DateTime.now().subtract(const Duration(days: 180));

      final matches = await widget.imapService.scanEmails(
        maxResults: 150,
        since: sinceDate,
      );

      debugPrint('Scan complete: ${matches.length} matches found');
      debugPrint(
          'Matches: ${matches.map((m) => '${m.serviceName} - ${m.cost}').join(", ")}');

      setState(() {
        _isScanning = false;
      });

      if (mounted) {
        if (matches.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No subscriptions found in scanned emails'),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Navigate to results screen and replace this screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EmailScanResultsScreen(
                matches: matches,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error scanning emails: $e');
      setState(() => _isScanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning emails: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.imapService.disconnect();
      await EmailCredentialsStorage.deleteCredentials(widget.provider);
      if (mounted) {
        Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text('${widget.provider.name} Inbox'),
        actions: [
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Disconnect'),
                  ],
                ),
                onTap: () {
                  Future.delayed(const Duration(milliseconds: 100), () {
                    _disconnect();
                  });
                },
              ),
            ],
          ),
        ],
      ),
      body: _isLoadingEmails || _isScanning
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  SizedBox(height: ResponsiveHelper.spacing(16)),
                  Text(
                    _isScanning
                        ? 'Scanning emails for subscriptions...'
                        : 'Connecting to email server...',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveHelper.spacing(8)),
                  if (_isScanning)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveHelper.spacing(32),
                      ),
                      child: Text(
                        'This may take a few moments',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7),
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            )
          : !_isConnected && !_isLoadingEmails
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      Text(
                        'Failed to connect',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(8)),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveHelper.spacing(32),
                        ),
                        child: Text(
                          'Unable to connect to the email server. Please check your internet connection and try again.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(24)),
                      ElevatedButton.icon(
                        onPressed: _connectAndLoad,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : const SizedBox
                  .shrink(), // Should not reach here, but just in case
    );
  }
}
