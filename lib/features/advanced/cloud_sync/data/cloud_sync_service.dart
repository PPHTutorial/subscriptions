import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/config/app_config.dart';
import '../../../subscriptions/domain/subscription.dart';

/// Service for syncing subscriptions across devices
class CloudSyncService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Configure Google Sign-In with proper scopes
  late final GoogleSignIn _googleSignIn;

  // Make _firebaseAuth accessible for UI
  FirebaseAuth get firebaseAuth => _firebaseAuth;

  CloudSyncService() {
    // Verify Firebase is initialized and Cloud Sync is enabled
    if (!AppConfig.isFirebaseConfigured || !AppConfig.enableCloudSync) {
      throw Exception(
        'Cloud Sync is not available. Firebase must be configured and enabled.',
      );
    }

    // Verify Firebase app is initialized
    try {
      Firebase.app(); // This will throw if Firebase is not initialized
    } catch (e) {
      throw Exception(
        'Firebase is not initialized. Make sure Firebase.initializeApp() is called in main().',
      );
    }

    // Initialize Google Sign-In with proper configuration
    _googleSignIn = GoogleSignIn(
      scopes: <String>['email', 'profile'],
      // Optional: Add serverClientId if you have OAuth 2.0 client ID
      // serverClientId: 'YOUR_SERVER_CLIENT_ID',
    );
  }

  /// Sign in with Google
  /// Returns UserCredential on success, throws exception on failure
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Step 1: Sign out any existing Google Sign-In session to ensure fresh flow
      await _googleSignIn.signOut();

      // Step 2: Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception("User cancelled sign-in");
      }

      developer.log('Google Sign-In successful: ${googleUser.email}',
          name: 'CloudSyncService');

      // Step 3: Get authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception("Failed to get authentication tokens from Google");
      }

      developer.log('Got authentication tokens', name: 'CloudSyncService');

      // Step 4: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 5: Sign in to Firebase with Google credential
      developer.log('Signing in to Firebase...', name: 'CloudSyncService');
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user == null) {
        developer.log('Firebase sign-in returned null user',
            name: 'CloudSyncService');
        throw Exception("Firebase sign-in failed: user is null");
      }

      developer.log(
        'Firebase sign-in successful: ${userCredential.user?.email}',
        name: 'CloudSyncService',
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log(
        'FirebaseAuthException: ${e.code} - ${e.message}',
        name: 'CloudSyncService',
        error: e,
      );
      rethrow;
    } on Exception catch (e) {
      developer.log(
        'Exception during Google Sign-In: $e',
        name: 'CloudSyncService',
        error: e,
      );
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during Google Sign-In: $e',
        name: 'CloudSyncService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception("Unexpected error during sign-in: $e");
    }
  }

  /// Sign out from both Google and Firebase
  Future<void> signOut() async {
    try {
      developer.log('Signing out...', name: 'CloudSyncService');

      // Sign out from Firebase
      await _firebaseAuth.signOut();

      // Sign out from Google Sign-In
      await _googleSignIn.signOut();

      developer.log('Sign out successful', name: 'CloudSyncService');
    } catch (e) {
      developer.log('Error during sign out: $e',
          name: 'CloudSyncService', error: e);
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      developer.log('Signing in with email: $email', name: 'CloudSyncService');

      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception("Sign-in failed: user is null");
      }

      developer.log(
        'Email sign-in successful: ${userCredential.user?.email}',
        name: 'CloudSyncService',
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log(
        'FirebaseAuthException: ${e.code} - ${e.message}',
        name: 'CloudSyncService',
        error: e,
      );
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during email sign-in: $e',
        name: 'CloudSyncService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception("Unexpected error during sign-in: $e");
    }
  }

  /// Create account with email and password
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      developer.log('Creating account with email: $email',
          name: 'CloudSyncService');

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception("Account creation failed: user is null");
      }

      // Update display name if username is provided
      if (username != null && username.isNotEmpty) {
        await userCredential.user?.updateDisplayName(username.trim());
        await userCredential.user?.reload();
      }

      // Store username in Firestore user profile
      if (userCredential.user != null &&
          username != null &&
          username.isNotEmpty) {
        try {
          final userRef =
              _firestore.collection('users').doc(userCredential.user!.uid);
          await userRef.set({
            'username': username.trim(),
            'email': email.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          developer.log('Username stored in Firestore',
              name: 'CloudSyncService');
        } catch (e) {
          developer.log(
            'Failed to store username in Firestore: $e',
            name: 'CloudSyncService',
            error: e,
          );
          // Don't throw - account creation succeeded, just profile update failed
        }
      }

      developer.log(
        'Account created successfully: ${userCredential.user?.email}',
        name: 'CloudSyncService',
      );

      return userCredential;
    } on FirebaseAuthException catch (e) {
      developer.log(
        'FirebaseAuthException: ${e.code} - ${e.message}',
        name: 'CloudSyncService',
        error: e,
      );
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during account creation: $e',
        name: 'CloudSyncService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception("Unexpected error during account creation: $e");
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      developer.log('Sending password reset email to: $email',
          name: 'CloudSyncService');

      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());

      developer.log('Password reset email sent', name: 'CloudSyncService');
    } on FirebaseAuthException catch (e) {
      developer.log(
        'FirebaseAuthException: ${e.code} - ${e.message}',
        name: 'CloudSyncService',
        error: e,
      );
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error sending password reset: $e',
        name: 'CloudSyncService',
        error: e,
        stackTrace: stackTrace,
      );
      throw Exception("Unexpected error sending password reset: $e");
    }
  }

  /// Sign in with Apple (iOS only)
  Future<bool> signInWithApple() async {
    try {
      // TODO: Implement Apple Sign-In for Firebase
      // This requires additional setup for iOS
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if user is signed in
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Get current user ID
  String? get userId => _firebaseAuth.currentUser?.uid;

  /// Upload subscriptions to cloud
  Future<void> uploadSubscriptions(List<Subscription> subscriptions) async {
    if (!isSignedIn || userId == null) {
      throw Exception('Not signed in');
    }

    final userRef = _firestore.collection('users').doc(userId);
    final subscriptionsRef = userRef.collection('subscriptions');

    // Delete existing subscriptions
    final snapshot = await subscriptionsRef.get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }

    // Upload new subscriptions
    for (final subscription in subscriptions) {
      await subscriptionsRef.doc(subscription.id).set(subscription.toJson());
    }

    // Update last sync timestamp
    await userRef.set({
      'lastSync': FieldValue.serverTimestamp(),
      'subscriptionCount': subscriptions.length,
    }, SetOptions(merge: true));
  }

  /// Download subscriptions from cloud
  Future<List<Subscription>> downloadSubscriptions() async {
    if (!isSignedIn || userId == null) {
      throw Exception('Not signed in');
    }

    final subscriptionsRef =
        _firestore.collection('users').doc(userId).collection('subscriptions');

    final snapshot = await subscriptionsRef.get();
    final subscriptions = <Subscription>[];

    for (final doc in snapshot.docs) {
      try {
        final data = doc.data();
        final subscription = Subscription.fromJson(data);
        subscriptions.add(subscription);
      } catch (e) {
        // Skip invalid subscriptions
        continue;
      }
    }

    return subscriptions;
  }

  /// Sync subscriptions (merge local and cloud)
  Future<List<Subscription>> syncSubscriptions(
      List<Subscription> localSubscriptions) async {
    if (!isSignedIn) {
      return localSubscriptions;
    }

    try {
      final cloudSubscriptions = await downloadSubscriptions();

      // Merge strategy: prefer local if conflict, add new from cloud
      final merged = <String, Subscription>{};

      // Add local subscriptions first
      for (final sub in localSubscriptions) {
        merged[sub.id] = sub;
      }

      // Add cloud subscriptions that don't exist locally
      for (final sub in cloudSubscriptions) {
        if (!merged.containsKey(sub.id)) {
          merged[sub.id] = sub;
        }
      }

      // Upload merged list
      await uploadSubscriptions(merged.values.toList());

      return merged.values.toList();
    } catch (e) {
      // If sync fails, return local subscriptions
      return localSubscriptions;
    }
  }

  /// Get sync status information
  Future<Map<String, dynamic>> getSyncStatus() async {
    if (!isSignedIn || userId == null) {
      return {
        'isSignedIn': false,
        'lastSync': null,
        'subscriptionCount': 0,
      };
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(userId).get();
      final data = userDoc.data() ?? {};

      return {
        'isSignedIn': true,
        'lastSync': (data['lastSync'] as Timestamp?)?.toDate(),
        'subscriptionCount': data['subscriptionCount'] ?? 0,
        'email': _firebaseAuth.currentUser?.email,
        'displayName': _firebaseAuth.currentUser?.displayName,
      };
    } catch (e) {
      return {
        'isSignedIn': true,
        'lastSync': null,
        'subscriptionCount': 0,
        'error': e.toString(),
      };
    }
  }

  /// Get Firestore instance for direct access
  FirebaseFirestore get firestore => _firestore;

  /// Change user password (requires reauthentication)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user signed in');
    }

    // Reauthenticate user
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);

    // Update password
    await user.updatePassword(newPassword);
  }

  /// Update user profile
  Future<void> updateProfile({String? displayName}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No user signed in');
    }

    if (displayName != null && displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
      await user.reload();

      // Also update in Firestore
      if (userId != null) {
        await _firestore.collection('users').doc(userId).set({
          'username': displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }
}
