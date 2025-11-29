import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/subscriptions/domain/subscription.dart';

final notificationServiceProvider = Provider<NotificationService>((_) {
  throw UnimplementedError(
    'notificationServiceProvider must be overridden in ProviderScope',
  );
});

abstract class NotificationService {
  Future<void> initialize();
  Future<bool> requestPermissions();
  Future<void> scheduleSubscription(Subscription subscription);
  Future<void> cancelForSubscription(String subscriptionId);
  Future<void> syncSubscriptions(List<Subscription> subscriptions);
}

class LocalNotificationService implements NotificationService {
  LocalNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'subscription_reminders';

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();
    // Use system's local timezone
    // The timezone package will use the system default when we use tz.TZDateTime.from
    // No need to explicitly set location as zonedSchedule handles system timezone

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create notification channel with sound and vibration (Android 8.0+)
    if (Platform.isAndroid) {
      final androidChannel = AndroidNotificationChannel(
        _channelId,
        'Subscription reminders',
        description: 'Notifications for upcoming subscription renewals',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        showBadge: true,
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    var androidGranted = true;
    if (Platform.isAndroid) {
      final status = await Permission.notification.request();
      androidGranted = status.isGranted || status.isLimited;
    }

    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final mac = await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return androidGranted && (ios ?? true) && (mac ?? true);
  }

  @override
  Future<void> scheduleSubscription(Subscription subscription) async {
    if (!_initialized) await initialize();

    await cancelForSubscription(subscription.id);

    if (subscription.reminderDays.isEmpty) {
      return;
    }

    // Get notification settings (if available)
    // Note: This requires notificationSettingsProvider to be accessible
    // For now, we'll use default settings (all enabled)
    final playSound =
        true; // Will be overridden by settings if provider is available
    final enableVibration =
        true; // Will be overridden by settings if provider is available

    // Check if exact alarms are permitted (Android 12+)
    bool canScheduleExact = true;
    if (Platform.isAndroid) {
      canScheduleExact = await _canScheduleExactAlarms();
    }

    for (final offset in subscription.reminderDays) {
      final scheduledDate =
          subscription.renewalDate.subtract(Duration(days: offset));
      if (scheduledDate.isBefore(DateTime.now())) continue;

      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      final id = _notificationId(subscription.id, offset);
      final title = _notificationTitle(subscription, offset);
      final message = _message(subscription, offset);

      try {
        // Try exact scheduling first if permitted
        if (canScheduleExact && Platform.isAndroid) {
          await _plugin.zonedSchedule(
            id,
            title,
            message,
            tzDate,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                'Subscription reminders',
                channelDescription: 'Notifications for upcoming renewals',
                importance: Importance.max,
                priority: Priority.high,
                category: AndroidNotificationCategory.reminder,
                playSound: playSound,
                enableVibration: enableVibration,
                vibrationPattern: enableVibration
                    ? Int64List.fromList([0, 250, 250, 250])
                    : null,
                showWhen: true,
                when: scheduledDate.millisecondsSinceEpoch,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: subscription.id,
          );
        } else {
          // Fall back to inexact scheduling
          await _plugin.zonedSchedule(
            id,
            title,
            message,
            tzDate,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                'Subscription reminders',
                channelDescription: 'Notifications for upcoming renewals',
                importance: Importance.max,
                priority: Priority.high,
                category: AndroidNotificationCategory.reminder,
                playSound: playSound,
                enableVibration: enableVibration,
                vibrationPattern: enableVibration
                    ? Int64List.fromList([0, 250, 250, 250])
                    : null,
                showWhen: true,
                when: scheduledDate.millisecondsSinceEpoch,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: subscription.id,
          );
        }
      } catch (e) {
        // If exact scheduling fails, fall back to inexact
        if (canScheduleExact &&
            e.toString().contains('exact_alarms_not_permitted')) {
          canScheduleExact = false;
          // Retry with inexact scheduling
          await _plugin.zonedSchedule(
            id,
            title,
            message,
            tzDate,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                'Subscription reminders',
                channelDescription: 'Notifications for upcoming renewals',
                importance: Importance.max,
                priority: Priority.high,
                category: AndroidNotificationCategory.reminder,
                playSound: playSound,
                enableVibration: enableVibration,
                vibrationPattern: enableVibration
                    ? Int64List.fromList([0, 250, 250, 250])
                    : null,
                showWhen: true,
                when: scheduledDate.millisecondsSinceEpoch,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: subscription.id,
          );
        } else {
          // Re-throw if it's a different error
          rethrow;
        }
      }
    }
  }

  /// Check if exact alarms can be scheduled (Android 12+)
  ///
  /// Note: On Android 12+ (API 31+), SCHEDULE_EXACT_ALARM permission must be
  /// granted by the user through Settings. This permission cannot be requested
  /// programmatically - users must enable it manually in app settings.
  ///
  /// Returns true if we should try exact scheduling (will fall back on error)
  Future<bool> _canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;

    // We'll attempt exact scheduling and catch the error if permission is not granted
    // This is more reliable than trying to check the permission status
    // since permission_handler doesn't directly support SCHEDULE_EXACT_ALARM
    return true;
  }

