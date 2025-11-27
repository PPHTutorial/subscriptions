import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../data/subscription_repository.dart';
import '../domain/subscription.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository();
});

final subscriptionControllerProvider =
    AsyncNotifierProvider<SubscriptionController, List<Subscription>>(
  SubscriptionController.new,
);

class SubscriptionController extends AsyncNotifier<List<Subscription>> {
  late final SubscriptionRepository _repository;
  late final NotificationService _notifications;

  @override
  Future<List<Subscription>> build() async {
    _repository = ref.read(subscriptionRepositoryProvider);
    _notifications = ref.read(notificationServiceProvider);

    final subscriptions = await _repository.loadSubscriptions();
    await _notifications.syncSubscriptions(subscriptions);

    return subscriptions;
  }

  Future<void> addSubscription(Subscription subscription) async {
    final current = await future;
    final updated = [
      ...current,
      subscription.copyWith(
        accentColor: subscription.accentColor ?? _generateAccent(),
      ),
    ]..sort(_sortByRenewal);

    state = AsyncValue.data(updated);
    await _repository.saveSubscriptions(updated);
    final newEntry =
        updated.firstWhere((element) => element.id == subscription.id);
    await _notifications.scheduleSubscription(newEntry);
  }

  Future<void> removeSubscription(String id) async {
    final current = await future;
    final updated = current
        .where((subscription) => subscription.id != id)
        .toList()
      ..sort(_sortByRenewal);

    state = AsyncValue.data(updated);
    await _repository.saveSubscriptions(updated);
    await _notifications.cancelForSubscription(id);
  }

  Future<void> toggleAutoRenew(String id) async {
    final current = await future;
    final updated = current.map((subscription) {
      if (subscription.id == id) {
        return subscription.copyWith(autoRenew: !subscription.autoRenew);
      }
      return subscription;
    }).toList()
      ..sort(_sortByRenewal);

    state = AsyncValue.data(updated);
    await _repository.saveSubscriptions(updated);
    final updatedSub =
        updated.firstWhere((subscription) => subscription.id == id);
    await _notifications.scheduleSubscription(updatedSub);
  }

  Future<void> updateSubscription(Subscription updatedSubscription) async {
    final current = await future;
    final updated = current.map((subscription) {
      if (subscription.id == updatedSubscription.id) {
        return updatedSubscription;
      }
      return subscription;
    }).toList()
      ..sort(_sortByRenewal);

    state = AsyncValue.data(updated);
    await _repository.saveSubscriptions(updated);
    await _notifications.scheduleSubscription(updatedSubscription);
  }

  int _sortByRenewal(Subscription a, Subscription b) =>
      a.renewalDate.compareTo(b.renewalDate);

  int _generateAccent() {
    final colors = <Color>[
      const Color(0xFF6247EA),
      const Color(0xFF25D9B5),
      const Color(0xFFFF7A8A),
      const Color(0xFF3AA9FF),
      const Color(0xFFFFB347),
    ];
    return colors[Random().nextInt(colors.length)].value;
  }
}

