import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subscriptions/core/notifications/notification_service.dart';
import 'package:subscriptions/features/subscriptions/domain/subscription.dart';
import 'package:subscriptions/main.dart';

void main() {
  testWidgets('Subscriptions dashboard renders', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            _FakeNotificationService(),
          ),
        ],
        child: const SubscriptionsApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Add subscription'), findsWidgets);
  });
}

class _FakeNotificationService implements NotificationService {
  @override
  Future<void> cancelForSubscription(String subscriptionId) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> scheduleSubscription(Subscription subscription) async {}

  @override
  Future<void> syncSubscriptions(List<Subscription> subscriptions) async {}
}
