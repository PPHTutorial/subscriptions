import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ads/ad_navigation_helper.dart';
import '../../../core/config/app_config.dart';
import '../../../core/premium/premium_restrictions.dart';
import '../../../core/premium/premium_screen.dart';
import '../../../core/responsive/responsive_helper.dart';
import '../email_scanner/presentation/email_scanner_screen.dart';
import '../sms_scanner/presentation/sms_scanner_screen.dart';
import '../receipt_ocr/presentation/receipt_upload_screen.dart';
import '../cloud_sync/presentation/cloud_sync_screen.dart';
import '../ai_insights/presentation/ai_insights_screen.dart';

class AdvancedFeaturesSection extends ConsumerWidget {
  const AdvancedFeaturesSection({super.key});

  void _showConfigurationDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showPremiumRequiredDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star_outline_rounded),
            SizedBox(width: 12),
            Expanded(child: Text('Premium Feature')),
          ],
        ),
        content: const Text(
          'This feature is available for Premium users only. Upgrade to unlock all advanced features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PremiumScreen(),
                ),
              );
            },
            child: const Text('Upgrade to Premium'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
              child: Text(
                'Advanced Features',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            _FeatureTile(
              icon: Icons.email_rounded,
              title: 'Email Scanner',
              subtitle: 'Automatically detect subscriptions from emails (IMAP)',
              enabled: AppConfig.enableEmailScanner,
              configured: true, // Works locally with IMAP - no API keys needed
              isPremium: true,
              onTap: () async {
                final isRestricted = await PremiumRestrictions.isRestricted(
                  ref,
                  RestrictionType.advancedFeatures,
                );
                if (isRestricted) {
                  _showPremiumRequiredDialog(context);
                  return;
                }
                AdNavigationHelper.navigateWithInterstitial(
                  context,
                  const EmailScannerScreen(),
                );
              },
            ),
            _FeatureTile(
              icon: Icons.sms_rounded,
              title: 'SMS Scanner',
              subtitle: 'Scan bank alerts for subscription transactions',
              enabled: AppConfig.enableSmsScanner,
              configured: true, // SMS doesn't need API keys
              isPremium: true,
              onTap: () async {
                final isRestricted = await PremiumRestrictions.isRestricted(
                  ref,
                  RestrictionType.advancedFeatures,
                );
                if (isRestricted) {
                  _showPremiumRequiredDialog(context);
                  return;
                }
                AdNavigationHelper.navigateWithInterstitial(
                  context,
                  const SmsScannerScreen(),
                );
              },
            ),
            _FeatureTile(
              icon: Icons.receipt_long_rounded,
              title: 'Receipt Upload',
              subtitle: 'Extract details from receipt images using OCR',
              enabled: AppConfig.enableReceiptUpload,
              configured: true, // OCR uses Google ML Kit (no API key needed)
              isPremium: true,
              onTap: () async {
                final isRestricted = await PremiumRestrictions.isRestricted(
                  ref,
                  RestrictionType.advancedFeatures,
                );
                if (isRestricted) {
                  _showPremiumRequiredDialog(context);
                  return;
                }
                AdNavigationHelper.navigateWithInterstitial(
                  context,
                  const ReceiptUploadScreen(),
                );
              },
            ),
            Divider(
              height: 1,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
            ),
            _FeatureTile(
              icon: Icons.cloud_sync_rounded,
              title: 'Cloud Sync',
              subtitle: 'Sync subscriptions across devices',
              enabled: AppConfig.enableCloudSync,
              configured: AppConfig.isFirebaseConfigured,
              isPremium: true,
              onTap: () async {
                if (!AppConfig.isFirebaseConfigured) {
                  // Show configuration help
                  _showConfigurationDialog(context, 'Cloud Sync',
                      'Cloud Sync requires Firebase configuration. Please set up Firebase in app_config.dart');
                  return;
                }

                final isRestricted = await PremiumRestrictions.isRestricted(
                  ref,
                  RestrictionType.cloudSync,
                );
                if (isRestricted) {
                  _showPremiumRequiredDialog(context);
                  return;
                }

                AdNavigationHelper.navigateWithInterstitial(
                  context,
                  const CloudSyncScreen(),
                );
              },
            ),
            _FeatureTile(
              icon: Icons.psychology_rounded,
              title: 'AI Insights',
              subtitle: 'Get smart recommendations and waste predictions',
              enabled: AppConfig.enableAiInsights,
              configured: true, // Uses local logic, no API keys needed
              onTap: () {
                AdNavigationHelper.navigateWithInterstitial(
                  context,
                  const AiInsightsScreen(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.configured,
    required this.onTap,
    this.isPremium = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool configured;
  final VoidCallback onTap;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: enabled && configured
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
      ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          if (!configured)
            Padding(
              padding: EdgeInsets.only(top: ResponsiveHelper.spacing(4)),
              child: Text(
                'Contact support.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
              ),
            ),
          if (isPremium && configured)
            Padding(
              padding: EdgeInsets.only(top: ResponsiveHelper.spacing(4)),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: ResponsiveHelper.spacing(4)),
                  Text(
                    'Premium',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
      ),
      enabled: enabled && configured,
      onTap: enabled && configured ? onTap : null,
    );
  }
}
