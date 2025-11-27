import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/subscriptions/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = LocalNotificationService();
  await notificationService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(notificationService),
      ],
      child: const SubscriptionsApp(),
    ),
  );
}

class SubscriptionsApp extends StatelessWidget {
  const SubscriptionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subscriptions',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const HomeShell(),
    );
  }
}
