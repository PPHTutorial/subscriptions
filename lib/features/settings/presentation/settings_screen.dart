import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

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
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _SectionTitle(title: 'Appearance'),
          Card(
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
                  padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 24),
          const AdvancedFeaturesSection(),
          const SizedBox(height: 24),
          _SectionTitle(title: 'About'),
          Card(
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
