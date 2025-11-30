import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_html/flutter_html.dart';
import '../../../core/ads/banner_ad_widget.dart';
import '../../../core/responsive/responsive_helper.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
            onPressed: () async {
              final policy = await _loadPrivacyPolicy();
              // Extract plain text from HTML for clipboard
              final plainText = policy
                  .replaceAll(RegExp(r'<[^>]*>'), '')
                  .replaceAll('&nbsp;', ' ')
                  .replaceAll('&amp;', '&')
                  .replaceAll('&lt;', '<')
                  .replaceAll('&gt;', '>')
                  .replaceAll('&quot;', '"');
              await Clipboard.setData(ClipboardData(text: plainText));
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

          return SingleChildScrollView(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Html(
                  data: snapshot.data ?? '<p>Privacy Policy not available</p>',
                  style: {
                    'body': Style(
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    'h1': Style(
                      fontSize: FontSize(28),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(bottom: 16, top: 24),
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    'h2': Style(
                      fontSize: FontSize(24),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(bottom: 12, top: 20),
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    'h3': Style(
                      fontSize: FontSize(20),
                      fontWeight: FontWeight.bold,
                      margin: Margins.only(bottom: 8, top: 16),
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    'p': Style(
                      fontSize: FontSize(16),
                      lineHeight: LineHeight(1.6),
                      margin: Margins.only(bottom: 12, top: 8),
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    'ul': Style(
                      margin: Margins.only(bottom: 12, left: 20),
                    ),
                    'li': Style(
                      fontSize: FontSize(16),
                      lineHeight: LineHeight(1.6),
                      margin: Margins.only(bottom: 8),
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    'strong': Style(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    'em': Style(
                      fontStyle: FontStyle.italic,
                    ),
                  },
                ),
                SizedBox(height: ResponsiveHelper.spacing(24)),
                const BannerAdWidget(),
                SizedBox(height: ResponsiveHelper.spacing(16)),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<String> _loadPrivacyPolicy() async {
    return _getEmbeddedPrivacyPolicy();
  }

  String _getEmbeddedPrivacyPolicy() {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
</head>
<body>
<h1>Privacy Policy</h1>

<p><strong>Last Updated: December 2024</strong></p>

<h2>Introduction</h2>

<p>Subscriptions ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.</p>

<h2>Information We Collect</h2>

<h3>Information You Provide</h3>

<ul>
<li><strong>Subscription Data</strong>: Service names, costs, renewal dates, billing cycles, categories, payment methods, and notes you enter manually</li>
<li><strong>Account Information</strong>: Email address and password (for cloud sync features) - stored securely and encrypted</li>
<li><strong>Receipt/Invoice Data</strong>: Images and documents you upload for OCR processing - processed locally on your device</li>
<li><strong>Email Content</strong>: Email messages you choose to scan (only when you explicitly grant permission and provide credentials)</li>
<li><strong>SMS Content</strong>: SMS messages you choose to scan (Android only, only when you explicitly grant permission)</li>
</ul>

<h3>Automatically Collected Information</h3>

<ul>
<li><strong>Device Information</strong>: Device type, operating system version, app version</li>
<li><strong>Usage Data</strong>: App features used, error logs (for debugging)</li>
<li><strong>Analytics</strong>: Anonymous usage statistics to improve app performance</li>
</ul>

<h3>Third-Party Services</h3>

<ul>
<li><strong>Google Mobile Ads</strong>: We use AdMob for advertising. AdMob may collect device identifiers and usage data.</li>
<li><strong>Firebase</strong>: We use Firebase for cloud sync and authentication.</li>
</ul>

<h2>How We Use Your Information</h2>

<p>We use the information we collect to:</p>

<ul>
<li><strong>Provide Core Services</strong>: Manage and track your subscriptions, send reminders, generate analytics</li>
<li><strong>Email/SMS Scanning</strong>: Parse emails and SMS messages to automatically detect subscriptions (only with your explicit permission)</li>
<li><strong>Receipt OCR</strong>: Extract subscription details from receipts and invoices you upload</li>
<li><strong>Cloud Sync</strong>: Synchronize your subscription data across devices (only if you enable this feature)</li>
<li><strong>Improve Services</strong>: Analyze usage patterns to enhance app functionality</li>
<li><strong>Advertising</strong>: Display relevant ads through Google Mobile Ads</li>
</ul>

<h2>Data Storage and Security</h2>

<h3>Local Storage</h3>

<ul>
<li>All subscription data is stored locally on your device using encrypted storage</li>
<li>Email credentials are stored in memory only during active sessions and never persisted</li>
<li>Receipt images are processed locally and not uploaded to our servers</li>
</ul>

<h3>Cloud Storage (Optional)</h3>

<ul>
<li>If you enable cloud sync, your subscription data is stored in Firebase (encrypted at rest)</li>
<li>You can disable cloud sync at any time</li>
<li>You can delete your cloud data at any time through the app settings</li>
</ul>

<h3>Security Measures</h3>

<ul>
<li>Encryption of sensitive data</li>
<li>Secure authentication for cloud sync</li>
<li>No transmission of email/SMS credentials to our servers</li>
<li>Regular security audits</li>
</ul>

<h2>Data Sharing and Disclosure</h2>

<p>We do NOT sell your personal information. We may share data only in these circumstances:</p>

<ul>
<li><strong>With Your Consent</strong>: When you explicitly authorize sharing</li>
<li><strong>Service Providers</strong>: Trusted third parties who assist in operating our app (Firebase, Google Ads) - they are bound by confidentiality agreements</li>
<li><strong>Legal Requirements</strong>: When required by law or to protect our rights</li>
<li><strong>Business Transfers</strong>: In case of merger, acquisition, or sale of assets (with notice to users)</li>
</ul>

<h2>Your Rights and Choices</h2>

<h3>Access and Control</h3>

<ul>
<li><strong>View Your Data</strong>: Access all your subscription data within the app</li>
<li><strong>Edit Data</strong>: Modify or delete any subscription entry</li>
<li><strong>Export Data</strong>: Export your subscription data in standard formats</li>
<li><strong>Delete Account</strong>: Delete all your data (local and cloud) at any time</li>
</ul>

<h3>Permissions</h3>

<ul>
<li><strong>Email Access</strong>: Only used when you explicitly grant permission and provide credentials. You can revoke access at any time.</li>
<li><strong>SMS Access</strong>: Only used when you explicitly grant permission (Android). You can revoke access at any time.</li>
<li><strong>Camera/Photos</strong>: Only used for receipt upload. You can deny this permission.</li>
<li><strong>Notifications</strong>: Used for subscription reminders. You can disable in app settings.</li>
</ul>

<h3>Opt-Out Options</h3>

<ul>
<li>Disable cloud sync</li>
<li>Disable email/SMS scanning</li>
<li>Disable analytics (through device settings)</li>
<li>Disable personalized ads (through device settings)</li>
</ul>

<h2>Children's Privacy</h2>

<p>Our app is not intended for children under 13 years of age. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.</p>

<h2>International Data Transfers</h2>

<p>If you use cloud sync, your data may be stored on servers located outside your country. We ensure appropriate safeguards are in place to protect your data in accordance with this Privacy Policy.</p>

<h2>Data Retention</h2>

<ul>
<li><strong>Local Data</strong>: Stored on your device until you delete it or uninstall the app</li>
<li><strong>Cloud Data</strong>: Retained until you delete your account or disable cloud sync</li>
<li><strong>Email/SMS Credentials</strong>: Not stored - only used during active scanning sessions</li>
<li><strong>Receipt Images</strong>: Processed locally and not retained after processing</li>
</ul>

<h2>Changes to This Privacy Policy</h2>

<p>We may update this Privacy Policy from time to time. We will notify you of any changes by:</p>

<ul>
<li>Posting the new Privacy Policy in the app</li>
<li>Updating the "Last Updated" date</li>
<li>For significant changes, we may provide additional notice</li>
</ul>

<h2>Contact Us</h2>

<p>If you have questions about this Privacy Policy or our data practices, please contact us:</p>

<ul>
<li><strong>Email</strong>: privacy@subscriptions.app</li>
<li><strong>Address</strong>: [Your Company Address]</li>
</ul>

<h2>Compliance</h2>

<p>This Privacy Policy complies with:</p>

<ul>
<li>General Data Protection Regulation (GDPR) - EU users</li>
<li>California Consumer Privacy Act (CCPA) - California users</li>
<li>Children's Online Privacy Protection Act (COPPA) - US users</li>
<li>Other applicable data protection laws</li>
</ul>

<hr>

<p><strong>By using Subscriptions, you acknowledge that you have read and understood this Privacy Policy.</strong></p>
</body>
</html>
''';
  }
}
