import '../domain/email_provider.dart';
import '../domain/email_subscription_match.dart';
import '../../../subscriptions/domain/subscription.dart';
import 'package:enough_mail/enough_mail.dart';

/// Local email scanner using IMAP/POP3 protocols
/// Works with any email provider that supports IMAP/POP3
/// No OAuth client ID required - uses user credentials directly
class ImapEmailScannerService {
  final EmailProvider provider;
  ImapClient? _imapClient;
  bool _isConnected = false;

  // Email credentials (stored securely, never logged)
  String? _email;
  String? _password;
  String? _imapServer;
  int? _imapPort;
  bool _useSsl = true;

  ImapEmailScannerService(this.provider) {
    _configureServerSettings();
  }

  void _configureServerSettings() {
    switch (provider) {
      case EmailProvider.gmail:
        _imapServer = 'imap.gmail.com';
        _imapPort = 993;
        _useSsl = true;
        break;
      case EmailProvider.outlook:
        _imapServer = 'outlook.office365.com';
        _imapPort = 993;
        _useSsl = true;
        break;
    }
  }

  /// Set email credentials for IMAP connection
  /// Credentials are stored in memory only, never persisted
  void setCredentials({
    required String email,
    required String password,
    String? customImapServer,
    int? customImapPort,
    bool? useSsl,
  }) {
    _email = email;
    _password = password;
    if (customImapServer != null) {
      _imapServer = customImapServer;
      _imapPort = customImapPort ?? 993;
      _useSsl = useSsl ?? true;
    }
  }

  /// Connect to email server using IMAP
  Future<bool> connect() async {
    if (_email == null || _password == null || _imapServer == null) {
      throw Exception(
          'Email credentials not set. Call setCredentials() first.');
    }

    try {
      // Create IMAP client using enough_mail
      _imapClient = ImapClient();

      // Connect to server
      await _imapClient!.connectToServer(
        _imapServer!,
        _imapPort!,
        isSecure: _useSsl,
      );

      // Authenticate
      await _imapClient!.login(_email!, _password!);

      _isConnected = true;
      return true;
    } catch (e) {
      _isConnected = false;
      throw Exception('Failed to connect to email server: $e');
    }
  }

  /// Disconnect from email server
  Future<void> disconnect() async {
    try {
      await _imapClient?.logout();
      _imapClient?.disconnect();
    } catch (e) {
      // Ignore disconnect errors
    } finally {
      _imapClient = null;
      _isConnected = false;
    }
  }

  /// Scan emails for subscription-related content
  Future<List<EmailSubscriptionMatch>> scanEmails({
    int maxResults = 50,
    DateTime? since,
    String folder = 'INBOX',
  }) async {
    if (!_isConnected || _imapClient == null) {
      throw Exception('Not connected. Call connect() first.');
    }

    try {
      // Select mailbox - create Mailbox object properly
      final mailbox = Mailbox(
        encodedName: folder,
        encodedPath: folder,
        flags: <MailboxFlag>[],
        pathSeparator: '/',
      );
      await _imapClient!.selectMailbox(mailbox);

      // Search for emails - enough_mail uses different search API
      // Try fetching recent messages directly without search first
      // Get the total number of messages in the mailbox
      final messageCount = mailbox.messagesExists;

      if (messageCount == 0) {
        return [];
      }

      // Calculate range to fetch (most recent messages)
      final start =
          messageCount > maxResults ? messageCount - maxResults + 1 : 1;
      final end = messageCount;

      // Fetch messages by sequence number range
      // fetchMessages signature: fetchMessages(MessageSequence sequence, String? charset)
      final fetchResult = await _imapClient!.fetchMessages(
        MessageSequence.fromRange(start, end),
        null, // charset - null for default
      );

      // Parse fetched messages directly
      final emails = <Map<String, dynamic>>[];
      for (final message in fetchResult.messages) {
        try {
          // Filter by date if specified
          if (since != null) {
            final messageDate = message.decodeDate();
            if (messageDate == null || messageDate.isBefore(since)) {
              continue;
            }
          }

          emails.add(_parseImapMessage(message));

          // Limit results
          if (emails.length >= maxResults) {
            break;
          }
        } catch (e) {
          // Skip messages that fail to parse
          continue;
        }
      }

      // Parse emails for subscriptions
      final matches = <EmailSubscriptionMatch>[];
      for (final email in emails) {
        final match = _parseEmailForSubscription(email);
        if (match != null) {
          matches.add(match);
        }
      }

      return matches;
    } catch (e) {
      throw Exception('Failed to scan emails: $e');
    }
  }

