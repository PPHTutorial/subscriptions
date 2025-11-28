import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../data/cloud_sync_service.dart';

class CloudSyncScreen extends ConsumerStatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  ConsumerState<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends ConsumerState<CloudSyncScreen> {
  CloudSyncService? _syncService;
  bool _isSignedIn = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    try {
      _syncService = CloudSyncService();
      _isSignedIn = _syncService?.isSignedIn ?? false;
    } catch (e) {
      // Service initialization failed (Firebase not configured)
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_syncService == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cloud Sync'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(32)),
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
                  'Firebase Not Configured',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: ResponsiveHelper.spacing(8)),
                Text(
                  'Please configure Firebase in app_config.dart',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Sync'),
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
                      'Firebase Sync',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(8)),
                    Text(
                      'Sync your subscriptions across all your devices using Firebase',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(20)),
            Card(
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isSignedIn ? 'Signed In' : 'Sign In',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    if (!_isSignedIn)
                      ElevatedButton.icon(
                        onPressed: () => _signInWithGoogle(),
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in with Google'),
                      ),
                    if (_isSignedIn) ...[
                      Text(
                        'Signed in as: ${_syncService?.userId ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(16)),
                      ElevatedButton(
                        onPressed: _isSyncing ? null : _sync,
                        child: _isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Sync Now'),
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(12)),
                      OutlinedButton(
                        onPressed: _signOut,
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    if (_syncService == null) return;

    try {
      final success = await _syncService!.signInWithGoogle();
      setState(() => _isSignedIn = success);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sign in failed. Check API configuration.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _sync() async {
    if (_syncService == null) return;

    setState(() => _isSyncing = true);
    try {
      // TODO: Implement actual sync with subscription controller
      // For now, just check connection
      await _syncService!.downloadSubscriptions();
      setState(() => _isSyncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed')),
        );
      }
    } catch (e) {
      setState(() => _isSyncing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    if (_syncService == null) return;
    await _syncService!.signOut();
    setState(() => _isSignedIn = false);
  }
}
