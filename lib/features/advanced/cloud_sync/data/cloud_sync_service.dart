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

  Future<UserCredential> signInWithGoogle() async {
    // Step 1: Trigger Google Sign-In flow
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw Exception("User cancelled sign-in");
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    return userCredential;
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
