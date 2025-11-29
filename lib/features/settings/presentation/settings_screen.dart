import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:subscriptions/core/ads/banner_ad_widget.dart';
import 'package:subscriptions/core/currency/currency_list.dart';
import 'package:subscriptions/core/currency/currency_preferences_provider.dart';
import 'package:subscriptions/core/notifications/notification_service.dart';
import 'package:subscriptions/core/notifications/notification_settings_provider.dart';
import 'package:subscriptions/core/responsive/responsive_helper.dart';
import 'package:subscriptions/features/legal/presentation/privacy_policy_screen.dart';
import 'package:subscriptions/features/legal/presentation/terms_of_service_screen.dart';

import '../../../core/theme/theme_provider.dart';
import '../../advanced/presentation/advanced_features_section.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version}.${packageInfo.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            ResponsiveHelper.spacing(8),
            ResponsiveHelper.spacing(8),
            ResponsiveHelper.spacing(8),
            // Add bottom padding to account for bottom nav bar + safe area
            ResponsiveHelper.spacing(8) // Bottom nav bar height
            ),
        children: [
          _SectionTitle(title: 'Appearance'),
          Card(
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Dark mode'),
                    subtitle: const Text('Toggle dark theme'),
                    value: themeState.brightness == Brightness.dark,
                    onChanged: (_) =>
                        ref.read(themeProvider.notifier).toggleBrightness(),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: ResponsiveHelper.spacing(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Color scheme',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: AppColorScheme.values.map((scheme) {
                            final isSelected = themeState.colorScheme == scheme;
                            return GestureDetector(
                              onTap: () => ref
                                  .read(themeProvider.notifier)
                                  .setColorScheme(scheme),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _getColorForScheme(scheme),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 24,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const BannerAdWidget(),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Currency'),
          const CurrencySettingsSection(),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Notifications'),
          const NotificationSettingsSection(),
          const SizedBox(height: 24),
          const AdvancedFeaturesSection(),
          const SizedBox(height: 24),
          _SectionTitle(title: 'About'),
          Card(
            // margin: EdgeInsets.all(ResponsiveHelper.spacing(8)),
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('App version'),
                    subtitle:
                        Text(_appVersion.isEmpty ? 'Loading...' : _appVersion),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: const Text('Rate app'),
                    onTap: _rateApp,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: const Text('Share app'),
                    onTap: _shareApp,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Legal'),
          Card(
            child: Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PrivacyPolicyScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Terms of Service'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const TermsOfServiceScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const BannerAdWidget(),
        ],
      ),
    );
  }

  Color _getColorForScheme(AppColorScheme scheme) {
    switch (scheme) {
      case AppColorScheme.purple:
        return const Color(0xFF6247EA);
      case AppColorScheme.blue:
        return const Color(0xFF3AA9FF);
      case AppColorScheme.green:
        return const Color.fromARGB(255, 37, 217, 46);
      case AppColorScheme.pink:
        return const Color(0xFFFF7A8A);
      case AppColorScheme.orange:
        return const Color(0xFFFFB347);
      case AppColorScheme.teal:
        return const Color(0xFF25D9B5);
      case AppColorScheme.yellow:
        return const Color(0xFFFFD700);
      case AppColorScheme.red:
        return const Color(0xFFB00020);
      case AppColorScheme.gray:
        return const Color(0xFF808080);
      case AppColorScheme.brown:
        return const Color(0xFF8B4513);
      case AppColorScheme.black:
        return const Color(0xFF000000);
      case AppColorScheme.white:
        return const Color(0xFFFFFFFF);
    }
  }

  Future<void> _rateApp() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Review not available at this time')),
        );
      }
    }
  }

  Future<void> _shareApp() async {
    await Share.share(
      'Check out Subscriptions - Track and manage all your subscriptions in one place!\n\nDownload now!',
      subject: 'Subscriptions App',
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  List<PendingNotificationRequest> _pendingNotifications = [];
  bool _isLoadingPending = false;

  @override
  void initState() {
    super.initState();
    _loadPendingNotifications();
  }

  Future<void> _loadPendingNotifications() async {
    setState(() => _isLoadingPending = true);
    try {
      final notificationService = ref.read(notificationServiceProvider);
      if (notificationService is LocalNotificationService) {
        final pending = await notificationService.getPendingNotifications();
        setState(() {
          _pendingNotifications = pending;
          _isLoadingPending = false;
        });
      }
    } catch (e) {
      setState(() => _isLoadingPending = false);
    }
  }

  Future<void> _testNotification() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      if (notificationService is LocalNotificationService) {
        await notificationService.showTestNotification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test notification sent!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      final granted = await notificationService.requestPermissions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? 'Notification permissions granted'
                  : 'Notification permissions denied',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permissions: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _openSystemSettings() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
      // Open app notification settings
      await openAppSettings();
    } else if (Platform.isIOS) {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(notificationSettingsProvider);
    final settingsNotifier = ref.read(notificationSettingsProvider.notifier);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text('Enable notifications'),
              subtitle: const Text('Allow subscription reminders'),
              value: settings.enabled,
              onChanged: (value) => settingsNotifier.setEnabled(value),
            ),
            if (settings.enabled) ...[
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Sound'),
                subtitle: const Text('Play sound for notifications'),
                value: settings.soundEnabled,
                onChanged: (value) => settingsNotifier.setSoundEnabled(value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Vibration'),
                subtitle: const Text('Vibrate for notifications'),
                value: settings.vibrationEnabled,
                onChanged: (value) =>
                    settingsNotifier.setVibrationEnabled(value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Show badge'),
                subtitle: const Text('Display badge on app icon'),
                value: settings.showBadge,
                onChanged: (value) => settingsNotifier.setShowBadge(value),
              ),
            ],
            // Only show test notification in debug mode
            if (kDebugMode) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Test notification'),
                subtitle: const Text('Send a test notification now (Dev only)'),
                onTap: _testNotification,
              ),
            ],
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.security),
              title: const Text('Request permissions'),
              subtitle: const Text('Request notification permissions'),
              onTap: _requestPermissions,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('System settings'),
              subtitle: const Text('Open system notification settings'),
              onTap: _openSystemSettings,
            ),
            const Divider(height: 1),
            ExpansionTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Pending notifications'),
              subtitle: Text(
                _isLoadingPending
                    ? 'Loading...'
                    : '${_pendingNotifications.length} scheduled',
              ),
              children: [
                if (_isLoadingPending)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_pendingNotifications.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                    child: Text(
                      'No pending notifications',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                  )
                else
                  ..._pendingNotifications.map((notification) {
                    // PendingNotificationRequest doesn't have scheduledDate directly
                    // We'll show the ID and payload instead
                    return ListTile(
                      dense: true,
                      title: Text(notification.title ?? 'No title'),
                      subtitle: Text(notification.body ?? ''),
                      trailing: Text(
                        'ID: ${notification.id}',
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  }),
                Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(8)),
                  child: TextButton.icon(
                    onPressed: _loadPendingNotifications,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CurrencySettingsSection extends ConsumerStatefulWidget {
  const CurrencySettingsSection({super.key});

  @override
  ConsumerState<CurrencySettingsSection> createState() =>
      _CurrencySettingsSectionState();
}

class _CurrencySettingsSectionState
    extends ConsumerState<CurrencySettingsSection> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final currencyNotifier = ref.read(baseCurrencyProvider.notifier);
    final currencyService = ref.watch(currencyConversionServiceProvider);

    final filteredCurrencies = CurrencyList.searchCurrencies(_searchQuery);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Base Currency',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(4)),
                      Text(
                        'All amounts will be converted to this currency',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveHelper.spacing(16),
                    vertical: ResponsiveHelper.spacing(8),
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        CurrencyList.getCurrencyInfo(baseCurrency)?.flag ?? '',
                        style: const TextStyle(fontSize: 20),
                      ),
                      SizedBox(width: ResponsiveHelper.spacing(8)),
                      Text(
                        baseCurrency,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveHelper.spacing(16)),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search currencies...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context)
                    .colorScheme
                    .surfaceVariant
                    .withOpacity(0.3),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
            SizedBox(height: ResponsiveHelper.spacing(16)),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = filteredCurrencies[index];
                  final isSelected = currency.code == baseCurrency;

                  return ListTile(
                    leading: Text(
                      currency.flag ?? '',
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(currency.name),
                    subtitle: Text(currency.code),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    selected: isSelected,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () async {
                      if (!isSelected) {
                        await currencyNotifier.setBaseCurrency(currency.code);
                        // Refresh exchange rates for new base currency
                        await currencyService.refreshRates();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Base currency changed to ${currency.code}. Exchange rates updated.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            ),
            SizedBox(height: ResponsiveHelper.spacing(12)),
            FutureBuilder<double?>(
              future: Future.value(
                currencyService.getExchangeRate('USD'),
              ),
              builder: (context, snapshot) {
                if (snapshot.hasData &&
                    snapshot.data != null &&
                    baseCurrency != 'USD') {
                  final rate = snapshot.data!;
                  return Container(
                    padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceVariant
                          .withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(8)),
                        Expanded(
                          child: Text(
                            '1 USD = ${rate.toStringAsFixed(4)} $baseCurrency',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
