import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import 'cloud_sync_service.dart';

/// Provider for CloudSyncService
/// Returns null if Firebase is not configured or Cloud Sync is disabled
final cloudSyncServiceProvider = Provider<CloudSyncService?>((ref) {
  try {
    if (!AppConfig.isFirebaseConfigured || !AppConfig.enableCloudSync) {
      return null;
    }
    return CloudSyncService();
  } catch (e) {
    return null;
  }
});

/// Provider for checking if user is signed in
final cloudSyncSignedInProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(cloudSyncServiceProvider);
  if (service == null) {
    yield false;
    return;
  }

  // Initial check
  yield service.isSignedIn;

  // Listen to auth state changes
  yield* service.firebaseAuth.authStateChanges().map((user) => user != null);
});

/// Provider for current user email
final cloudSyncUserEmailProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(cloudSyncServiceProvider);
  if (service == null || !service.isSignedIn) {
    return null;
  }

  try {
    final user = service.firebaseAuth.currentUser;
    return user?.email ?? user?.displayName ?? user?.uid;
  } catch (e) {
    return null;
  }
});
