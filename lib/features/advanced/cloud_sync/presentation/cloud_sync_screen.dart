import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/config/app_config.dart';
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
  String? _errorMessage;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      // Check if Firebase is configured
      if (!AppConfig.isFirebaseConfigured) {
        setState(() {
          _errorMessage =
              'Firebase is not configured. Please run "flutterfire configure" to set up Firebase.';
          _isInitializing = false;
        });
        return;
      }

      // Check if Cloud Sync is enabled
      if (!AppConfig.enableCloudSync) {
        setState(() {
          _errorMessage = 'Cloud Sync is disabled in app configuration.';
          _isInitializing = false;
        });
        return;
      }

      // Check if Firebase is initialized
      try {
        Firebase.app();
      } catch (e) {
        setState(() {
          _errorMessage =
              'Firebase is not initialized. Please restart the app after configuring Firebase.';
          _isInitializing = false;
        });
        return;
      }

      // Initialize the service
      _syncService = CloudSyncService();
      _isSignedIn = _syncService?.isSignedIn ?? false;

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize Cloud Sync: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cloud Sync'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_syncService == null || _errorMessage != null) {
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
                  _errorMessage?.contains('not configured') == true
                      ? 'Firebase Not Configured'
                      : 'Cloud Sync Unavailable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: ResponsiveHelper.spacing(8)),
                Text(
                  _errorMessage ?? 'Cloud Sync is not available',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                SizedBox(height: ResponsiveHelper.spacing(24)),
                ElevatedButton.icon(
                  onPressed: _initializeService,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
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
                      'Sync your subscriptions across all your devices ',
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
                      FutureBuilder<String?>(
                        future: _getUserEmail(),
                        builder: (context, snapshot) {
                          final displayText =
                              snapshot.hasData && snapshot.data != null
                                  ? snapshot.data!
                                  : _syncService?.userId ?? 'Unknown';
                          return Text(
                            'Signed in as: $displayText',
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        },
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
            SizedBox(height: ResponsiveHelper.spacing(20)),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }

  Future<String?> _getUserEmail() async {
    if (_syncService == null) return null;
    try {
      // Get user email from Firebase Auth
      final user = _syncService!.firebaseAuth.currentUser;
      return user?.email ?? user?.displayName ?? user?.uid;
    } catch (e) {
      return null;
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_syncService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud Sync service is not initialized.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final credential = await _syncService!.signInWithGoogle();

      setState(() {
        _isSignedIn = credential.user != null;
        _isSyncing = false;
      });

      if (credential.user == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in was canceled or failed. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      } else if (credential.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed in with Google!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isSyncing = false;
        _errorMessage = _getFirebaseErrorMessage(e);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in error: ${_getFirebaseErrorMessage(e)}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Sign in error: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _isSyncing = false;
        _errorMessage = 'Error signing in: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing in: ${e.toString()}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled. Please enable it in Firebase Console.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      default:
        return 'Sign in failed: ${e.message ?? e.code}';
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