  @override
  Future<void> cancelForSubscription(String subscriptionId) async {
    final pending = await _plugin.pendingNotificationRequests();
    final matching =
        pending.where((request) => request.payload == subscriptionId);
    for (final request in matching) {
      await _plugin.cancel(request.id);
    }
  }

  @override
  Future<void> syncSubscriptions(List<Subscription> subscriptions) async {
    for (final subscription in subscriptions) {
      await scheduleSubscription(subscription);
    }
  }

  /// Generate a descriptive notification ID that includes subscription and reminder info
  int _notificationId(String subscriptionId, int offset) {
    // Create a more descriptive ID by combining subscription ID hash with offset
    // This ensures uniqueness while being traceable
    final subscriptionHash = subscriptionId.hashCode & 0x7fffffff;
    // Use offset * 10000 to create clear separation between different reminder days
    // This makes it easier to identify which reminder this is for
    return subscriptionHash + (offset * 10000);
  }

  /// Generate a detailed notification title with context
  String _notificationTitle(Subscription subscription, int offset) {
    if (offset == 0) {
      return '${subscription.serviceName} - Renewal Today';
    } else if (offset == 1) {
      return '${subscription.serviceName} - Renews Tomorrow';
    } else {
      return '${subscription.serviceName} - Renewal in $offset Days';
    }
  }

  /// Generate a comprehensive notification message with all relevant details
  String _message(Subscription subscription, int offset) {
    final renewalDate = subscription.renewalDate;
    final formattedDate = _formatDate(renewalDate);
    final formattedTime = _formatTime(renewalDate);
    final cost = _formatCost(subscription);
    final billingCycle = subscription.billingLabel;

    // Build a detailed message with all important information
    final buffer = StringBuffer();

    if (offset == 0) {
      buffer
          .write('Your ${subscription.serviceName} subscription renews today');
    } else if (offset == 1) {
      buffer.write(
          'Your ${subscription.serviceName} subscription renews tomorrow');
    } else {
      buffer.write(
          'Your ${subscription.serviceName} subscription renews in $offset days');
    }

    buffer.write(' on $formattedDate');

    if (formattedTime.isNotEmpty) {
      buffer.write(' at $formattedTime');
    }

    buffer.write('.');

    // Add cost information
    if (subscription.cost > 0) {
      buffer.write('\nAmount: $cost');
      if (subscription.billingCycle != BillingCycle.custom) {
        buffer.write(' ($billingCycle)');
      }
    }

    // Add payment method if available
    if (subscription.paymentMethod.isNotEmpty) {
      buffer.write('\nPayment: ${subscription.paymentMethod}');
    }

    // Add urgency indicator for same-day renewals
    if (offset == 0) {
      buffer.write(
          '\n\nAction required: Check your payment method to avoid service interruption.');
    } else if (offset <= 3) {
      buffer.write('\n\nReminder: Ensure sufficient funds are available.');
    }

    return buffer.toString();
  }

  /// Format date in a user-friendly way
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final targetDate = DateTime(date.year, date.month, date.day);

    if (targetDate == today) {
      return 'Today';
    } else if (targetDate == tomorrow) {
      return 'Tomorrow';
    } else {
      // Format as "Mon, Jan 15" or "Jan 15, 2024" if different year
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      final weekday = weekdays[date.weekday - 1];
      final month = months[date.month - 1];
      final day = date.day;

      if (date.year == now.year) {
        return '$weekday, $month $day';
      } else {
        return '$weekday, $month $day, ${date.year}';
      }
    }
  }

  /// Format time in a user-friendly way
  String _formatTime(DateTime date) {
    // Only show time if it's not midnight (default time)
    if (date.hour == 0 && date.minute == 0) {
      return '';
    }

    final hour = date.hour;
    final minute = date.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');

    return '$displayHour:$displayMinute $period';
  }

  /// Format cost with currency
  String _formatCost(Subscription subscription) {
    final currencyCode = subscription.currencyCode;
    final cost = subscription.cost;

    // Format based on currency
    if (currencyCode == 'USD' ||
        currencyCode == 'CAD' ||
        currencyCode == 'AUD') {
      return '\$${cost.toStringAsFixed(2)}';
    } else if (currencyCode == 'EUR') {
      return '€${cost.toStringAsFixed(2)}';
    } else if (currencyCode == 'GBP') {
      return '£${cost.toStringAsFixed(2)}';
    } else if (currencyCode == 'JPY' || currencyCode == 'KRW') {
      return '${currencyCode} ${cost.toStringAsFixed(0)}';
    } else {
      // For other currencies, show code and amount
      return '${currencyCode} ${cost.toStringAsFixed(2)}';
    }
  }

  /// Test notification - shows immediately for debugging
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    await _plugin.show(
      999999,
      'Test Notification',
      'This is a test notification to verify sound and vibration work.',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Subscription reminders',
          channelDescription: 'Notifications for upcoming renewals',
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
          showWhen: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Get all pending notifications for debugging
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }
}
