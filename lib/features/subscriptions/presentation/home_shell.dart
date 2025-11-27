import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../application/subscription_controller.dart';
import 'dashboard_screen.dart';
import 'subscriptions_screen.dart';
import 'widgets/add_subscription_sheet.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationServiceProvider).requestPermissions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(onAddTap: _openCreateSheet),
      SubscriptionsScreen(onAddTap: _openCreateSheet),
    ];

    final titles = ['Overview', 'Subscriptions'];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert_rounded),
            tooltip: 'Add subscription',
            onPressed: _openCreateSheet,
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: tabs[_index],
      ),
      bottomNavigationBar: _buildNavBar(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add subscription'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        currentIndex: _index,
        onTap: (value) => setState(() => _index = value),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_graph_rounded),
            label: 'Overview',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.credit_card_rounded),
            label: 'Subscriptions',
          ),
        ],
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final notifier = ref.read(subscriptionControllerProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSubscriptionSheet(
        onSubmit: (subscription) async {
          await notifier.addSubscription(subscription);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}

