import 'package:flutter/foundation.dart';
import '../domain/email_provider.dart';
import '../domain/email_subscription_match.dart';
import '../../../subscriptions/domain/subscription.dart';
import 'package:enough_mail/enough_mail.dart';

/// Simple IMAP email scanner using enough_mail
class ImapEmailScannerService {
  final EmailProvider provider;
  ImapClient? _imapClient;
  bool _isConnected = false;

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
      case EmailProvider.yahoo:
        _imapServer = 'imap.mail.yahoo.com';
        _imapPort = 993;
        _useSsl = true;
        break;
      case EmailProvider.icloud:
        _imapServer = 'imap.mail.me.com';
        _imapPort = 993;
        _useSsl = true;
        break;
      case EmailProvider.protonmail:
        _imapServer = '127.0.0.1';
        _imapPort = 1143;
        _useSsl = false;
        break;
      case EmailProvider.custom:
        _imapServer = 'imap.titan.email';
        _imapPort = 993;
        _useSsl = true;
        break;
    }
  }

  void setCredentials({
    required String email,
    required String password,
    String? customImapServer,
    int? customImapPort,
    bool? useSsl,
  }) {
    _email = email;
    _password = password;

    if (provider == EmailProvider.custom) {
      if (customImapServer != null && customImapServer.isNotEmpty) {
        _imapServer = customImapServer;
        _imapPort = customImapPort ?? 993;
        _useSsl = useSsl ?? true;
      }
    } else if (customImapServer != null && customImapServer.isNotEmpty) {
      _imapServer = customImapServer;
      _imapPort = customImapPort ?? 993;
      _useSsl = useSsl ?? true;
    }
  }

  Future<bool> connect() async {
    if (_email == null || _password == null || _imapServer == null) {
      throw Exception(
          'Email credentials not set. Call setCredentials() first.');
    }

    try {
      _imapClient = ImapClient();
      final port = _imapPort ?? 993;
      final useSsl = _useSsl || port == 465;

      await _imapClient!.connectToServer(_imapServer!, port, isSecure: useSsl);
      await _imapClient!.login(_email!, _password!);

      _isConnected = true;
      return true;
    } catch (e) {
      _isConnected = false;
      throw Exception('Failed to connect: $e');
    }
  }

  bool get isConnected => _isConnected && _imapClient != null;

  Future<void> disconnect() async {
    try {
      await _imapClient?.logout();
      _imapClient?.disconnect();
    } catch (e) {
      // Ignore
    } finally {
      _imapClient = null;
      _isConnected = false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchEmails({
    int maxResults = 150,
    DateTime? since,
    String folder = 'INBOX',
  }) async {
    if (!_isConnected || _imapClient == null) {
      throw Exception('Not connected. Call connect() first.');
    }

    try {
      Mailbox? selectedMailbox;
      if (folder == 'INBOX') {
        selectedMailbox = await _imapClient!.selectInbox();
      } else {
      final mailbox = Mailbox(
        encodedName: folder,
        encodedPath: folder,
          flags: [],
        pathSeparator: '/',
      );
        selectedMailbox = await _imapClient!.selectMailbox(mailbox);
      }
      final messageCount = selectedMailbox.messagesExists;

      if (messageCount == 0) return [];

      // Fetch from latest to oldest (reverse order)
      // IMAP sequence numbers: 1 is oldest, messageCount is newest
      // Fetch the most recent emails first (from today backwards)
      final start =
          messageCount > maxResults ? messageCount - maxResults + 1 : 1;
      final end = messageCount;

      try {
      final fetchResult = await _imapClient!.fetchMessages(
        MessageSequence.fromRange(start, end),
          'BODY.PEEK[]',
      );

        if (fetchResult.messages.isEmpty) {
          return [];
        }

      final emails = <Map<String, dynamic>>[];
        // Messages are in ascending order (oldest to newest)
        // Reverse to get newest first (descending order - from today to previous)
        final messages = fetchResult.messages.toList().reversed.toList();

        // Process messages from newest to oldest (ascending date order)
        // Start from today and go backwards
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        for (final message in messages) {
          try {
            final messageDate = message.decodeDate();

            // If since is provided, skip emails older than that
            if (since != null) {
            if (messageDate == null || messageDate.isBefore(since)) {
                debugPrint(
                    'Skipping email: date ${messageDate} is before ${since}');
              continue;
            }
            } else {
              // If no since date, only include emails from the last 60 days
              if (messageDate != null) {
                final messageDay = DateTime(
                    messageDate.year, messageDate.month, messageDate.day);
                final daysDiff = today.difference(messageDay).inDays;

                if (daysDiff > 180) {
                  debugPrint('Skipping email: too old (${daysDiff} days)');
                  continue;
                }
              }
            }

            final parsedEmail = _parseMessage(message);
            emails.add(parsedEmail);

            debugPrint(
                'Added email from ${messageDate} (${emails.length}/${maxResults})');

            if (emails.length >= maxResults) break;
          } catch (e) {
            // Log error but continue with other messages
            debugPrint('Error parsing message: $e');
            continue;
          }
        }

        debugPrint('Fetched ${emails.length} emails (from newest to oldest)');

        return emails;
        } catch (e) {
        debugPrint('Error fetching messages with range: $e');
        // If range fetch fails, try fetching individual messages from the end
        try {
          final emails = <Map<String, dynamic>>[];
          final fetchCount =
              messageCount > maxResults ? maxResults : messageCount;

          // Fetch messages one by one from the end (newest)
          for (var seqNum = messageCount;
              seqNum > messageCount - fetchCount && seqNum > 0;
              seqNum--) {
            try {
              final fetchResult = await _imapClient!.fetchMessages(
                MessageSequence.fromRange(seqNum, seqNum),
                'BODY.PEEK[]',
              );

              if (fetchResult.messages.isNotEmpty) {
                final message = fetchResult.messages.first;
                if (since != null) {
                  final messageDate = message.decodeDate();
                  if (messageDate == null || messageDate.isBefore(since)) {
                    continue;
                  }
                }
                emails.add(_parseMessage(message));
                if (emails.length >= maxResults) break;
              }
            } catch (e) {
              debugPrint('Error fetching message $seqNum: $e');
          continue;
        }
      }

          return emails;
        } catch (e2) {
          debugPrint('Alternative fetch also failed: $e2');
          rethrow;
        }
      }
    } catch (e) {
      throw Exception('Failed to fetch emails: $e');
    }
  }

  Future<List<EmailSubscriptionMatch>> scanEmails({
    int maxResults = 50,
    DateTime? since,
    String folder = 'INBOX',
  }) async {
    debugPrint('Starting email scan...');
    final emails =
        await fetchEmails(maxResults: maxResults, since: since, folder: folder);
    debugPrint('Fetched ${emails.length} emails for scanning');

      final matches = <EmailSubscriptionMatch>[];

    for (var i = 0; i < emails.length; i++) {
      final email = emails[i];
      debugPrint('Scanning email ${i + 1}/${emails.length}');
        final match = _parseEmailForSubscription(email);
        if (match != null) {
        debugPrint('Match found: ${match.serviceName}');
          matches.add(match);
        }
      }

    debugPrint('Scan complete: Found ${matches.length} subscription(s)');
      return matches;
  }

  Map<String, dynamic> _parseMessage(MimeMessage message) {
    try {
      final subject = message.decodeSubject() ?? '';
      final from =
          message.from?.map((a) => a.toString()).join(', ') ?? 'Unknown';
      final date = message.decodeDate() ?? DateTime.now();
      final textBody = _extractTextBody(message);
      final htmlBody = _extractHtmlBody(message);

      debugPrint('Parsed email: Subject="$subject", From="$from", Date=$date');

    return {
      'id': message.sequenceId?.toString() ?? message.uid?.toString() ?? '',
        'subject': subject,
        'from': from,
        'date': date,
        'body': textBody,
        'htmlBody': htmlBody,
      };
    } catch (e) {
      debugPrint('Error parsing message: $e');
      rethrow;
    }
  }

  String? _extractTextBody(MimeMessage message) {
    try {
      // Use decodeTextPlainPart
      final text = message.decodeTextPlainPart();
      if (text != null && text.isNotEmpty) {
        // Clean up the text - remove excessive whitespace but preserve structure
        return text
            .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Max 2 consecutive newlines
            .replaceAll(RegExp(r'[ \t]+'), ' ') // Multiple spaces to single
            .trim();
                  }
                } catch (e) {
      // Ignore
    }
    return null;
  }

  String? _extractHtmlBody(MimeMessage message) {
    try {
      // Use decodeTextHtmlPart
      final html = message.decodeTextHtmlPart();
      if (html != null && html.isNotEmpty) {
        return html;
                  }
                } catch (e) {
      // Ignore
    }
    return null;
  }

  /// Extract plain text from HTML for parsing purposes
  String _extractPlainTextFromHtml(String html) {
    // Remove script and style tags
    String text =
        html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
    text =
        text.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');

    // Replace common HTML entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll('&apos;', "'");

    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');

    // Clean up whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    text = text.trim();

    return text;
  }

  EmailSubscriptionMatch? _parseEmailForSubscription(
      Map<String, dynamic> email) {
    final subject = email['subject'] as String? ?? '';
    final htmlBody = email['htmlBody'] as String?;
    final textBody = email['body'] as String? ?? '';

    // Extract plain text from HTML if available, otherwise use text body
    final body = htmlBody != null && htmlBody.isNotEmpty
        ? _extractPlainTextFromHtml(htmlBody)
        : textBody;

    final date = email['date'] as DateTime? ?? DateTime.now();

    if (subject.isEmpty && body.isEmpty) return null;

    // Use both original and lowercase for better matching
    final fullText = '${subject} ${body}';
    final text = fullText.toLowerCase();

    // First, check if this is a job application or other non-subscription email
    if (_isJobApplication(subject, body) ||
        _isNonSubscriptionEmail(subject, body)) {
      debugPrint(
          'Skipping email - detected as job application or non-subscription: $subject');
      return null;
    }

    // More lenient keyword checking - check if it's likely a subscription email
    if (!_containsSubscriptionKeywords(text) &&
        !_isLikelySubscriptionEmail(subject, body)) {
      return null;
    }

    final serviceName = _extractServiceName(subject, body);
    if (serviceName == null) return null;

    // More lenient cost extraction - try multiple patterns
    final costMatch = _extractCost(fullText) ?? _extractCost(text);
    if (costMatch == null) {
      // If no cost found, still try to create match with default values
      // This makes scanning less strict
      final renewalDate =
          _extractRenewalDate(text, date) ?? date.add(const Duration(days: 30));
      final billingCycle = _extractBillingCycle(text);

      return EmailSubscriptionMatch(
        serviceName: serviceName,
        cost: 0.0, // Unknown cost
        currencyCode: 'USD',
        renewalDate: renewalDate,
        billingCycle: billingCycle,
        confidence: 0.3, // Lower confidence without cost
        category: _inferCategory(serviceName, text),
        paymentMethod: _extractPaymentMethod(text),
        emailSubject: subject,
        emailDate: date,
      );
    }

    final renewalDate =
        _extractRenewalDate(text, date) ?? date.add(const Duration(days: 30));
    final billingCycle = _extractBillingCycle(text);
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
      category: _inferCategory(serviceName, text),
      paymentMethod: _extractPaymentMethod(text),
      emailSubject: subject,
      emailDate: date,
    );
  }

  /// Check if email is a job application (to exclude false positives)
  bool _isJobApplication(String subject, String body) {
    final combined = '${subject} ${body}'.toLowerCase();

    final jobApplicationKeywords = [
      'job application',
      'application for',
      'applying for',
      'position',
      'role',
      'job opportunity',
      'career opportunity',
      'we are hiring',
      'join our team',
      'open position',
      'job opening',
      'vacancy',
      'recruitment',
      'recruiting',
      'candidate',
      'resume',
      'cv',
      'cover letter',
      'interview',
      'salary',
      'compensation',
      'benefits package',
      'employment',
      'full-time',
      'part-time',
      'remote position',
      'work from home',
      'job posting',
      'job listing',
      'apply now',
      'submit application',
      'application deadline',
      'hiring manager',
      'hr',
      'human resources',
      'talent acquisition',
      'years of experience',
      'required skills',
      'qualifications',
      'job description',
      'job requirements',
    ];

    // Check for multiple job-related keywords (more reliable)
    int jobKeywordCount = 0;
    for (final keyword in jobApplicationKeywords) {
      if (combined.contains(keyword)) {
        jobKeywordCount++;
        if (jobKeywordCount >= 2) {
          // If 2+ job keywords found, it's likely a job application
          return true;
        }
      }
    }

    // Also check for salary/compensation patterns that are too high for subscriptions
    final salaryPatterns = [
      RegExp(r'\$\s*[\d,]+(?:k|m|thousand|million)', caseSensitive: false),
      RegExp(
          r'(?:salary|compensation|pay)\s*:?\s*\$?\s*[\d,]+(?:k|m|thousand|million)',
          caseSensitive: false),
      RegExp(r'[\d,]+(?:k|m|thousand|million)\s*(?:per\s+year|annually|yearly)',
          caseSensitive: false),
    ];

    // If salary pattern found AND job keywords present, it's a job application
    if (jobKeywordCount >= 1 &&
        salaryPatterns.any((p) => p.hasMatch(combined))) {
      return true;
    }

    return false;
  }

  /// Check for other non-subscription emails (spam, newsletters, etc.)
  bool _isNonSubscriptionEmail(String subject, String body) {
    final combined = '${subject} ${body}'.toLowerCase();

    final nonSubscriptionKeywords = [
      'unsubscribe',
      'newsletter',
      'promotional',
      'marketing',
      'advertisement',
      'spam',
      'verify your email',
      'confirm your email',
      'email verification',
      'account verification',
      'password reset',
      'forgot password',
      'security alert',
      'suspicious activity',
      'login attempt',
      'two-factor',
      '2fa',
      'verification code',
      'otp',
      'one-time password',
    ];

    // If multiple non-subscription keywords found, exclude
    int nonSubCount = 0;
    for (final keyword in nonSubscriptionKeywords) {
      if (combined.contains(keyword)) {
        nonSubCount++;
        if (nonSubCount >= 2) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isLikelySubscriptionEmail(String subject, String body) {
    // Check for common subscription email patterns
    final patterns = [
      RegExp(r'\b(monthly|yearly|annual|quarterly|weekly)\b',
          caseSensitive: false),
      RegExp(r'\b(renew|renewal|renewing)\b', caseSensitive: false),
      RegExp(r'\b(billing|billed|charge|charged)\b', caseSensitive: false),
      RegExp(r'\b(invoice|receipt|payment)\b', caseSensitive: false),
      RegExp(r'\b(subscription|subscriptions)\b', caseSensitive: false),
      RegExp(r'\b(plan|premium|pro|plus)\b', caseSensitive: false),
    ];

    final combined = '${subject} ${body}'.toLowerCase();
    return patterns.any((pattern) => pattern.hasMatch(combined));
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
    final services = [
      // Streaming & Video
      'netflix', 'spotify', 'disney', 'disney plus', 'disney+', 'hulu', 'hbo',
      'hbo max', 'prime video', 'amazon prime', 'youtube premium', 'youtube tv',
      'apple tv', 'paramount', 'peacock', 'showtime', 'starz', 'crunchyroll',
      'fubo', 'sling', 'directv', 'amazon', 'youtube',
      // Music
      'apple music', 'amazon music', 'tidal', 'pandora', 'soundcloud', 'deezer',
      // Productivity
      'adobe', 'microsoft', 'office', 'office 365', 'microsoft 365',
      'notion', 'figma', 'canva', 'slack', 'trello', 'asana', 'monday',
      'clickup', 'todoist', 'evernote', 'onenote', 'roam', 'obsidian',
      // Cloud Storage
      'dropbox', 'google drive', 'onedrive', 'icloud', 'box', 'pcloud',
      'mega', 'backblaze', 'carbonite', 'google',
      // Development
      'github', 'gitlab', 'bitbucket', 'aws', 'azure', 'google cloud', 'gcp',
      'heroku', 'vercel', 'netlify', 'digitalocean', 'linode', 'vultr',
      // Design
      'photoshop', 'illustrator', 'indesign', 'premiere', 'after effects',
      'sketch', 'affinity',
      // Communication
      'zoom', 'teams', 'discord', 'telegram', 'skype', 'webex', 'gotomeeting',
      'bluejeans', 'ringcentral',
      // Security
      'nordvpn', 'expressvpn', 'surfshark', 'cyberghost', 'protonvpn',
      'lastpass', '1password', 'dashlane', 'bitwarden', 'keeper',
      'norton', 'mcafee', 'kaspersky', 'avast', 'bitdefender',
      // Finance
      'mint', 'ynab', 'quickbooks', 'freshbooks', 'xero', 'wave',
      'moneydance', 'turbotax', 'credit karma', 'paypal', 'stripe', 'square',
      // News
      'new york times', 'washington post', 'wall street journal', 'wsj',
      'the guardian', 'economist', 'atlantic', 'new yorker', 'medium',
      'substack',
      // Education
      'coursera', 'udemy', 'skillshare', 'linkedin learning', 'pluralsight',
      'masterclass', 'khan academy', 'udacity', 'codecademy', 'treehouse',
      'linkedin',
      // Health
      'myfitnesspal', 'strava', 'nike training', 'calm', 'headspace',
      'noom', 'weight watchers', 'ww', 'fitbit premium', 'whoop',
      // Gaming
      'xbox', 'playstation', 'nintendo', 'steam', 'epic games', 'ubisoft',
      'ea play', 'game pass', 'nvidia geforce', 'twitch',
      // Shopping
      'amazon prime', 'costco', 'sam\'s club', 'walmart+', 'target',
      // Travel
      'booking.com', 'expedia', 'airbnb', 'uber', 'lyft', 'turo',
      // Food
      'doordash', 'ubereats', 'grubhub', 'instacart', 'hello fresh',
      'blue apron',
      // Social Media
      'linkedin premium', 'twitter blue', 'reddit premium',
      // Telecom
      'verizon', 'at&t', 't-mobile', 'sprint', 'vodafone', 'orange',
      // Mobile Money
      'mpesa', 'mtn mobile money', 'orange money', 'airtel money',
      // Business
      'salesforce', 'hubspot', 'zendesk', 'intercom', 'mailchimp',
      'sendgrid', 'constant contact',
      // Marketing
      'campaign monitor', 'convertkit', 'activecampaign',
      // Other
      'grammarly',
    ];

    for (final service in services) {
      if (text.toLowerCase().contains(service)) {
        return service.split(' ').map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
      }
    }

    // If no known service found, try to extract from subject
    if (subject != null && subject.isNotEmpty) {
      final cleaned = subject
          .replaceAll(RegExp(r'^(re|fwd?|fw):\s*', caseSensitive: false), '')
          .replaceAll(
              RegExp(r'\[.*?\]', caseSensitive: false), '') // Remove brackets
          .replaceAll(RegExp(r'\(.*?\)', caseSensitive: false),
              '') // Remove parentheses
          .trim();

      // More lenient - accept longer subjects and extract meaningful parts
      if (cleaned.length >= 3) {
        // Try to extract service name from common patterns
        // e.g., "Netflix Subscription", "Your Spotify Premium", etc.
        final servicePattern = RegExp(
          r'\b(netflix|spotify|amazon|disney|hulu|hbo|apple|youtube|adobe|microsoft|office|dropbox|icloud|google|grammarly|canva|notion|figma|slack|zoom|linkedin|github|aws|azure|nordvpn|expressvpn|lastpass|1password|quickbooks|salesforce|hubspot|coursera|udemy|xbox|playstation|steam|doordash|ubereats|booking|expedia|airbnb|verizon|t-mobile|mailchimp|stripe|paypal|mint|ynab)\b',
          caseSensitive: false,
        );
        final match = servicePattern.firstMatch(cleaned);
        if (match != null) {
          return match.group(1)!.split(' ').map((word) {
            if (word.isEmpty) return word;
            return word[0].toUpperCase() + word.substring(1);
          }).join(' ');
        }

        // If no service pattern, return cleaned subject (truncated if too long)
        return cleaned.length > 50 ? '${cleaned.substring(0, 47)}...' : cleaned;
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractCost(String text) {
    // Enhanced patterns to handle K/M suffixes and various currency formats
    final patterns = [
      // Pattern with K/M suffixes: $124K, GHS500K, ₵1M, USD 50.77k
      RegExp(
          r'(?:total|amount|charge|payment|cost|price|fee|paid|pay|billed)[:\s]*([\$€£¥₹¢₵]|USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS)\s*([\d,]+\.?\d*)\s*([kmKM]|thousand|million)\b',
          caseSensitive: false),
      // Pattern with currency symbol before amount and K/M: $124K, ₵1M
      RegExp(r'([\$€£¥₹¢₵])\s*([\d,]+\.?\d*)\s*([kmKM]|thousand|million)\b',
          caseSensitive: false),
      // Pattern with currency code and K/M: USD 50.77k, GHS500K
      RegExp(
          r'\b(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS)\s*([\d,]+\.?\d*)\s*([kmKM]|thousand|million)\b',
          caseSensitive: false),
      // Standard patterns without K/M (existing patterns)
      RegExp(
          r'(?:total|amount|charge|payment|cost|price|fee|paid|pay|billed)[:\s]*([\$€£¥₹¢₵]|USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS)?\s*([\d,]+\.?\d*)',
          caseSensitive: false),
      RegExp(r'([\$€£¥₹¢₵])\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(
          r'([\d,]+\.?\d*)\s*(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS|dollars?|euros?|pounds?|cedis?)',
          caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*([\$€£¥₹¢₵])', caseSensitive: false),
      // Pattern for "X.XX per month/year"
      RegExp(r'([\d,]+\.?\d*)\s*(?:per|/)\s*(?:month|year|monthly|yearly)',
          caseSensitive: false),
    ];

    double? maxAmount;
    String? currency;

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        double? amount;
        String? detectedCurrency;
        String? multiplierStr;

        // Check if this pattern has K/M suffix (patterns 0-2)
        if (match.groupCount >= 3 && match.group(3) != null) {
          // Pattern with K/M suffix
          final amountStr = match.group(2)?.replaceAll(',', '') ?? '';
          amount = double.tryParse(amountStr);
          multiplierStr = match.group(3)?.toLowerCase();

          // Extract currency from group 1
          final currencyGroup = match.group(1);
          if (currencyGroup != null) {
            detectedCurrency = _normalizeCurrency(currencyGroup);
          }
        } else if (match.groupCount >= 2) {
          // Standard pattern without K/M
          // Try to find the amount (numeric group) and currency (non-numeric group)
          String? amountStr;
          for (int i = 1; i <= match.groupCount; i++) {
            final group = match.group(i);
            if (group != null) {
              // Check if this group is numeric (amount)
              if (RegExp(r'^[\d,\.]+$').hasMatch(group)) {
                amountStr = group.replaceAll(',', '');
              } else {
                // This is likely currency
                final normalized = _normalizeCurrency(group);
                if (normalized != null) {
                  detectedCurrency = normalized;
                }
              }
            }
          }
          if (amountStr != null) {
            amount = double.tryParse(amountStr);
          }
        } else {
          // Fallback: try to parse first group as amount
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
          amount = double.tryParse(amountStr);
        }

        // Apply K/M multiplier if present
        if (amount != null && multiplierStr != null) {
          if (multiplierStr == 'k' || multiplierStr == 'thousand') {
            amount = amount * 1000;
          } else if (multiplierStr == 'm' || multiplierStr == 'million') {
            amount = amount * 1000000;
          }
        }

        // Validate amount (reasonable subscription range: $0.01 to $100,000)
        if (amount != null && amount > 0 && amount <= 100000) {
          // Infer currency from text if not detected
          if (detectedCurrency == null) {
            detectedCurrency = _inferCurrencyFromText(text);
          }

          if (maxAmount == null || amount > maxAmount) {
            maxAmount = amount;
            currency = detectedCurrency;
          }
        }
      }
    }

    if (maxAmount != null) {
      return {'cost': maxAmount, 'currency': currency ?? 'USD'};
    }
    return null;
  }

  /// Normalize currency symbols and codes to standard codes
  String? _normalizeCurrency(String currencyStr) {
    final normalized = currencyStr.trim().toUpperCase();

    // Currency symbol mapping
    final symbolMap = {
      '\$': 'USD',
      '€': 'EUR',
      '£': 'GBP',
      '¥': 'JPY',
      '₹': 'INR',
      '¢': 'USD', // Cent symbol, assume USD
      '₵': 'GHS', // Ghana Cedi
    };

    if (symbolMap.containsKey(normalized)) {
      return symbolMap[normalized];
    }

    // Currency code mapping
    final codeMap = {
      'USD': 'USD',
      'EUR': 'EUR',
      'GBP': 'GBP',
      'INR': 'INR',
      'GHS': 'GHS',
      'NGN': 'NGN',
      'ZAR': 'ZAR',
      'KES': 'KES',
      'UGX': 'UGX',
      'TZS': 'TZS',
      'DOLLAR': 'USD',
      'DOLLARS': 'USD',
      'EURO': 'EUR',
      'EUROS': 'EUR',
      'POUND': 'GBP',
      'POUNDS': 'GBP',
      'POUND STERLING': 'GBP',
      'CEDIS': 'GHS',
      'CEDI': 'GHS',
    };

    return codeMap[normalized] ?? normalized;
  }

  /// Infer currency from text context
  String _inferCurrencyFromText(String text) {
    final lowerText = text.toLowerCase();

    // Check for currency symbols
    if (text.contains('\$')) return 'USD';
    if (text.contains('€')) return 'EUR';
    if (text.contains('£')) return 'GBP';
    if (text.contains('₹')) return 'INR';
    if (text.contains('₵')) return 'GHS';

    // Check for currency codes
    if (RegExp(r'\b(USD|usd)\b').hasMatch(text)) return 'USD';
    if (RegExp(r'\b(EUR|eur)\b').hasMatch(text)) return 'EUR';
    if (RegExp(r'\b(GBP|gbp)\b').hasMatch(text)) return 'GBP';
    if (RegExp(r'\b(INR|inr)\b').hasMatch(text)) return 'INR';
    if (RegExp(r'\b(GHS|ghs)\b').hasMatch(text)) return 'GHS';
    if (RegExp(r'\b(NGN|ngn)\b').hasMatch(text)) return 'NGN';
    if (RegExp(r'\b(ZAR|zar)\b').hasMatch(text)) return 'ZAR';
    if (RegExp(r'\b(KES|kes)\b').hasMatch(text)) return 'KES';
    if (RegExp(r'\b(UGX|ugx)\b').hasMatch(text)) return 'UGX';
    if (RegExp(r'\b(TZS|tzs)\b').hasMatch(text)) return 'TZS';

    // Check for currency names
    if (lowerText.contains('dollar')) return 'USD';
    if (lowerText.contains('euro')) return 'EUR';
    if (lowerText.contains('pound')) return 'GBP';
    if (lowerText.contains('rupee')) return 'INR';
    if (lowerText.contains('cedi') || lowerText.contains('cedis')) return 'GHS';

    // Default to USD
    return 'USD';
  }

  DateTime? _extractRenewalDate(String text, DateTime emailDate) {
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

    // Use the billing cycle extraction to determine renewal date
    final billingCycle = _extractBillingCycle(text);
    switch (billingCycle) {
      case BillingCycle.weekly:
      return emailDate.add(const Duration(days: 7));
      case BillingCycle.monthly:
        return emailDate.add(const Duration(days: 30));
      case BillingCycle.quarterly:
      return emailDate.add(const Duration(days: 90));
      case BillingCycle.halfYearly:
        return emailDate.add(const Duration(days: 180));
      case BillingCycle.yearly:
        return emailDate.add(const Duration(days: 365));
      case BillingCycle.custom:
        return emailDate.add(const Duration(days: 30)); // Default fallback
    }
  }

  BillingCycle _extractBillingCycle(String text) {
    final lowerText = text.toLowerCase();

    // Use regex patterns for more accurate detection
    // Check for specific patterns first (most specific to least specific)

    // Yearly/Annual patterns (12 months, per year, annually, etc.)
    final yearlyPatterns = [
      RegExp(
          r'\b(annual|annually|yearly|per\s+year|every\s+year|12\s+months?|yearly\s+subscription|annual\s+plan)\b',
          caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:year|yr|years?)\b', caseSensitive: false),
      RegExp(
          r'\b(?:billed|charged|renewed?)\s+(?:annually|yearly|per\s+year)\b',
          caseSensitive: false),
    ];

    // Half-yearly/Semi-annual patterns (6 months, bi-annual, semi-annual, etc.)
    final halfYearlyPatterns = [
      RegExp(
          r'\b(semi-?annual|bi-?annual|half-?yearly|half-?year|6\s+months?|every\s+6\s+months?)\b',
          caseSensitive: false),
      RegExp(
          r'\b(?:billed|charged|renewed?)\s+(?:semi-?annually|bi-?annually|every\s+6\s+months?)\b',
          caseSensitive: false),
    ];

    // Quarterly patterns (3 months, per quarter, etc.)
    final quarterlyPatterns = [
      RegExp(
          r'\b(quarterly|per\s+quarter|every\s+quarter|3\s+months?|every\s+3\s+months?|quarterly\s+subscription)\b',
          caseSensitive: false),
      RegExp(r'\b(?:billed|charged|renewed?)\s+(?:quarterly|per\s+quarter)\b',
          caseSensitive: false),
    ];

    // Monthly patterns (per month, monthly, 30 days, etc.)
    final monthlyPatterns = [
      RegExp(
          r'\b(monthly|per\s+month|every\s+month|monthly\s+subscription|monthly\s+plan|30\s+days?)\b',
          caseSensitive: false),
      RegExp(r'\b(?:billed|charged|renewed?)\s+(?:monthly|per\s+month)\b',
          caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:month|mo|months?)\b',
          caseSensitive: false), // e.g., "1 month", "2 months"
    ];

    // Weekly patterns (per week, weekly, 7 days, etc.)
    final weeklyPatterns = [
      RegExp(
          r'\b(weekly|per\s+week|every\s+week|weekly\s+subscription|7\s+days?)\b',
          caseSensitive: false),
      RegExp(r'\b(?:billed|charged|renewed?)\s+(?:weekly|per\s+week)\b',
          caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:week|wk|weeks?)\b',
          caseSensitive: false), // e.g., "1 week", "2 weeks"
    ];

    // Check patterns in order of specificity (yearly -> half-yearly -> quarterly -> monthly -> weekly)

    // Check for yearly
    for (final pattern in yearlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        // If it's a number pattern, check if it's 1 year (not 2 years, 3 years, etc.)
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final numStr = match!.group(1);
          if (numStr != null) {
            final num = int.tryParse(numStr);
            if (num != null && num == 1) {
              debugPrint(
                  'Detected billing cycle: Yearly (from pattern: ${pattern.pattern})');
      return BillingCycle.yearly;
            }
          }
        } else {
          debugPrint(
              'Detected billing cycle: Yearly (from pattern: ${pattern.pattern})');
          return BillingCycle.yearly;
        }
      }
    }

    // Check for half-yearly (6 months, semi-annual, bi-annual)
    for (final pattern in halfYearlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        debugPrint(
            'Detected billing cycle: Half-Yearly (from pattern: ${pattern.pattern})');
        return BillingCycle.halfYearly;
      }
    }

    // Check for quarterly
    for (final pattern in quarterlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        debugPrint(
            'Detected billing cycle: Quarterly (from pattern: ${pattern.pattern})');
      return BillingCycle.quarterly;
      }
    }

    // Check for monthly
    for (final pattern in monthlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        // If it's a number pattern, check if it's 1 month (not 2 months, 3 months, etc.)
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final numStr = match!.group(1);
          if (numStr != null) {
            final num = int.tryParse(numStr);
            if (num != null && num == 1) {
              debugPrint(
                  'Detected billing cycle: Monthly (from pattern: ${pattern.pattern})');
              return BillingCycle.monthly;
            } else if (num == 2) {
              // 2 months could be bi-monthly, but we'll map to monthly for now
              debugPrint('Detected billing cycle: Monthly (2 months pattern)');
              return BillingCycle.monthly;
            } else if (num == 3) {
              debugPrint(
                  'Detected billing cycle: Quarterly (3 months pattern)');
              return BillingCycle.quarterly;
            } else if (num == 6) {
              debugPrint(
                  'Detected billing cycle: Half-Yearly (6 months pattern)');
              return BillingCycle.halfYearly;
            } else if (num == 12) {
              debugPrint('Detected billing cycle: Yearly (12 months pattern)');
              return BillingCycle.yearly;
            }
          }
    } else {
          debugPrint(
              'Detected billing cycle: Monthly (from pattern: ${pattern.pattern})');
      return BillingCycle.monthly;
        }
      }
    }

    // Check for weekly
    for (final pattern in weeklyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        // If it's a number pattern, check if it's 1 week
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final numStr = match!.group(1);
          if (numStr != null) {
            final num = int.tryParse(numStr);
            if (num != null && num == 1) {
              debugPrint(
                  'Detected billing cycle: Weekly (from pattern: ${pattern.pattern})');
              return BillingCycle.weekly;
            }
          }
    } else {
          debugPrint(
              'Detected billing cycle: Weekly (from pattern: ${pattern.pattern})');
          return BillingCycle.weekly;
        }
      }
    }

    // Fallback: check for simple keywords (less accurate but better than nothing)
    if (lowerText.contains('year') || lowerText.contains('annual')) {
      debugPrint('Detected billing cycle: Yearly (fallback keyword)');
      return BillingCycle.yearly;
    } else if (lowerText.contains('quarter')) {
      debugPrint('Detected billing cycle: Quarterly (fallback keyword)');
      return BillingCycle.quarterly;
    } else if (lowerText.contains('week')) {
      debugPrint('Detected billing cycle: Weekly (fallback keyword)');
      return BillingCycle.weekly;
    }

    // Default to monthly
    debugPrint('Detected billing cycle: Monthly (default)');
    return BillingCycle.monthly;
  }

  SubscriptionCategory _inferCategory(String serviceName, String fullText) {
    final text = '${serviceName.toLowerCase()} ${fullText.toLowerCase()}';

    // Category keyword maps with weighted scoring
    final categoryScores = <SubscriptionCategory, int>{};

    // Streaming & Video
    final streamingKeywords = [
      'netflix',
      'spotify',
      'disney',
      'disney+',
      'disney plus',
      'hulu',
      'hbo',
      'hbo max',
      'prime video',
      'amazon prime',
      'youtube premium',
      'youtube tv',
      'apple tv',
      'paramount',
      'peacock',
      'showtime',
      'starz',
      'crunchyroll',
      'fubo',
      'sling',
      'directv',
      'streaming',
      'stream',
      'watch',
      'movie',
      'movies',
      'tv show',
      'series',
      'episode',
      'season',
      'premium video',
      'video subscription',
      'entertainment subscription'
    ];

    // Music
    final musicKeywords = [
      'spotify',
      'apple music',
      'youtube music',
      'amazon music',
      'tidal',
      'pandora',
      'soundcloud',
      'deezer',
      'music',
      'song',
      'songs',
      'album',
      'playlist',
      'artist',
      'musician',
      'audio streaming',
      'music streaming'
    ];

    // Productivity & Software
    final productivityKeywords = [
      'adobe',
      'microsoft',
      'office',
      'office 365',
      'microsoft 365',
      'notion',
      'figma',
      'canva',
      'slack',
      'trello',
      'asana',
      'monday',
      'clickup',
      'todoist',
      'evernote',
      'onenote',
      'roam',
      'obsidian',
      'productivity',
      'task management',
      'project management',
      'note taking',
      'collaboration tool',
      'work management'
    ];

    // Cloud Storage
    final cloudStorageKeywords = [
      'dropbox',
      'google drive',
      'onedrive',
      'icloud',
      'box',
      'pcloud',
      'mega',
      'sync',
      'backblaze',
      'carbonite',
      'cloud storage',
      'file storage',
      'file backup',
      'online storage',
      'cloud backup',
      'data storage'
    ];

    // Software Development
    final devKeywords = [
      'github',
      'gitlab',
      'bitbucket',
      'aws',
      'azure',
      'google cloud',
      'gcp',
      'heroku',
      'vercel',
      'netlify',
      'digitalocean',
      'linode',
      'vultr',
      'code',
      'coding',
      'developer',
      'development',
      'programming',
      'api',
      'server',
      'hosting',
      'deployment',
      'ci/cd',
      'devops',
      'cloud computing',
      'infrastructure',
      'software development',
      'coding tool'
    ];

    // Design
    final designKeywords = [
      'adobe creative',
      'photoshop',
      'illustrator',
      'indesign',
      'premiere',
      'after effects',
      'figma',
      'sketch',
      'canva',
      'affinity',
      'design',
      'graphic design',
      'ui/ux',
      'prototype',
      'mockup',
      'design tool',
      'creative suite',
      'video editing',
      'photo editing'
    ];

    // Communication
    final communicationKeywords = [
      'zoom',
      'teams',
      'slack',
      'discord',
      'telegram',
      'whatsapp business',
      'skype',
      'webex',
      'gotomeeting',
      'bluejeans',
      'ringcentral',
      'communication',
      'messaging',
      'video call',
      'video conferencing',
      'team chat',
      'business communication',
      'calling',
      'voip'
    ];

    // Security
    final securityKeywords = [
      'nordvpn',
      'expressvpn',
      'surfshark',
      'cyberghost',
      'protonvpn',
      'lastpass',
      '1password',
      'dashlane',
      'bitwarden',
      'keeper',
      'norton',
      'mcafee',
      'kaspersky',
      'avast',
      'bitdefender',
      'vpn',
      'password manager',
      'antivirus',
      'security',
      'cybersecurity',
      'encryption',
      'privacy',
      'secure',
      'protection',
      'firewall'
    ];

    // Finance
    final financeKeywords = [
      'mint',
      'ynab',
      'quickbooks',
      'freshbooks',
      'xero',
      'wave',
      'moneydance',
      'gnucash',
      'turbotax',
      'credit karma',
      'paypal',
      'stripe',
      'square',
      'accounting',
      'bookkeeping',
      'tax',
      'invoice',
      'expense',
      'budget',
      'financial',
      'payment processing',
      'billing software'
    ];

    // News & Media
    final newsKeywords = [
      'new york times',
      'washington post',
      'wall street journal',
      'wsj',
      'the guardian',
      'economist',
      'atlantic',
      'new yorker',
      'medium',
      'substack',
      'newsletter',
      'news',
      'magazine',
      'journalism',
      'article',
      'publication',
      'media subscription',
      'news subscription'
    ];

    // Education
    final educationKeywords = [
      'coursera',
      'udemy',
      'skillshare',
      'linkedin learning',
      'pluralsight',
      'masterclass',
      'khan academy',
      'udacity',
      'codecademy',
      'treehouse',
      'education',
      'learning',
      'course',
      'training',
      'tutorial',
      'class',
      'online course',
      'e-learning',
      'educational',
      'certification'
    ];

    // Health & Fitness
    final healthKeywords = [
      'myfitnesspal',
      'strava',
      'nike training',
      'calm',
      'headspace',
      'noom',
      'weight watchers',
      'ww',
      'fitbit premium',
      'whoop',
      'health',
      'fitness',
      'workout',
      'exercise',
      'meditation',
      'wellness',
      'nutrition',
      'diet',
      'mental health',
      'therapy',
      'counseling'
    ];

    // Gaming
    final gamingKeywords = [
      'xbox',
      'playstation',
      'nintendo',
      'steam',
      'epic games',
      'ubisoft',
      'ea play',
      'game pass',
      'nvidia geforce',
      'twitch',
      'gaming',
      'game',
      'games',
      'gamer',
      'console',
      'pc gaming',
      'online gaming'
    ];

    // Shopping
    final shoppingKeywords = [
      'amazon prime',
      'costco',
      'sam\'s club',
      'walmart+',
      'target',
      'shopping',
      'retail',
      'membership',
      'delivery',
      'shipping',
      'online shopping',
      'retail subscription',
      'membership fee'
    ];

    // Travel
    final travelKeywords = [
      'booking.com',
      'expedia',
      'airbnb',
      'uber',
      'lyft',
      'turo',
      'travel',
      'hotel',
      'flight',
      'airline',
      'car rental',
      'trip',
      'vacation',
      'booking',
      'reservation',
      'travel subscription'
    ];

    // Food & Delivery
    final foodKeywords = [
      'doordash',
      'ubereats',
      'grubhub',
      'instacart',
      'hello fresh',
      'blue apron',
      'meal kit',
      'food delivery',
      'restaurant',
      'dining',
      'groceries',
      'meal',
      'recipe',
      'cooking',
      'food subscription'
    ];

    // Social Media
    final socialKeywords = [
      'linkedin premium',
      'twitter blue',
      'facebook',
      'instagram',
      'tiktok',
      'pinterest',
      'reddit premium',
      'social media',
      'social network',
      'community',
      'networking',
      'social platform'
    ];

    // Telecom
    final telecomKeywords = [
      'verizon',
      'at&t',
      't-mobile',
      'sprint',
      'vodafone',
      'orange',
      'telecom',
      'mobile',
      'phone',
      'cellular',
      'data plan',
      'phone plan',
      'mobile plan',
      'carrier',
      'network',
      'sim card',
      'mobile subscription'
    ];

    // Mobile Money
    final mobileMoneyKeywords = [
      'mpesa',
      'mtn mobile money',
      'orange money',
      'airtel money',
      'mobile money',
      'mobile payment',
      'digital wallet',
      'e-wallet',
      'mobile banking',
      'mobile transfer',
      'cash transfer'
    ];

    // Business
    final businessKeywords = [
      'salesforce',
      'hubspot',
      'zendesk',
      'intercom',
      'mailchimp',
      'sendgrid',
      'constant contact',
      'business',
      'enterprise',
      'saas',
      'crm',
      'customer relationship',
      'business tool',
      'enterprise software'
    ];

    // Marketing
    final marketingKeywords = [
      'mailchimp',
      'sendgrid',
      'constant contact',
      'campaign monitor',
      'convertkit',
      'activecampaign',
      'marketing',
      'email marketing',
      'campaign',
      'newsletter',
      'marketing automation',
      'seo',
      'analytics'
    ];

    // Utilities
    final utilitiesKeywords = [
      'electricity',
      'water',
      'gas',
      'internet',
      'wifi',
      'broadband',
      'utility',
      'utilities',
      'service charge',
      'utility bill',
      'service fee'
    ];

    // Scoring function
    void scoreCategory(SubscriptionCategory category, List<String> keywords) {
      int score = 0;
      for (final keyword in keywords) {
        if (text.contains(keyword)) {
          score += 2; // Base score
          // Bonus for exact matches
          if (serviceName.toLowerCase().contains(keyword)) {
            score += 3;
          }
        }
      }
      if (score > 0) {
        categoryScores[category] = (categoryScores[category] ?? 0) + score;
      }
    }

    // Score all categories
    scoreCategory(SubscriptionCategory.streaming, streamingKeywords);
    scoreCategory(SubscriptionCategory.music, musicKeywords);
    scoreCategory(SubscriptionCategory.productivity, productivityKeywords);
    scoreCategory(SubscriptionCategory.cloudStorage, cloudStorageKeywords);
    scoreCategory(SubscriptionCategory.softwareDevelopment, devKeywords);
    scoreCategory(SubscriptionCategory.design, designKeywords);
    scoreCategory(SubscriptionCategory.communication, communicationKeywords);
    scoreCategory(SubscriptionCategory.security, securityKeywords);
    scoreCategory(SubscriptionCategory.finance, financeKeywords);
    scoreCategory(SubscriptionCategory.news, newsKeywords);
    scoreCategory(SubscriptionCategory.education, educationKeywords);
    scoreCategory(SubscriptionCategory.health, healthKeywords);
    scoreCategory(SubscriptionCategory.gaming, gamingKeywords);
    scoreCategory(SubscriptionCategory.shopping, shoppingKeywords);
    scoreCategory(SubscriptionCategory.travel, travelKeywords);
    scoreCategory(SubscriptionCategory.food, foodKeywords);
    scoreCategory(SubscriptionCategory.socialMedia, socialKeywords);
    scoreCategory(SubscriptionCategory.telecom, telecomKeywords);
    scoreCategory(SubscriptionCategory.mobileMoney, mobileMoneyKeywords);
    scoreCategory(SubscriptionCategory.business, businessKeywords);
    scoreCategory(SubscriptionCategory.marketing, marketingKeywords);
    scoreCategory(SubscriptionCategory.utilities, utilitiesKeywords);

    // Additional pattern matching for statements
    final statementPatterns = [
      (
        RegExp(
            r'\b(watch|stream|video|movie|tv)\b.*\b(subscription|plan|premium)\b',
            caseSensitive: false),
        SubscriptionCategory.streaming
      ),
      (
        RegExp(
            r'\b(listen|music|song|audio)\b.*\b(subscription|plan|premium)\b',
            caseSensitive: false),
        SubscriptionCategory.music
      ),
      (
        RegExp(
            r'\b(code|develop|programming|software)\b.*\b(tool|service|platform)\b',
            caseSensitive: false),
        SubscriptionCategory.softwareDevelopment
      ),
      (
        RegExp(r'\b(design|graphic|creative|ui|ux)\b.*\b(tool|software|app)\b',
            caseSensitive: false),
        SubscriptionCategory.design
      ),
      (
        RegExp(r'\b(secure|privacy|vpn|password|encrypt)\b',
            caseSensitive: false),
        SubscriptionCategory.security
      ),
      (
        RegExp(r'\b(accounting|invoice|billing|tax|financial)\b',
            caseSensitive: false),
        SubscriptionCategory.finance
      ),
      (
        RegExp(r'\b(learn|course|education|training|tutorial)\b',
            caseSensitive: false),
        SubscriptionCategory.education
      ),
      (
        RegExp(r'\b(fitness|workout|health|exercise|meditation)\b',
            caseSensitive: false),
        SubscriptionCategory.health
      ),
      (
        RegExp(r'\b(game|gaming|console|play)\b', caseSensitive: false),
        SubscriptionCategory.gaming
      ),
      (
        RegExp(r'\b(news|article|magazine|publication|journalism)\b',
            caseSensitive: false),
        SubscriptionCategory.news
      ),
      (
        RegExp(r'\b(shop|retail|delivery|membership)\b', caseSensitive: false),
        SubscriptionCategory.shopping
      ),
      (
        RegExp(r'\b(travel|hotel|flight|booking|trip)\b', caseSensitive: false),
        SubscriptionCategory.travel
      ),
      (
        RegExp(r'\b(food|meal|restaurant|delivery|groceries)\b',
            caseSensitive: false),
        SubscriptionCategory.food
      ),
      (
        RegExp(r'\b(social|network|community|connect)\b', caseSensitive: false),
        SubscriptionCategory.socialMedia
      ),
      (
        RegExp(r'\b(phone|mobile|cellular|carrier|network)\b',
            caseSensitive: false),
        SubscriptionCategory.telecom
      ),
      (
        RegExp(r'\b(business|enterprise|crm|saas)\b', caseSensitive: false),
        SubscriptionCategory.business
      ),
      (
        RegExp(r'\b(marketing|campaign|email|promotion)\b',
            caseSensitive: false),
        SubscriptionCategory.marketing
      ),
    ];

    for (final (pattern, category) in statementPatterns) {
      if (pattern.hasMatch(text)) {
        categoryScores[category] = (categoryScores[category] ?? 0) + 5;
      }
    }

    // Find category with highest score
    if (categoryScores.isEmpty) {
      return SubscriptionCategory.other;
    }

    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategory = sortedCategories.first;
    debugPrint(
        'Category inference: ${topCategory.key.name} (score: ${topCategory.value}) for service: $serviceName');

    return topCategory.key;
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
      case EmailProvider.yahoo:
    return {
          'server': 'imap.mail.yahoo.com',
          'port': 993,
          'useSsl': true,
          'note': 'Use an App Password instead of your regular password',
        };
      case EmailProvider.icloud:
        return {
          'server': 'imap.mail.me.com',
          'port': 993,
          'useSsl': true,
          'note': 'Use an App-Specific Password from appleid.apple.com',
        };
      case EmailProvider.protonmail:
        return {
          'server': '127.0.0.1',
          'port': 1143,
          'useSsl': false,
          'note':
              'Requires ProtonMail Bridge to be running. See proton.me/bridge',
        };
      case EmailProvider.custom:
        return {
          'server': 'Custom',
          'port': 993,
          'useSsl': true,
          'note': 'Enter your custom IMAP server settings below',
        };
    }
  }
}
