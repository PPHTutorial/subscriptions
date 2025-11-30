import 'dart:developer' as developer;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import 'cloud_sync_service.dart';

/// Provider for CloudSyncService
/// Returns null if Firebase is not configured or Cloud Sync is disabled
final cloudSyncServiceProvider = Provider<CloudSyncService?>((ref) {
  try {
    // Check configuration first
    if (!AppConfig.isFirebaseConfigured) {
      developer.log(
        'CloudSyncService: Firebase is not configured',
        name: 'CloudSyncProvider',
      );
      return null;
    }

    if (!AppConfig.enableCloudSync) {
      developer.log(
        'CloudSyncService: Cloud Sync is disabled',
        name: 'CloudSyncProvider',
      );
      return null;
    }

    // Try to create the service
    final service = CloudSyncService();
    developer.log(
      'CloudSyncService: Service created successfully',
      name: 'CloudSyncProvider',
    );
    return service;
  } catch (e, stackTrace) {
    developer.log(
      'CloudSyncService: Failed to create service: $e',
      name: 'CloudSyncProvider',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
});

/// Provider for checking if user is signed in
/// Uses StreamProvider to listen to auth state changes
final cloudSyncSignedInProvider = StreamProvider<bool>((ref) {
  final service = ref.watch(cloudSyncServiceProvider);

  if (service == null) {
    developer.log(
      'cloudSyncSignedInProvider: Service is null, returning false',
      name: 'CloudSyncProvider',
    );
    return Stream.value(false);
  }

  // Return a stream that listens to auth state changes
  return service.firebaseAuth.authStateChanges().map((User? user) {
    final isSignedIn = user != null;
    developer.log(
      'cloudSyncSignedInProvider: Auth state changed - isSignedIn: $isSignedIn',
      name: 'CloudSyncProvider',
    );
    return isSignedIn;
  });
});

/// Provider for current user email
/// Uses StreamProvider to listen to auth state changes
final cloudSyncUserEmailProvider = StreamProvider<String?>((ref) {
  final service = ref.watch(cloudSyncServiceProvider);

  if (service == null) {
    return Stream.value(null);
  }

  // Return a stream that listens to auth state changes
  return service.firebaseAuth.authStateChanges().map((User? user) {
    if (user == null) {
      return null;
    }

    final email = user.email ?? user.displayName ?? user.uid;
    developer.log(
      'cloudSyncUserEmailProvider: User email: $email',
      name: 'CloudSyncProvider',
    );
    return email;
  });
});