  Map<String, dynamic> _parseImapMessage(MimeMessage message) {
    return {
      'id': message.sequenceId?.toString() ?? message.uid?.toString() ?? '',
      'subject': message.decodeSubject() ?? '',
      'from': message.from?.map((a) => a.toString()).join(', ') ?? '',
      'date': message.decodeDate() ?? DateTime.now(),
      'body': _extractBody(message),
      'htmlBody': _extractHtmlBody(message),
    };
  }

  String? _extractBody(MimeMessage message) {
    // Try to extract text/plain content from message
    try {
      // Check parts for text/plain
      if (message.parts != null && message.parts!.isNotEmpty) {
        for (final part in message.parts!) {
          final mediaType = part.mediaType;
          if (mediaType != null) {
            // Check if it's text/plain
            final mimeType = mediaType.toString().toLowerCase();
            if (mimeType.contains('text/plain')) {
              try {
                // Try to get text content from part
                // Note: MimePart API may vary - adjust based on enough_mail version
                try {
                  // Try different ways to extract text based on part type
                  if (part is MimePart) {
                    // Attempt to decode text from MimePart
                    // This may need adjustment based on actual enough_mail API
                    return null; // Placeholder - needs actual API implementation
                  }
                } catch (e) {
                  continue;
                }
              } catch (e) {
                continue;
              }
            }
          }
        }
      }
    } catch (e) {
      // Continue to try other methods
    }

    return null;
  }

  String? _extractHtmlBody(MimeMessage message) {
    // Try to extract text/html content from message
    try {
      // Check parts for text/html
      if (message.parts != null && message.parts!.isNotEmpty) {
        for (final part in message.parts!) {
          final mediaType = part.mediaType;
          if (mediaType != null) {
            // Check if it's text/html
            final mimeType = mediaType.toString().toLowerCase();
            if (mimeType.contains('text/html')) {
              try {
                // Try to get HTML content from part
                // Note: MimePart API may vary - adjust based on enough_mail version
                try {
                  // Try different ways to extract HTML based on part type
                  if (part is MimePart) {
                    // Attempt to decode HTML from MimePart
                    // This may need adjustment based on actual enough_mail API
                    return null; // Placeholder - needs actual API implementation
                  }
                } catch (e) {
                  continue;
                }
              } catch (e) {
                continue;
              }
            }
          }
        }
      }
    } catch (e) {
      // Continue to try other methods
    }

    return null;
  }

