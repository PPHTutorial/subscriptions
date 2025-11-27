import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/subscription.dart';

class SubscriptionRepository {
  static const _storageKey = 'subscriptions_store_v1';

  Future<List<Subscription>> loadSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    final data = jsonDecode(raw) as List<dynamic>;
    return data
        .map((entry) => Subscription.fromJson(entry as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSubscriptions(List<Subscription> subscriptions) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = subscriptions
        .map((subscription) => subscription.toJson())
        .toList(growable: false);

    await prefs.setString(_storageKey, jsonEncode(payload));
  }
}

