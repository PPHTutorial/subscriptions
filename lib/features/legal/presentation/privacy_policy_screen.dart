import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/responsive/responsive_helper.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
            onPressed: () async {
              final policy = await _loadPrivacyPolicy();
              await Clipboard.setData(ClipboardData(text: policy));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Privacy Policy copied to clipboard')),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _loadPrivacyPolicy(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading Privacy Policy: ${snapshot.error}'),
                ],
              ),
            );
          }

          final formattedText = _formatText(
              context, snapshot.data ?? 'Privacy Policy not available');
          return SingleChildScrollView(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
            child: formattedText,
          );
        },
      ),
    );
  }

  Future<String> _loadPrivacyPolicy() async {
    try {
      return _getEmbeddedPrivacyPolicy();
    } catch (e) {
      // Fallback to embedded text if file not found
      return _getEmbeddedPrivacyPolicy();
    }
  }

  Widget _formatText(BuildContext context, String markdown) {
    // Convert markdown to formatted Flutter widgets with proper paragraphing
    final lines = markdown.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }

      // Headers
      if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: SelectableText(
              line.substring(4),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 10),
            child: SelectableText(
              line.substring(3),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        );
      } else if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: SelectableText(
              line.substring(2),
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        );
      }
      // Bullet points
      else if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: SelectableText(
                    _removeMarkdownFormatting(line.substring(2)),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Regular paragraphs
      else {
        final cleanText = _removeMarkdownFormatting(line);
        if (cleanText.isNotEmpty && !cleanText.startsWith('---')) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: SelectableText(
                cleanText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _removeMarkdownFormatting(String text) {
    return text
        .replaceAll(RegExp(r'\*\*(.+?)\*\*', dotAll: true), r'$1') // Bold
        .replaceAll(RegExp(r'\*(.+?)\*', dotAll: true), r'$1') // Italic
        .replaceAll(RegExp(r'\[(.+?)\]\(.+?\)', dotAll: true), r'$1') // Links
        .replaceAll(RegExp(r'`(.+?)`', dotAll: true), r'$1') // Inline code
        .trim();
  }

  String _getEmbeddedPrivacyPolicy() {
    return '''
# Privacy Policy

**Last Updated: December 2024**

## Introduction

Subscriptions ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.

## Information We Collect

### Information You Provide

- **Subscription Data**: Service names, costs, renewal dates, billing cycles, categories, payment methods, and notes you enter manually
- **Account Information**: Email address and password (for cloud sync features) - stored securely and encrypted
- **Receipt/Invoice Data**: Images and documents you upload for OCR processing - processed locally on your device
- **Email Content**: Email messages you choose to scan (only when you explicitly grant permission and provide credentials)
- **SMS Content**: SMS messages you choose to scan (Android only, only when you explicitly grant permission)

### Automatically Collected Information

- **Device Information**: Device type, operating system version, app version
- **Usage Data**: App features used, error logs (for debugging)
- **Analytics**: Anonymous usage statistics to improve app performance

### Third-Party Services

- **Google Mobile Ads**: We use AdMob for advertising. AdMob may collect device identifiers and usage data.
- **Firebase**: We use Firebase for cloud sync and authentication.

## How We Use Your Information

We use the information we collect to:

- **Provide Core Services**: Manage and track your subscriptions, send reminders, generate analytics
- **Email/SMS Scanning**: Parse emails and SMS messages to automatically detect subscriptions (only with your explicit permission)
- **Receipt OCR**: Extract subscription details from receipts and invoices you upload
- **Cloud Sync**: Synchronize your subscription data across devices (only if you enable this feature)
- **Improve Services**: Analyze usage patterns to enhance app functionality
- **Advertising**: Display relevant ads through Google Mobile Ads

## Data Storage and Security

### Local Storage

- All subscription data is stored locally on your device using encrypted storage
- Email credentials are stored in memory only during active sessions and never persisted
- Receipt images are processed locally and not uploaded to our servers

### Cloud Storage (Optional)

- If you enable cloud sync, your subscription data is stored in Firebase (encrypted at rest)
- You can disable cloud sync at any time
- You can delete your cloud data at any time through the app settings

### Security Measures

- Encryption of sensitive data
- Secure authentication for cloud sync
- No transmission of email/SMS credentials to our servers
- Regular security audits

## Data Sharing and Disclosure

We do **NOT** sell your personal information. We may share data only in these circumstances:

- **With Your Consent**: When you explicitly authorize sharing
- **Service Providers**: Trusted third parties who assist in operating our app (Firebase, Google Ads) - they are bound by confidentiality agreements
- **Legal Requirements**: When required by law or to protect our rights
- **Business Transfers**: In case of merger, acquisition, or sale of assets (with notice to users)

## Your Rights and Choices

### Access and Control

- **View Your Data**: Access all your subscription data within the app
- **Edit Data**: Modify or delete any subscription entry
- **Export Data**: Export your subscription data in standard formats
- **Delete Account**: Delete all your data (local and cloud) at any time

### Permissions

- **Email Access**: Only used when you explicitly grant permission and provide credentials. You can revoke access at any time.
- **SMS Access**: Only used when you explicitly grant permission (Android). You can revoke access at any time.
- **Camera/Photos**: Only used for receipt upload. You can deny this permission.
- **Notifications**: Used for subscription reminders. You can disable in app settings.

### Opt-Out Options

- Disable cloud sync
- Disable email/SMS scanning
- Disable analytics (through device settings)
- Disable personalized ads (through device settings)

## Children's Privacy

Our app is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.

## International Data Transfers

If you use cloud sync, your data may be stored on servers located outside your country. We ensure appropriate safeguards are in place to protect your data in accordance with this Privacy Policy.

## Data Retention

- **Local Data**: Stored on your device until you delete it or uninstall the app
- **Cloud Data**: Retained until you delete your account or disable cloud sync
- **Email/SMS Credentials**: Not stored - only used during active scanning sessions
- **Receipt Images**: Processed locally and not retained after processing

## Changes to This Privacy Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by:
- Posting the new Privacy Policy in the app
- Updating the "Last Updated" date
- For significant changes, we may provide additional notice

## Contact Us

If you have questions about this Privacy Policy or our data practices, please contact us:

- **Email**: privacy@subscriptions.app
- **Address**: [Your Company Address]

## Compliance

This Privacy Policy complies with:
- General Data Protection Regulation (GDPR) - EU users
- California Consumer Privacy Act (CCPA) - California users
- Children's Online Privacy Protection Act (COPPA) - US users
- Other applicable data protection laws

---

**By using Subscriptions, you acknowledge that you have read and understood this Privacy Policy.**
''';
  }
}
