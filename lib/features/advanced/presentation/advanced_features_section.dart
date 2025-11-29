import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ads/ad_navigation_helper.dart';
import '../../../core/config/app_config.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
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
            const Divider(height: 1),
            _FeatureTile(
              icon: Icons.email_rounded,
              title: 'Email Scanner',
              subtitle: 'Automatically detect subscriptions from emails (IMAP)',
              enabled: AppConfig.enableEmailScanner,
              configured: true, // Works locally with IMAP - no API keys needed
              onTap: () {
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
              onTap: () {
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
              onTap: () {
                AdNavigationHelper.navigateWithInterstitial(
                  context,
                  const ReceiptUploadScreen(),
                );
              },
            ),
            const Divider(height: 1),
            _FeatureTile(
              icon: Icons.cloud_sync_rounded,
              title: 'Cloud Sync',
              subtitle: 'Sync subscriptions across devices',
              enabled: AppConfig.enableCloudSync,
              configured: AppConfig.isFirebaseConfigured,
              onTap: () {
                if (AppConfig.isFirebaseConfigured) {
                  AdNavigationHelper.navigateWithInterstitial(
                    context,
                    const CloudSyncScreen(),
                  );
                } else {
                  // Show configuration help
                  _showConfigurationDialog(context, 'Cloud Sync',
                      'Cloud Sync requires Firebase configuration. Please set up Firebase in app_config.dart');
                }
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final bool configured;
  final VoidCallback onTap;

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
