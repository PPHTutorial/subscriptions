import 'dart:io';
import 'package:permission_handler/permission_handler.dart'
    hide openAppSettings;
import 'package:permission_handler/permission_handler.dart' as ph
    show openAppSettings;

/// Service for managing all app permissions
class PermissionService {
  /// Request all permissions needed by the app
  ///
  /// Returns a map of permission statuses
  /// Requests permissions one by one to ensure dialogs appear properly
  Future<Map<Permission, PermissionStatus>> requestAllPermissions() async {
    final permissions = <Permission>[];
    final statuses = <Permission, PermissionStatus>{};

    // Always request notifications first
    permissions.add(Permission.notification);

    // Android-specific permissions
    if (Platform.isAndroid) {
      permissions.add(Permission.sms);
      permissions.add(Permission.storage);
      permissions.add(Permission.photos);
    }

    // iOS-specific permissions
    if (Platform.isIOS) {
      permissions.add(Permission.photos);
      permissions.add(Permission.camera);
    }

    // Cross-platform permissions
    if (!permissions.contains(Permission.camera)) {
      permissions.add(Permission.camera);
    }

    // Request permissions one by one with small delays to ensure dialogs appear
    for (final permission in permissions) {
      try {
        final status = await permission.request();
        statuses[permission] = status;
        // Small delay between requests to ensure each dialog appears
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        // If a permission fails, continue with others
        statuses[permission] = PermissionStatus.denied;
      }
    }

    return statuses;
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request SMS permission (Android only)
  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  /// Request storage permission (Android)
  /// On Android 11+ (API 30+), file_picker uses scoped storage which doesn't require explicit permissions
  /// On Android 10 and below, uses storage permission
  /// Note: file_picker handles its own permissions on modern Android versions
  Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true; // iOS doesn't need this

    try {
      // Request storage permission (works for older Android versions)
      final status = await Permission.storage.request();

      // If storage permission is denied, try manageExternalStorage for Android 11+
      if (!status.isGranted) {
        try {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (manageStatus.isGranted) {
            return true;
          }
        } catch (e) {
          // manageExternalStorage might not be available on all devices
          // file_picker should still work with scoped storage
        }
      }

      // Even if permission is denied, file_picker can still work with scoped storage
      // on Android 11+, so we return true to allow the file picker to try
      // The file_picker package handles its own permissions automatically
      return true;
    } catch (e) {
      // If permission request fails, still allow file picker to try
      // file_picker handles its own permissions on modern Android
      return true;
    }
  }

  /// Request photos permission
  Future<bool> requestPhotosPermission() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Check if all critical permissions are granted
  Future<bool> areCriticalPermissionsGranted() async {
    final notificationGranted = await Permission.notification.isGranted;
    return notificationGranted;
  }

  /// Check permission status
  Future<PermissionStatus> checkPermission(Permission permission) async {
    return await permission.status;
  }

  /// Open app settings if permissions are permanently denied
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  /// Get list of denied permissions
  Future<List<Permission>> getDeniedPermissions() async {
    final allPermissions = <Permission>[
      Permission.notification,
      if (Platform.isAndroid) Permission.sms,
      Permission.camera,
      Permission.photos,
      if (Platform.isAndroid) Permission.storage,
    ];

    final denied = <Permission>[];
    for (final permission in allPermissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        denied.add(permission);
      }
    }
    return denied;
  }
}
