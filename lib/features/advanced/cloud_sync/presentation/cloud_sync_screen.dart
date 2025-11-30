import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../../../subscriptions/domain/subscription.dart';
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

  // Email/Password form controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignUpMode = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
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
        backgroundColor: Theme.of(context).colorScheme.surface,
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
        backgroundColor: Theme.of(context).colorScheme.surface,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Cloud Sync'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              margin: EdgeInsets.only(bottom: ResponsiveHelper.spacing(12)),
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isSignedIn
                          ? 'Signed In'
                          : (_isSignUpMode ? 'Create Account' : 'Sign In'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    if (!_isSignedIn) ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isSignUpMode) ...[
                              TextFormField(
                                controller: _usernameController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  hintText: 'Choose a username',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  if (value.length < 3) {
                                    return 'Username must be at least 3 characters';
                                  }
                                  if (value.length > 20) {
                                    return 'Username must be less than 20 characters';
                                  }
                                  if (!RegExp(r'^[a-zA-Z0-9_]+$')
                                      .hasMatch(value)) {
                                    return 'Username can only contain letters, numbers, and underscores';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(16)),
                            ],
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                hintText: 'your.email@example.com',
                                prefixIcon: const Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@') ||
                                    !value.contains('.')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(16)),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _isSignUpMode
                                  ? _signUp()
                                  : _signInWithEmail(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (_isSignUpMode && value.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            if (!_isSignUpMode) ...[
                              SizedBox(height: ResponsiveHelper.spacing(8)),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _resetPassword,
                                  child: const Text('Forgot Password?'),
                                ),
                              ),
                            ],
                            SizedBox(height: ResponsiveHelper.spacing(16)),
                            ElevatedButton(
                              onPressed: _isSyncing
                                  ? null
                                  : (_isSignUpMode
                                      ? _signUp
                                      : _signInWithEmail),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: ResponsiveHelper.spacing(16),
                                ),
                              ),
                              child: _isSyncing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text(_isSignUpMode
                                      ? 'Create Account'
                                      : 'Sign In'),
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(12)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isSignUpMode
                                      ? 'Already have an account?'
                                      : "Don't have an account?",
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isSignUpMode = !_isSignUpMode;
                                      _errorMessage = null;
                                      // Clear username when switching modes
                                      if (!_isSignUpMode) {
                                        _usernameController.clear();
                                      }
                                    });
                                  },
                                  child: Text(
                                      _isSignUpMode ? 'Sign In' : 'Sign Up'),
                                ),
                              ],
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(16)),
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface)),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ResponsiveHelper.spacing(16),
                                  ),
                                  child: Text(
                                    'OR',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface)),
                              ],
                            ),
                            SizedBox(height: ResponsiveHelper.spacing(16)),
                            OutlinedButton.icon(
                              onPressed: _isSyncing ? null : _signInWithGoogle,
                              icon: const Icon(Icons.login),
                              label: const Text('Sign in with Google'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isSignedIn) ...[
                      // Account Info
                      FutureBuilder<String?>(
                        future: _getUserEmail(),
                        builder: (context, snapshot) {
                          final displayText =
                              snapshot.hasData && snapshot.data != null
                                  ? snapshot.data!
                                  : _syncService?.userId ?? 'Unknown';
                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(Icons.person),
                            ),
                            title: Text('Signed in as'),
                            subtitle: Text(displayText),
                            trailing: IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _showAccountManagementDialog(),
                            ),
                          );
                        },
                      ),
                      Divider(color: Theme.of(context).colorScheme.onSurface),
                      SizedBox(height: ResponsiveHelper.spacing(8)),

                      // Sync Status Section
                      _SyncStatusSection(syncService: _syncService!),

                      // Backup Section
                      _BackupSection(
                        syncService: _syncService!,
                        isSyncing: _isSyncing,
                        onSync: _sync,
                      ),

                      // Restore Section
                      _RestoreSection(syncService: _syncService!),

                      // Auto-Sync Settings
                      _AutoSyncSettingsSection(),
                      SizedBox(height: ResponsiveHelper.spacing(16)),

                      // Sign Out
                      OutlinedButton.icon(
                        onPressed: _signOut,
                        icon: Icon(Icons.logout),
                        label: Text('Sign Out'),
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
      if (user == null) return null;

      // Try to get username from Firestore first
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc.data()?['username'] != null) {
          return userDoc.data()!['username'] as String;
        }
      } catch (e) {
        // Fall back to display name or email
      }

      // Fallback to display name, email, or uid
      return user.displayName ?? user.email ?? user.uid;
    } catch (e) {
      return null;
    }
  }

  Future<void> _signInWithEmail() async {
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

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final credential = await _syncService!.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      setState(() {
        _isSignedIn = credential.user != null;
        _isSyncing = false;
      });

      if (credential.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully signed in as ${credential.user?.email ?? "User"}!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      final errorMsg = _getFirebaseErrorMessage(e);
      setState(() {
        _isSyncing = false;
        _errorMessage = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in error: $errorMsg'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      final errorMsg = _getGenericErrorMessage(e);
      setState(() {
        _isSyncing = false;
        _errorMessage = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing in: $errorMsg'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _signUp() async {
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

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      final credential = await _syncService!.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
        username: _usernameController.text.isNotEmpty
            ? _usernameController.text
            : null,
      );

      setState(() {
        _isSignedIn = credential.user != null;
        _isSyncing = false;
        _isSignUpMode = false;
      });

      if (credential.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Account created! Signed in as ${credential.user?.email ?? "User"}!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      final errorMsg = _getFirebaseErrorMessage(e);
      setState(() {
        _isSyncing = false;
        _errorMessage = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account creation error: $errorMsg'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      final errorMsg = _getGenericErrorMessage(e);
      setState(() {
        _isSyncing = false;
        _errorMessage = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating account: $errorMsg'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!_emailController.text.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      await _syncService?.sendPasswordResetEmail(_emailController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent! Check your inbox.'),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      final errorMsg = _getGenericErrorMessage(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending reset email: $errorMsg'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
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
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final credential = await _syncService!.signInWithGoogle();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

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
          SnackBar(
            content: Text(
                'Successfully signed in as ${credential.user?.email ?? credential.user?.displayName ?? "User"}!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      final errorMsg = _getFirebaseErrorMessage(e);
      setState(() {
        _isSyncing = false;
        _errorMessage = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in error: $errorMsg'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
      }

      debugPrint('Sign in error: $e');
      debugPrint('Stack trace: $stackTrace');

      final errorMsg = _getGenericErrorMessage(e);
      setState(() {
        _isSyncing = false;
        _errorMessage = errorMsg;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing in: $errorMsg'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  String _getGenericErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Check for common Google Sign-In errors
    if (errorString.contains('apiException: 10') ||
        errorString.contains('developer_error') ||
        errorString.contains('DEVELOPER_ERROR')) {
      return 'Google Sign-In Error: Please add your SHA-1 fingerprint to Firebase Console. See FIREBASE_SETUP.md for instructions.';
    }

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    if (errorString.contains('sign_in_failed') ||
        errorString.contains('sign_in_cancelled') ||
        errorString.contains('sign_in_canceled')) {
      return 'Sign-in was canceled or failed. Please try again.';
    }

    if (errorString.contains('user cancelled') ||
        errorString.contains('user canceled')) {
      return 'Sign-in was canceled.';
    }

    if (errorString.contains('platform_exception')) {
      return 'Platform error. Please ensure Google Play Services is up to date.';
    }

    // Return the original error message
    return error.toString();
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid-email':
        return 'Invalid email address. Please check and try again.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled. Please contact support.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'The credential is invalid or has expired.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'An error occurred: ${e.code}';
    }
  }

  Future<void> _sync() async {
    if (_syncService == null) return;

    setState(() => _isSyncing = true);
    try {
      // Get current subscriptions from controller
      final subscriptionsAsync = ref.read(subscriptionControllerProvider);
      final localSubscriptions = subscriptionsAsync.maybeWhen(
        data: (subs) => subs,
        orElse: () => <Subscription>[],
      );

      // Sync with cloud (merge local and cloud)
      await _syncService!.syncSubscriptions(localSubscriptions);

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

    try {
      await _syncService!.signOut();
      setState(() => _isSignedIn = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showAccountManagementDialog() async {
    if (_syncService == null) return;

    final user = _syncService!.firebaseAuth.currentUser;
    if (user == null) return;

    final email = user.email ?? 'No email';
    final displayName = user.displayName ?? 'No display name';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Management'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: Text(email),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person),
              title: const Text('Display Name'),
              subtitle: Text(displayName),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SyncStatusSection extends StatelessWidget {
  const _SyncStatusSection({required this.syncService});

  final CloudSyncService syncService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: syncService.getSyncStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final status = snapshot.data ?? {};
        final lastSync = status['lastSync'] as DateTime?;
        final subscriptionCount = status['subscriptionCount'] as int? ?? 0;

        return Card(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Padding(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: ResponsiveHelper.spacing(12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Last Sync:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      lastSync != null
                          ? '${lastSync.day}/${lastSync.month}/${lastSync.year} ${lastSync.hour}:${lastSync.minute.toString().padLeft(2, '0')}'
                          : 'Never',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveHelper.spacing(8)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cloud Subscriptions:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '$subscriptionCount',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackupSection extends StatelessWidget {
  const _BackupSection({
    required this.syncService,
    required this.isSyncing,
    required this.onSync,
  });

  final CloudSyncService syncService;
  final bool isSyncing;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: ResponsiveHelper.spacing(8)),
            Text(
              'Upload your subscriptions to the cloud',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: ResponsiveHelper.spacing(16)),
            ElevatedButton.icon(
              onPressed: isSyncing ? null : onSync,
              icon: isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(isSyncing ? 'Backing up...' : 'Backup to Cloud'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestoreSection extends StatelessWidget {
  const _RestoreSection({required this.syncService});

  final CloudSyncService syncService;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restore',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: ResponsiveHelper.spacing(8)),
            Text(
              'Download subscriptions from the cloud',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: ResponsiveHelper.spacing(16)),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await syncService.downloadSubscriptions();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Restore completed'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Restore failed: $e'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.cloud_download),
              label: const Text('Restore from Cloud'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoSyncSettingsSection extends StatefulWidget {
  const _AutoSyncSettingsSection();

  @override
  State<_AutoSyncSettingsSection> createState() =>
      _AutoSyncSettingsSectionState();
}

class _AutoSyncSettingsSectionState extends State<_AutoSyncSettingsSection> {
  bool _autoSyncEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAutoSyncSetting();
  }

  Future<void> _loadAutoSyncSetting() async {
    // TODO: Load from SharedPreferences or similar
    setState(() {
      _autoSyncEnabled = false;
    });
  }

  Future<void> _saveAutoSyncSetting(bool value) async {
    // TODO: Save to SharedPreferences or similar
    setState(() {
      _autoSyncEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Auto-Sync',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: ResponsiveHelper.spacing(8)),
            Text(
              'Automatically sync your subscriptions',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            SwitchListTile(
              value: _autoSyncEnabled,
              onChanged: _saveAutoSyncSetting,
              title: const Text('Enable Auto-Sync'),
              subtitle: const Text('Sync automatically when app opens'),
            ),
          ],
        ),
      ),
    );
  }
}