  EmailSubscriptionMatch? _parseEmailForSubscription(
      Map<String, dynamic> email) {
    final subject = email['subject'] as String? ?? '';
    final body = email['body'] as String? ?? email['htmlBody'] as String? ?? '';
    final date = email['date'] as DateTime? ?? DateTime.now();

    if (subject.isEmpty && body.isEmpty) return null;

    final text = '${subject} ${body}'.toLowerCase();

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
      'auto-renew',
      'auto renew',
      'recurring',
    ];
    return keywords.any((keyword) => text.contains(keyword));
  }

  String? _extractServiceName(String? subject, String? body) {
    final text = '${subject ?? ''} ${body ?? ''}';

    // Expanded service names list
    final services = [
      'netflix',
      'spotify',
      'amazon prime',
      'amazon',
      'disney',
      'disney+',
      'hulu',
      'hbo',
      'hbo max',
      'apple music',
      'youtube premium',
      'youtube',
      'adobe',
      'microsoft',
      'office 365',
      'microsoft 365',
      'dropbox',
      'icloud',
      'google drive',
      'google',
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
      'shopify',
      'squarespace',
      'wix',
      'wordpress',
      'mailchimp',
      'hubspot',
      'salesforce',
      'zendesk',
      'atlassian',
      'jira',
      'confluence',
      'trello',
      'asana',
      'monday',
      'clickup',
      'airtable',
      'smartsheet',
      'quickbooks',
      'xero',
      'freshbooks',
      'wave',
      'stripe',
      'paypal',
      'square',
    ];

    for (final service in services) {
      if (text.toLowerCase().contains(service)) {
        return service.split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
      }
    }

    // Try to extract from subject
    if (subject != null && subject.isNotEmpty) {
      final cleaned = subject
          .replaceAll(RegExp(r'^(re|fwd?):\s*', caseSensitive: false), '')
          .trim();
      if (cleaned.length >= 3 && cleaned.length < 50) {
        return cleaned;
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractCost(String text) {
    // Enhanced cost extraction patterns
    final patterns = [
      RegExp(
          r'(?:total|amount|charge|payment|cost)[:\s]+[\$€£¥₹¢]?\s*([\d,]+\.?\d*)',
          caseSensitive: false),
      RegExp(r'[\$€£¥₹¢]\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS)',
          caseSensitive: false),
    ];

    double? maxAmount;
    String? currency;

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(amountStr);
        if (amount != null && amount > 0 && amount < 1000000) {
          if (maxAmount == null || amount > maxAmount) {
            maxAmount = amount;
            if (match.groupCount >= 2 && match.group(2) != null) {
              currency = match.group(2)!.toUpperCase();
            } else if (text.contains('\$')) {
              currency = 'USD';
            } else if (text.contains('€')) {
              currency = 'EUR';
            } else if (text.contains('£')) {
              currency = 'GBP';
            } else if (text.contains('₹')) {
              currency = 'INR';
            } else {
              currency = 'USD';
            }
          }
        }
      }
    }

    if (maxAmount != null) {
      return {'cost': maxAmount, 'currency': currency ?? 'USD'};
    }

    return null;
  }

  DateTime? _extractRenewalDate(String text, DateTime emailDate) {
    // Enhanced date extraction
    final datePatterns = [
      RegExp(r'renew.*?(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'(\w+\s+\d{1,2},?\s+\d{4})', caseSensitive: false),
      RegExp(r'(\d{1,2}\s+\w+\s+\d{4})', caseSensitive: false),
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

    // Estimate based on billing cycle
    if (text.contains('monthly') || text.contains('month')) {
      return emailDate.add(const Duration(days: 30));
    } else if (text.contains('yearly') ||
        text.contains('year') ||
        text.contains('annual')) {
      return emailDate.add(const Duration(days: 365));
    } else if (text.contains('weekly') || text.contains('week')) {
      return emailDate.add(const Duration(days: 7));
    } else if (text.contains('quarterly') || text.contains('quarter')) {
      return emailDate.add(const Duration(days: 90));
    }

    return emailDate.add(const Duration(days: 30)); // Default
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
      return BillingCycle.monthly;
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
    } else if (text.contains('debit')) {
      return 'Debit Card';
    }
    return null;
  }

  double _calculateConfidence({
    required String serviceName,
    required double cost,
    required DateTime renewalDate,
  }) {
    double confidence = 0.5;

    final knownServices = [
      'netflix',
      'spotify',
      'amazon',
      'disney',
      'adobe',
      'microsoft',
      'apple',
      'google',
      'dropbox',
      'github',
      'slack',
      'zoom',
    ];
    if (knownServices.any((s) => serviceName.toLowerCase().contains(s))) {
      confidence += 0.2;
    }

    if (cost > 0 && cost < 1000) {
      confidence += 0.1;
    }

    if (renewalDate.isAfter(DateTime.now())) {
      confidence += 0.2;
    }

    return confidence.clamp(0.0, 1.0);
  }

  /// Get IMAP server settings for common providers
  static Map<String, dynamic> getImapSettings(EmailProvider provider) {
    switch (provider) {
      case EmailProvider.gmail:
        return {
          'server': 'imap.gmail.com',
          'port': 993,
          'useSsl': true,
          'note': 'Enable "Less secure app access" or use App Password',
        };
      case EmailProvider.outlook:
        return {
          'server': 'outlook.office365.com',
          'port': 993,
          'useSsl': true,
          'note': 'Use your Microsoft account password',
        };
    }
  }

  /// Get IMAP settings for custom email providers
  static Map<String, dynamic> getCustomImapSettings({
    required String server,
    int port = 993,
    bool useSsl = true,
  }) {
    return {
      'server': server,
      'port': port,
      'useSsl': useSsl,
    };
  }
}
