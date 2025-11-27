import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone_updated_gradle/flutter_native_timezone.dart';
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
    try {
      final timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

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

    for (final offset in subscription.reminderDays) {
      final scheduledDate =
          subscription.renewalDate.subtract(Duration(days: offset));
      if (scheduledDate.isBefore(DateTime.now())) continue;

      final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);
      final id = _notificationId(subscription.id, offset);

      await _plugin.zonedSchedule(
        id,
        '${subscription.serviceName} renews soon',
        _message(subscription, offset),
        tzDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Subscription reminders',
            channelDescription: 'Notifications for upcoming renewals',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
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
    }
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

  int _notificationId(String subscriptionId, int offset) {
    final base = subscriptionId.hashCode & 0x7fffffff;
    return base + offset;
  }

  String _message(Subscription subscription, int offset) {
    if (offset == 0) {
      return '${subscription.serviceName} renews today.';
    }
    final suffix = offset == 1 ? 'day' : 'days';
    return '${subscription.serviceName} renews in $offset $suffix.';
  }
}
