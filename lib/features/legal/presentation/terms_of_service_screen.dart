import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/responsive/responsive_helper.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
            onPressed: () async {
              final terms = await _loadTermsOfService();
              await Clipboard.setData(ClipboardData(text: terms));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Terms of Service copied to clipboard')),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _loadTermsOfService(),
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
                  Text('Error loading Terms of Service: ${snapshot.error}'),
                ],
              ),
            );
          }

          final formattedText = _formatText(
              context, snapshot.data ?? 'Terms of Service not available');
          return SingleChildScrollView(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
            child: formattedText,
          );
        },
      ),
    );
  }

  Future<String> _loadTermsOfService() async {
    try {
      return _getEmbeddedTermsOfService();
    
    } catch (e) {
      // Fallback to embedded text if file not found
      return _getEmbeddedTermsOfService();
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

  String _getEmbeddedTermsOfService() {
    return '''
# Terms of Service

**Last Updated: December 2024**

## Agreement to Terms

By downloading, installing, accessing, or using the Subscriptions mobile application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.

## Description of Service

Subscriptions is a mobile application that helps users:
- Track and manage subscription services
- Receive reminders for upcoming renewals
- Analyze subscription spending
- Automatically detect subscriptions from emails, SMS, and receipts (optional features)
- Synchronize data across devices (optional feature)

## Eligibility

You must be at least 13 years old to use this App. If you are under 18, you represent that you have your parent's or guardian's permission to use the App.

## User Accounts

### Account Creation

- You may use the App without creating an account (local-only mode)
- Cloud sync features require account creation through Firebase
- You are responsible for maintaining the confidentiality of your account credentials

### Account Security

- You are responsible for all activities that occur under your account
- Notify us immediately of any unauthorized use
- We are not liable for any loss or damage arising from your failure to protect your account

## User Responsibilities

### Acceptable Use

You agree to:
- Use the App only for lawful purposes
- Provide accurate and truthful information
- Not attempt to gain unauthorized access to the App or its systems
- Not interfere with or disrupt the App's functionality
- Not use the App to violate any laws or regulations
- Not reverse engineer, decompile, or disassemble the App

### Prohibited Activities

You agree NOT to:
- Use the App for any illegal or unauthorized purpose
- Transmit any viruses, malware, or harmful code
- Spam, harass, or abuse other users (if applicable)
- Impersonate any person or entity
- Collect or harvest information about other users
- Use automated systems to access the App without permission

## Subscription Data

### Your Data

- You own all data you enter into the App
- You are responsible for the accuracy of your subscription information
- We do not claim ownership of your data

### Data Accuracy

- The App provides tools to help you track subscriptions, but you are responsible for verifying the accuracy of information
- We are not responsible for errors in subscription data you enter or that is extracted from emails/SMS/receipts
- Always verify extracted information before adding subscriptions

## Third-Party Services

### Email and SMS Access

- Email and SMS scanning features require your explicit permission
- You are responsible for ensuring you have the right to access the emails/SMS you scan
- We do not store your email/SMS credentials - they are used only during active scanning sessions
- You grant us permission to process email/SMS content solely for subscription detection

### Cloud Sync

- Cloud sync uses Firebase (Google) services
- Your data is subject to Firebase's terms and privacy policy
- We are not responsible for Firebase service outages or data loss

### Advertising

- The App displays ads through Google Mobile Ads (AdMob)
- Ads are subject to Google's advertising policies
- We are not responsible for ad content or user interactions with ads

## Intellectual Property

### Our Rights

- The App, including its design, features, and content, is owned by us or our licensors
- All trademarks, logos, and service marks are our property or their respective owners
- You may not copy, modify, distribute, or create derivative works without permission

### Your Rights

- You retain ownership of data you create or upload
- You grant us a license to use your data to provide the App's services

## Disclaimers

### Service Availability

- We strive to provide reliable service but do not guarantee uninterrupted or error-free operation
- The App may be unavailable due to maintenance, updates, or technical issues
- We reserve the right to modify or discontinue features at any time

### Accuracy Disclaimer

- Subscription information extracted from emails, SMS, or receipts may contain errors
- We do not guarantee the accuracy of automatically extracted data
- Always verify extracted information before relying on it

### Financial Disclaimer

- The App is a tracking tool and does not provide financial advice
- We are not responsible for subscription charges, renewals, or cancellations
- You are solely responsible for managing your subscriptions and payments

### No Warranty

THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.

## Limitation of Liability

TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR:
- Any indirect, incidental, special, consequential, or punitive damages
- Loss of profits, revenue, data, or use
- Errors or omissions in subscription information
- Unauthorized access to or alteration of your data
- Any damages exceeding the amount you paid for the App (if any)

## Indemnification

You agree to indemnify and hold us harmless from any claims, damages, losses, liabilities, and expenses (including legal fees) arising from:
- Your use of the App
- Your violation of these Terms
- Your violation of any rights of another party
- Your violation of any applicable laws

## Termination

### By You

- You may stop using the App at any time
- You may delete your account and data through app settings
- Uninstalling the App will remove local data (unless you have cloud sync enabled)

### By Us

We may terminate or suspend your access to the App immediately, without prior notice, for:
- Violation of these Terms
- Fraudulent or illegal activity
- Extended periods of inactivity
- At our sole discretion

## Changes to Terms

We reserve the right to modify these Terms at any time. We will:
- Post updated Terms in the App
- Update the "Last Updated" date
- For significant changes, provide additional notice

Your continued use of the App after changes constitutes acceptance of the new Terms.

## Governing Law

These Terms shall be governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to its conflict of law provisions.

## Dispute Resolution

### Informal Resolution

If you have a dispute, please contact us first to attempt informal resolution.

### Arbitration

Any disputes that cannot be resolved informally shall be resolved through binding arbitration in accordance with applicable rules, except where prohibited by law.

## Severability

If any provision of these Terms is found to be unenforceable, the remaining provisions will remain in full effect.

## Entire Agreement

These Terms, together with our Privacy Policy, constitute the entire agreement between you and us regarding the App.

## Contact Information

If you have questions about these Terms, please contact us:

- **Email**: legal@subscriptions.app
- **Address**: [Your Company Address]

## Acknowledgment

BY USING THE APP, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THESE TERMS OF SERVICE.

---

**Effective Date: December 2024**
''';
  }
}
