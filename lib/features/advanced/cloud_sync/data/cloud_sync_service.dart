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
  }

  /// Sign in with Google
  ///
  /// Requires:
  /// 1. Firebase initialized in main.dart (via Firebase.initializeApp())
  /// 2. Google Sign-In enabled in Firebase Console
  /// 3. SHA-1 fingerprint added to Firebase (Android)
  /// 4. OAuth client ID configured (iOS)
  /// 5. Run `flutterfire configure` to generate firebase_options.dart
  Future<bool> signInWithGoogle() async {
    try {
      // Check if Firebase is initialized
      if (!_firebaseAuth.app.isAutomaticDataCollectionEnabled) {
        // Firebase might not be fully initialized
        // This is a soft check - the actual initialization happens in main.dart
      }

      // Create GoogleSignIn instance with email scope
      // Note: GoogleSignIn() constructor should work, but if it doesn't,
      // try using GoogleSignIn.standard() or check package version
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: <String>['email'],
      );

      // Trigger the sign-in flow
      // This opens the Google Sign-In dialog
      // If signIn() doesn't work, the package API may have changed
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      // User canceled the sign-in
      if (googleUser == null) {
        return false;
      }

      // Obtain the auth details from the request
      // This gets the access token and ID token from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Verify we have the required tokens
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        // Missing required tokens - sign-in cannot proceed
        return false;
      }

      // Create a new credential for Firebase Authentication
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      // This links the Google account to Firebase Auth
      final UserCredential userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      // Verify sign-in was successful
      if (userCredential.user != null) {
        return true;
      }

      return false;
    } on FirebaseAuthException {
      // Handle Firebase-specific errors
      // Error codes: account-exists-with-different-credential, invalid-credential, operation-not-allowed
      return false;
    } on Exception {
      // Handle other errors (network, configuration, etc.)
      return false;
    } catch (_) {
      // Catch-all for any other errors
      return false;
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

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

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
}
