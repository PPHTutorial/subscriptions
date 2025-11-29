import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_html/flutter_html.dart';
import '../../../core/ads/banner_ad_widget.dart';
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
              // Extract plain text from HTML for clipboard
              final plainText = terms
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

          return SingleChildScrollView(
            padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Html(
                  data:
                      snapshot.data ?? '<p>Terms of Service not available</p>',
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

  Future<String> _loadTermsOfService() async {
    return _getEmbeddedTermsOfService();
  }

  String _getEmbeddedTermsOfService() {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
</head>
<body>
<h1>Terms of Service</h1>

<p><strong>Last Updated: December 2024</strong></p>

<h2>Agreement to Terms</h2>

<p>By downloading, installing, accessing, or using the Subscriptions mobile application ("App"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree to these Terms, do not use the App.</p>

<h2>Description of Service</h2>

<p>Subscriptions is a mobile application that helps users:</p>

<ul>
<li>Track and manage subscription services</li>
<li>Receive reminders for upcoming renewals</li>
<li>Analyze subscription spending</li>
<li>Automatically detect subscriptions from emails, SMS, and receipts (optional features)</li>
<li>Synchronize data across devices (optional feature)</li>
</ul>

<h2>Eligibility</h2>

<p>You must be at least 13 years old to use this App. If you are under 18, you represent that you have your parent's or guardian's permission to use the App.</p>

<h2>User Accounts</h2>

<h3>Account Creation</h3>

<ul>
<li>You may use the App without creating an account (local-only mode)</li>
<li>Cloud sync features require account creation through Firebase</li>
<li>You are responsible for maintaining the confidentiality of your account credentials</li>
</ul>

<h3>Account Security</h3>

<ul>
<li>You are responsible for all activities that occur under your account</li>
<li>Notify us immediately of any unauthorized use</li>
<li>We are not liable for any loss or damage arising from your failure to protect your account</li>
</ul>

<h2>User Responsibilities</h2>

<h3>Acceptable Use</h3>

<p>You agree to:</p>

<ul>
<li>Use the App only for lawful purposes</li>
<li>Provide accurate and truthful information</li>
<li>Not attempt to gain unauthorized access to the App or its systems</li>
<li>Not interfere with or disrupt the App's functionality</li>
<li>Not use the App to violate any laws or regulations</li>
<li>Not reverse engineer, decompile, or disassemble the App</li>
</ul>

<h3>Prohibited Activities</h3>

<p>You agree NOT to:</p>

<ul>
<li>Use the App for any illegal or unauthorized purpose</li>
<li>Transmit any viruses, malware, or harmful code</li>
<li>Spam, harass, or abuse other users (if applicable)</li>
<li>Impersonate any person or entity</li>
<li>Collect or harvest information about other users</li>
<li>Use automated systems to access the App without permission</li>
</ul>

<h2>Subscription Data</h2>

<h3>Your Data</h3>

<ul>
<li>You own all data you enter into the App</li>
<li>You are responsible for the accuracy of your subscription information</li>
<li>We do not claim ownership of your data</li>
</ul>

<h3>Data Accuracy</h3>

<ul>
<li>The App provides tools to help you track subscriptions, but you are responsible for verifying the accuracy of information</li>
<li>We are not responsible for errors in subscription data you enter or that is extracted from emails/SMS/receipts</li>
<li>Always verify extracted information before adding subscriptions</li>
</ul>

<h2>Third-Party Services</h2>

<h3>Email and SMS Access</h3>

<ul>
<li>Email and SMS scanning features require your explicit permission</li>
<li>You are responsible for ensuring you have the right to access the emails/SMS you scan</li>
<li>We do not store your email/SMS credentials - they are used only during active scanning sessions</li>
<li>You grant us permission to process email/SMS content solely for subscription detection</li>
</ul>

<h3>Cloud Sync</h3>

<ul>
<li>Cloud sync uses Firebase (Google) services</li>
<li>Your data is subject to Firebase's terms and privacy policy</li>
<li>We are not responsible for Firebase service outages or data loss</li>
</ul>

<h3>Advertising</h3>

<ul>
<li>The App displays ads through Google Mobile Ads (AdMob)</li>
<li>Ads are subject to Google's advertising policies</li>
<li>We are not responsible for ad content or user interactions with ads</li>
</ul>

<h2>Intellectual Property</h2>

<h3>Our Rights</h3>

<ul>
<li>The App, including its design, features, and content, is owned by us or our licensors</li>
<li>All trademarks, logos, and service marks are our property or their respective owners</li>
<li>You may not copy, modify, distribute, or create derivative works without permission</li>
</ul>

<h3>Your Rights</h3>

<ul>
<li>You retain ownership of data you create or upload</li>
<li>You grant us a license to use your data to provide the App's services</li>
</ul>

<h2>Disclaimers</h2>

<h3>Service Availability</h3>

<ul>
<li>We strive to provide reliable service but do not guarantee uninterrupted or error-free operation</li>
<li>The App may be unavailable due to maintenance, updates, or technical issues</li>
<li>We reserve the right to modify or discontinue features at any time</li>
</ul>

<h3>Accuracy Disclaimer</h3>

<ul>
<li>Subscription information extracted from emails, SMS, or receipts may contain errors</li>
<li>We do not guarantee the accuracy of automatically extracted data</li>
<li>Always verify extracted information before relying on it</li>
</ul>

<h3>Financial Disclaimer</h3>

<ul>
<li>The App is a tracking tool and does not provide financial advice</li>
<li>We are not responsible for subscription charges, renewals, or cancellations</li>
<li>You are solely responsible for managing your subscriptions and payments</li>
</ul>

<h3>No Warranty</h3>

<p>THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.</p>

<h2>Limitation of Liability</h2>

<p>TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR:</p>

<ul>
<li>Any indirect, incidental, special, consequential, or punitive damages</li>
<li>Loss of profits, revenue, data, or use</li>
<li>Errors or omissions in subscription information</li>
<li>Unauthorized access to or alteration of your data</li>
<li>Any damages exceeding the amount you paid for the App (if any)</li>
</ul>

<h2>Indemnification</h2>

<p>You agree to indemnify and hold us harmless from any claims, damages, losses, liabilities, and expenses (including legal fees) arising from:</p>

<ul>
<li>Your use of the App</li>
<li>Your violation of these Terms</li>
<li>Your violation of any rights of another party</li>
<li>Your violation of any applicable laws</li>
</ul>

<h2>Termination</h2>

<h3>By You</h3>

<ul>
<li>You may stop using the App at any time</li>
<li>You may delete your account and data through app settings</li>
<li>Uninstalling the App will remove local data (unless you have cloud sync enabled)</li>
</ul>

<h3>By Us</h3>

<p>We may terminate or suspend your access to the App immediately, without prior notice, for:</p>

<ul>
<li>Violation of these Terms</li>
<li>Fraudulent or illegal activity</li>
<li>Extended periods of inactivity</li>
<li>At our sole discretion</li>
</ul>

<h2>Changes to Terms</h2>

<p>We reserve the right to modify these Terms at any time. We will:</p>

<ul>
<li>Post updated Terms in the App</li>
<li>Update the "Last Updated" date</li>
<li>For significant changes, provide additional notice</li>
</ul>

<p>Your continued use of the App after changes constitutes acceptance of the new Terms.</p>

<h2>Governing Law</h2>

<p>These Terms shall be governed by and construed in accordance with the laws of [Your Jurisdiction], without regard to its conflict of law provisions.</p>

<h2>Dispute Resolution</h2>

<h3>Informal Resolution</h3>

<p>If you have a dispute, please contact us first to attempt informal resolution.</p>

<h3>Arbitration</h3>

<p>Any disputes that cannot be resolved informally shall be resolved through binding arbitration in accordance with applicable rules, except where prohibited by law.</p>

<h2>Severability</h2>

<p>If any provision of these Terms is found to be unenforceable, the remaining provisions will remain in full effect.</p>

<h2>Entire Agreement</h2>

<p>These Terms, together with our Privacy Policy, constitute the entire agreement between you and us regarding the App.</p>

<h2>Contact Information</h2>

<p>If you have questions about these Terms, please contact us:</p>

<ul>
<li><strong>Email</strong>: legal@subscriptions.app</li>
<li><strong>Address</strong>: [Your Company Address]</li>
</ul>

<h2>Acknowledgment</h2>

<p>BY USING THE APP, YOU ACKNOWLEDGE THAT YOU HAVE READ, UNDERSTOOD, AND AGREE TO BE BOUND BY THESE TERMS OF SERVICE.</p>

<hr>

<p><strong>Effective Date: December 2024</strong></p>
</body>
</html>
''';
  }
}
