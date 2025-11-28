import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/config/app_config.dart';
import '../../../../core/services/vercel_proxy_service.dart';
import '../domain/email_provider.dart';
import '../domain/email_subscription_match.dart';
import '../../../subscriptions/domain/subscription.dart';
import 'imap_email_scanner_service.dart';

/// Service for scanning emails to detect subscriptions
/// Uses IMAP/POP3 for local access - no OAuth client ID required
/// Works with any email provider that supports IMAP/POP3
class EmailScannerService {
  final EmailProvider provider;
  ImapEmailScannerService? _imapService;
  String? _accessToken;
  String? _refreshToken;
  bool _useImap = true; // Default to IMAP for local access

  EmailScannerService(this.provider) {
    _imapService = ImapEmailScannerService(provider);
  }

  /// Set email credentials for IMAP connection
  /// This is the preferred method - works locally without OAuth
  void setCredentials({
    required String email,
    required String password,
    String? customImapServer,
    int? customImapPort,
    bool? useSsl,
  }) {
    _imapService?.setCredentials(
      email: email,
      password: password,
      customImapServer: customImapServer,
      customImapPort: customImapPort,
      useSsl: useSsl,
    );
  }

  /// Authenticate with email provider
  /// Uses IMAP by default for local access
  Future<bool> authenticate() async {
    try {
      if (_useImap && _imapService != null) {
        return await _imapService!.connect();
      } else {
        // Fallback to OAuth (requires Vercel proxy)
        switch (provider) {
          case EmailProvider.gmail:
            return await _authenticateGmail();
          case EmailProvider.outlook:
            return await _authenticateOutlook();
        }
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> _authenticateGmail() async {
    if (!AppConfig.isVercelProxyConfigured) {
      throw Exception('Vercel proxy not configured. Use IMAP instead.');
    }

    // OAuth flow - only used if IMAP is not available
    // For production, prefer IMAP for scalability
    return false;
  }

  Future<bool> _authenticateOutlook() async {
    if (!AppConfig.isVercelProxyConfigured) {
      throw Exception('Vercel proxy not configured. Use IMAP instead.');
    }

    // OAuth flow - only used if IMAP is not available
    // For production, prefer IMAP for scalability
    return false;
  }

  /// Scan emails for subscription-related content
  /// Uses IMAP by default for local access
  Future<List<EmailSubscriptionMatch>> scanEmails({
    int maxResults = 50,
    DateTime? since,
    String folder = 'INBOX',
  }) async {
    try {
      if (_useImap && _imapService != null) {
        // Use IMAP for local access
        return await _imapService!.scanEmails(
          maxResults: maxResults,
          since: since,
          folder: folder,
        );
      } else {
        // Fallback to OAuth API (requires Vercel proxy)
        if (_accessToken == null) {
          throw Exception('Not authenticated. Call authenticate() first.');
        }

        final emails = await _fetchEmails(maxResults: maxResults, since: since);
        final matches = <EmailSubscriptionMatch>[];

        for (final email in emails) {
          final match = _parseEmailForSubscription(email);
          if (match != null) {
            matches.add(match);
          }
        }

        return matches;
      }
    } catch (e) {
      throw Exception('Failed to scan emails: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEmails({
    required int maxResults,
    DateTime? since,
  }) async {
    switch (provider) {
      case EmailProvider.gmail:
        return await _fetchGmailEmails(maxResults: maxResults, since: since);
      case EmailProvider.outlook:
        return await _fetchOutlookEmails(maxResults: maxResults, since: since);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchGmailEmails({
    required int maxResults,
    DateTime? since,
  }) async {
    // OAuth API - only used if IMAP is not available
    if (!AppConfig.isVercelProxyConfigured) {
      throw Exception('Use IMAP for local access. OAuth requires Vercel proxy.');
    }
    
    try {
      final result = await VercelProxyService.scanEmails(
        provider: 'gmail',
        accessToken: _accessToken!,
        maxResults: maxResults,
        since: since,
      );
      return List<Map<String, dynamic>>.from(result['emails'] ?? []);
    } catch (e) {
      throw Exception('Failed to fetch Gmail messages via proxy: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchOutlookEmails({
    required int maxResults,
    DateTime? since,
  }) async {
    // OAuth API - only used if IMAP is not available
    final url = Uri.parse(
      'https://graph.microsoft.com/v1.0/me/messages?'
      '\$top=$maxResults&'
      '\$orderby=receivedDateTime desc',
    );

    if (since != null) {
      final sinceStr = since.toIso8601String();
      url.replace(queryParameters: {
        ...url.queryParameters,
        '\$filter': 'receivedDateTime ge $sinceStr',
      });
    }

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $_accessToken'},
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch Outlook messages: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    return List<Map<String, dynamic>>.from(data['value'] ?? []);
  }

  String _buildGmailQuery({DateTime? since}) {
    final queries = <String>[
      'subject:("subscription" OR "renewal" OR "payment" OR "trial" OR "billing")',
    ];

    if (since != null) {
      final sinceSeconds = since.millisecondsSinceEpoch ~/ 1000;
      queries.add('after:$sinceSeconds');
    }

    return queries.join(' ');
  }

  EmailSubscriptionMatch? _parseEmailForSubscription(
      Map<String, dynamic> email) {
    final subject = _extractSubject(email);
    final body = _extractBody(email);
    final date = _extractDate(email);

    if (subject == null && body == null) return null;

    final text = '${subject ?? ''} ${body ?? ''}'.toLowerCase();

    // Check for subscription-related keywords
    if (!_containsSubscriptionKeywords(text)) {
      return null;
    }

    // Extract service name
    final serviceName = _extractServiceName(subject, body);
    if (serviceName == null) return null;

    // Extract cost
    final costMatch = _extractCost(text);
    if (costMatch == null) return null;

    // Extract renewal date
    final renewalDate = _extractRenewalDate(text, date);
    if (renewalDate == null) return null;

    // Extract billing cycle
    final billingCycle = _extractBillingCycle(text);

    // Calculate confidence
    final confidence = _calculateConfidence(
      serviceName: serviceName,
      cost: costMatch['cost'],
      renewalDate: renewalDate,
    );

    return EmailSubscriptionMatch(
      serviceName: serviceName,
      cost: costMatch['cost'] as double,
      currencyCode: costMatch['currency'] as String,
      renewalDate: renewalDate,
      billingCycle: billingCycle,
      confidence: confidence,
      category: _inferCategory(serviceName),
      paymentMethod: _extractPaymentMethod(text),
      emailSubject: subject,
      emailDate: date,
    );
  }

  String? _extractSubject(Map<String, dynamic> email) {
    switch (provider) {
      case EmailProvider.gmail:
        final payload = email['payload'];
        final headers = payload?['headers'] as List?;
        final subjectHeader = headers?.firstWhere(
          (h) => h['name'] == 'Subject',
          orElse: () => null,
        );
        return subjectHeader?['value'] as String?;
      case EmailProvider.outlook:
        return email['subject'] as String?;
    }
  }

  String? _extractBody(Map<String, dynamic> email) {
    switch (provider) {
      case EmailProvider.gmail:
        final payload = email['payload'];
        final parts = payload?['parts'] as List?;
        if (parts == null || parts.isEmpty) {
          return payload?['body']?['data'] as String?;
        }
        // Get text/plain part
        for (final part in parts) {
          if (part['mimeType'] == 'text/plain') {
            final data = part['body']?['data'] as String?;
            if (data != null) {
              return utf8.decode(base64Url.decode(data));
            }
          }
        }
        return null;
      case EmailProvider.outlook:
        return email['body']?['content'] as String?;
    }
  }

  DateTime? _extractDate(Map<String, dynamic> email) {
    switch (provider) {
      case EmailProvider.gmail:
        final payload = email['payload'];
        final headers = payload?['headers'] as List?;
        final dateHeader = headers?.firstWhere(
          (h) => h['name'] == 'Date',
          orElse: () => null,
        );
        final dateStr = dateHeader?['value'] as String?;
        return dateStr != null ? DateTime.tryParse(dateStr) : null;
      case EmailProvider.outlook:
        final dateStr = email['receivedDateTime'] as String?;
        return dateStr != null ? DateTime.tryParse(dateStr) : null;
    }
  }

  bool _containsSubscriptionKeywords(String text) {
    final keywords = [
      'subscription',
      'renewal',
      'renew',
      'payment',
      'billing',
      'trial',
      'expires',
      'expiring',
      'charge',
      'charged',
      'invoice',
      'receipt',
    ];
    return keywords.any((keyword) => text.contains(keyword));
  }

  String? _extractServiceName(String? subject, String? body) {
    final text = '${subject ?? ''} ${body ?? ''}';

    // Common service names
    final services = [
      'netflix',
      'spotify',
      'amazon prime',
      'disney',
      'hulu',
      'hbo',
      'apple music',
      'youtube premium',
      'adobe',
      'microsoft',
      'office 365',
      'dropbox',
      'icloud',
      'google drive',
      'grammarly',
      'canva',
      'notion',
      'figma',
      'slack',
      'zoom',
      'linkedin',
      'github',
      'aws',
      'azure',
    ];

    for (final service in services) {
      if (text.toLowerCase().contains(service)) {
        // Capitalize properly
        return service.split(' ').map((word) {
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
      }
    }

    // Try to extract from subject
    if (subject != null) {
      // Remove common prefixes
      final cleaned = subject
          .replaceAll(RegExp(r'^(re|fwd?):\s*', caseSensitive: false), '')
          .trim();
      if (cleaned.isNotEmpty && cleaned.length < 50) {
        return cleaned;
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractCost(String text) {
    // Match currency patterns: $9.99, €10.00, £5.99, 9.99 USD, etc.
    final patterns = [
      RegExp(r'[\$€£¥₹]?\s*(\d+\.?\d*)\s*([A-Z]{3})?', caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*(USD|EUR|GBP|INR|GHS|NGN)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final amount = double.tryParse(match.group(1) ?? '');
        if (amount != null && amount > 0) {
          String currency = 'USD';
          if (match.groupCount >= 2 && match.group(2) != null) {
            currency = match.group(2)!.toUpperCase();
          } else if (text.contains('\$')) {
            currency = 'USD';
          } else if (text.contains('€')) {
            currency = 'EUR';
          } else if (text.contains('£')) {
            currency = 'GBP';
          }
          return {'cost': amount, 'currency': currency};
        }
      }
    }
    return null;
  }

  DateTime? _extractRenewalDate(String text, DateTime? emailDate) {
    // Look for date patterns
    final datePatterns = [
      RegExp(r'renew.*?(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'(\w+\s+\d{1,2},?\s+\d{4})', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && date.isAfter(DateTime.now())) {
            return date;
          }
        }
      }
    }

    // If no date found, estimate based on billing cycle
    if (emailDate != null) {
      if (text.contains('monthly') || text.contains('month')) {
        return emailDate.add(const Duration(days: 30));
      } else if (text.contains('yearly') || text.contains('year')) {
        return emailDate.add(const Duration(days: 365));
      } else if (text.contains('weekly') || text.contains('week')) {
        return emailDate.add(const Duration(days: 7));
      }
    }

    return emailDate?.add(const Duration(days: 30)); // Default to 30 days
  }

  BillingCycle _extractBillingCycle(String text) {
    if (text.contains('yearly') ||
        text.contains('annual') ||
        text.contains('year')) {
      return BillingCycle.yearly;
    } else if (text.contains('quarterly') || text.contains('quarter')) {
      return BillingCycle.quarterly;
    } else if (text.contains('weekly') || text.contains('week')) {
      return BillingCycle.weekly;
    } else {
      return BillingCycle.monthly; // Default
    }
  }

  SubscriptionCategory _inferCategory(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('netflix') ||
        name.contains('spotify') ||
        name.contains('disney') ||
        name.contains('hulu') ||
        name.contains('hbo') ||
        name.contains('prime')) {
      return SubscriptionCategory.entertainment;
    } else if (name.contains('adobe') ||
        name.contains('microsoft') ||
        name.contains('office') ||
        name.contains('notion') ||
        name.contains('figma') ||
        name.contains('canva')) {
      return SubscriptionCategory.productivity;
    } else if (name.contains('aws') ||
        name.contains('azure') ||
        name.contains('github') ||
        name.contains('dropbox')) {
      return SubscriptionCategory.productivity;
    } else if (name.contains('linkedin') ||
        name.contains('slack') ||
        name.contains('zoom')) {
      return SubscriptionCategory.productivity;
    } else {
      return SubscriptionCategory.other;
    }
  }

  String? _extractPaymentMethod(String text) {
    if (text.contains('visa') ||
        text.contains('mastercard') ||
        text.contains('amex') ||
        text.contains('american express')) {
      return 'Credit Card';
    } else if (text.contains('paypal')) {
      return 'PayPal';
    } else if (text.contains('apple pay')) {
      return 'Apple Pay';
    } else if (text.contains('google pay')) {
      return 'Google Pay';
    }
    return null;
  }

  double _calculateConfidence({
    required String serviceName,
    required double cost,
    required DateTime renewalDate,
  }) {
    double confidence = 0.5; // Base confidence

    // Increase confidence if service name is recognized
    final knownServices = ['netflix', 'spotify', 'amazon', 'disney', 'adobe'];
    if (knownServices.any((s) => serviceName.toLowerCase().contains(s))) {
      confidence += 0.2;
    }

    // Increase confidence if cost is reasonable
    if (cost > 0 && cost < 1000) {
      confidence += 0.1;
    }

    // Increase confidence if renewal date is in the future
    if (renewalDate.isAfter(DateTime.now())) {
      confidence += 0.2;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Set OAuth tokens (for OAuth flow, not recommended for production)
  void setTokens(String accessToken, String? refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _useImap = false; // Switch to OAuth mode
  }

  /// Clear all credentials and disconnect
  Future<void> clearCredentials() async {
    _accessToken = null;
    _refreshToken = null;
    await _imapService?.disconnect();
  }

  /// Disconnect from email server
  Future<void> disconnect() async {
    await _imapService?.disconnect();
  }

  /// Get IMAP server settings for the current provider
  Map<String, dynamic> getImapSettings() {
    return ImapEmailScannerService.getImapSettings(provider);
  }
}
