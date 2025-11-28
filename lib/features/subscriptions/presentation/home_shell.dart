import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:subscriptions/core/responsive/responsive_helper.dart';

import '../../../core/ads/ad_navigation_helper.dart';
import '../../../core/notifications/notification_service.dart';
import '../../settings/presentation/settings_screen.dart';
import '../application/subscription_controller.dart';
import '../presentation/widgets/sort_filter_bar.dart';
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
  SortOption _sortOption = SortOption.renewalDate;
  bool _showTrialsOnly = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationServiceProvider).requestPermissions(),
    );
    // Show app open ad when navigating to this screen
    Future.microtask(() => AdNavigationHelper.showAppOpenAd());
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(onAddTap: _openCreateSheet),
      SubscriptionsScreen(
        onAddTap: _openCreateSheet,
        sortOption: _sortOption,
        onSortChanged: (option) => setState(() => _sortOption = option),
        showTrialsOnly: _showTrialsOnly,
        onTrialsFilterChanged: (value) =>
            setState(() => _showTrialsOnly = value),
      ),
      const SettingsScreen(),
    ];

    final titles = ['Overview', 'Subscriptions', 'Settings'];

    return Scaffold(
      extendBody:
          false, // Changed to false so content doesn't hide behind bottom nav
      extendBodyBehindAppBar:
          false, // Ensure AppBar doesn't extend behind status bar
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          if (_index == 1) ...[
            // Sort menu for subscriptions screen
            PopupMenuButton<SortOption>(
              icon: const Icon(Icons.sort_rounded),
              tooltip: 'Sort',
              initialValue: _sortOption,
              onSelected: (option) => setState(() => _sortOption = option),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: SortOption.renewalDate,
                  child: Row(
                    children: [
                      Icon(Icons.event_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Renewal date'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: SortOption.price,
                  child: Row(
                    children: [
                      Icon(Icons.attach_money_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Price'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: SortOption.category,
                  child: Row(
                    children: [
                      Icon(Icons.category_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Category'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: SortOption.name,
                  child: Row(
                    children: [
                      Icon(Icons.sort_by_alpha_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Name'),
                    ],
                  ),
                ),
              ],
            ),
            // Filter menu for subscriptions screen
            PopupMenuButton(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: 'Filter',
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: StatefulBuilder(
                    builder: (context, setState) => CheckboxListTile(
                      title: const Text('Trials only'),
                      value: _showTrialsOnly,
                      onChanged: (value) {
                        setState(() => _showTrialsOnly = value ?? false);
                        this.setState(() {});
                        Navigator.pop(context);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ],
          IconButton(
            icon: const Icon(Icons.add_rounded),
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
      /* floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('Add subscription'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, */
    );
  }

  Widget _buildNavBar(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color:
            theme.bottomNavigationBarTheme.backgroundColor?.withOpacity(0.95) ??
                Colors.white.withOpacity(0.95),
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
      child: Padding(
        padding: EdgeInsets.only(top: ResponsiveHelper.spacing(8)),
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
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateSheet() async {
    final notifier = ref.read(subscriptionControllerProvider.notifier);

    // Show interstitial ad before opening the sheet
    await AdNavigationHelper.showModalBottomSheetWithInterstitial(
      context,
      (_) => AddSubscriptionSheet(
        onSubmit: (subscription) async {
          await notifier.addSubscription(subscription);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
