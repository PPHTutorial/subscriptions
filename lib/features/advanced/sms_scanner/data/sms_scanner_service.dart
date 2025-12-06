import 'dart:async';
import 'package:telephony/telephony.dart';
import '../../../subscriptions/domain/subscription.dart';

/// Service for scanning SMS messages to detect subscription transactions
class SmsScannerService {
  final Telephony _telephony = Telephony.instance;
  StreamSubscription<List<SmsMessage>>? _smsSubscription;

  /// Request SMS reading permission
  Future<bool> requestPermission() async {
    final permission = await _telephony.requestPhoneAndSmsPermissions;
    return permission ?? false;
  }

  /// Check if SMS permission is granted
  Future<bool> hasPermission() async {
    final permission = await _telephony.requestPhoneAndSmsPermissions;
    return permission ?? false;
  }

  /// Start listening for SMS messages
  void startListening(Function(SmsMessage) onSmsReceived) {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        if (_isSubscriptionRelated(message.body ?? '')) {
          onSmsReceived(message);
        }
      },
      onBackgroundMessage: _backgroundMessageHandler,
    );
  }

  /// Stop listening for SMS messages
  void stopListening() {
    _smsSubscription?.cancel();
    _smsSubscription = null;
  }

  /// Scan existing SMS messages for subscription patterns
  Future<List<SubscriptionMatch>> scanExistingMessages({
    int limit = 100,
    DateTime? since,
  }) async {
    if (!await hasPermission()) {
      throw Exception('SMS permission not granted');
    }

    final messages = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
    );

    // Limit results manually
    final limitedMessages = messages.take(limit).toList();

    final matches = <SubscriptionMatch>[];

    for (final message in limitedMessages) {
      if (since != null && message.date != null) {
        if (DateTime.fromMillisecondsSinceEpoch(message.date!)
                .millisecondsSinceEpoch <
            since.millisecondsSinceEpoch) {
          continue;
        }
      }

      final match = _parseSmsForSubscription(message);
      if (match != null) {
        matches.add(match);
      }
    }

    return matches;
  }

  SubscriptionMatch? _parseSmsForSubscription(SmsMessage message) {
    final body = message.body ?? '';
    final sender = message.address ?? '';

    // First, check if this is a job application or other non-subscription SMS
    if (_isJobApplication(body) || _isNonSubscriptionText(body)) {
      return null;
    }

    if (!_isSubscriptionRelated(body)) {
      return null;
    }

    // Extract service name
    final serviceName = _extractServiceName(body, sender);
    if (serviceName == null) return null;

    // Extract cost
    final costMatch = _extractCost(body);
    if (costMatch == null) return null;

    // Extract date (use message date or parse from body)
    final date =
        message.date is DateTime ? message.date as DateTime : DateTime.now();
    final renewalDate = _extractRenewalDate(body, date);

    // Determine billing cycle based on frequency
    final billingCycle = _determineBillingCycle(body, date);

    return SubscriptionMatch(
      serviceName: serviceName,
      cost: costMatch['cost'] as double,
      currencyCode: costMatch['currency'] as String,
      renewalDate: renewalDate,
      billingCycle: billingCycle,
      confidence: _calculateConfidence(body, serviceName),
      paymentMethod: _extractPaymentMethod(body, sender),
      source: 'SMS',
      sourceData: body,
    );
  }

  bool _isSubscriptionRelated(String text) {
    final lowerText = text.toLowerCase();

    // Common subscription-related keywords
    final keywords = [
      'subscription',
      'renewal',
      'renew',
      'payment',
      'charged',
      'transaction',
      'netflix',
      'spotify',
      'amazon',
      'disney',
      'hulu',
      'adobe',
      'microsoft',
      'office 365',
      'dropbox',
      'grammarly',
      'canva',
      'notion',
      'figma',
      'slack',
      'zoom',
    ];

    return keywords.any((keyword) => lowerText.contains(keyword));
  }

  String? _extractServiceName(String body, String sender) {
    final lowerBody = body.toLowerCase();
    final lowerSender = sender.toLowerCase();

    // Check for known service names in body
    final services = [
      'netflix', 'spotify', 'amazon prime', 'disney', 'hulu', 'hbo',
      'apple music', 'youtube premium', 'adobe', 'microsoft', 'office 365',
      'dropbox', 'icloud', 'google drive', 'grammarly', 'canva', 'notion',
      'figma', 'slack', 'zoom', 'linkedin', 'github', 'aws', 'azure',
      'momo', 'mtn', 'vodafone', 'airtel', // Mobile money services
    ];

    for (final service in services) {
      if (lowerBody.contains(service) || lowerSender.contains(service)) {
        return service.split(' ').map((word) {
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
      }
    }

    // Try to extract from sender (for bank messages)
    if (lowerSender.contains('bank') ||
        lowerSender.contains('momo') ||
        lowerSender.contains('mtn') ||
        lowerSender.contains('vodafone')) {
      // Extract service name from body
      final patterns = [
        RegExp(r'(\w+)\s*(subscription|renewal|payment)', caseSensitive: false),
        RegExp(r'paid\s+to\s+(\w+)', caseSensitive: false),
        RegExp(r'(\w+)\s+gh', caseSensitive: false), // For Ghana mobile money
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(body);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.trim();
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractCost(String body) {
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
      // Standard patterns without K/M
      RegExp(r'(GHS|NGN|USD|EUR|GBP|INR)\s*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*(GHS|NGN|USD|EUR|GBP|INR)', caseSensitive: false),
      RegExp(r'[\$€£¥₹¢₵]\s*(\d+\.?\d*)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        String? currency;
        double? amount;

        // Check if this pattern has K/M suffix (patterns 0-2)
        if (match.groupCount >= 3 && match.group(3) != null) {
          // Pattern with K/M suffix
          final amountStr = match.group(2)?.replaceAll(',', '') ?? '';
          amount = double.tryParse(amountStr);
          final multiplierStr = match.group(3)?.toLowerCase();

          // Apply K/M multiplier
          if (amount != null && multiplierStr != null) {
            if (multiplierStr == 'k' || multiplierStr == 'thousand') {
              amount = amount * 1000;
            } else if (multiplierStr == 'm' || multiplierStr == 'million') {
              amount = amount * 1000000;
            }
          }

          // Extract currency from group 1
          final currencyGroup = match.group(1);
          if (currencyGroup != null) {
            currency = _normalizeCurrency(currencyGroup);
          }
        } else if (match.groupCount >= 2) {
          // Standard pattern without K/M
          currency = match.group(1)?.toUpperCase();
          amount = double.tryParse(match.group(2)?.replaceAll(',', '') ?? '');
          if (amount == null) {
            currency = match.group(2)?.toUpperCase();
            amount = double.tryParse(match.group(1)?.replaceAll(',', '') ?? '');
          }
          if (currency != null) {
            currency = _normalizeCurrency(currency);
          }
        } else {
          amount = double.tryParse(match.group(1)?.replaceAll(',', '') ?? '');
          currency = 'USD'; // Default
        }

        // Validate amount (reasonable subscription range: $0.01 to $100,000)
        if (amount != null && amount > 0 && amount <= 100000) {
          return {'cost': amount, 'currency': currency ?? 'USD'};
        }
      }
    }
    return null;
  }

  /// Check if SMS is a job application (to exclude false positives)
  bool _isJobApplication(String text) {
    final lowerText = text.toLowerCase();

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
      if (lowerText.contains(keyword)) {
        jobKeywordCount++;
        if (jobKeywordCount >= 2) {
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
        salaryPatterns.any((p) => p.hasMatch(lowerText))) {
      return true;
    }

    return false;
  }

  /// Check for other non-subscription texts (spam, newsletters, etc.)
  bool _isNonSubscriptionText(String text) {
    final lowerText = text.toLowerCase();

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
      if (lowerText.contains(keyword)) {
        nonSubCount++;
        if (nonSubCount >= 2) {
          return true;
        }
      }
    }

    return false;
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
      '¢': 'USD',
      '₵': 'GHS',
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
      'CEDIS': 'GHS',
      'CEDI': 'GHS',
    };

    return codeMap[normalized] ?? normalized;
  }

  DateTime _extractRenewalDate(String body, DateTime messageDate) {
    // Look for date patterns in SMS
    final datePatterns = [
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'(\w+\s+\d{1,2},?\s+\d{4})', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(body);
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

    // Default: assume monthly subscription, next renewal in 30 days
    return messageDate.add(const Duration(days: 30));
  }

  BillingCycle _determineBillingCycle(String body, DateTime messageDate) {
    final lowerText = body.toLowerCase();

    // Use regex patterns for more accurate detection (same as email scanner)

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
      RegExp(r'\b(\d+)\s*(?:month|mo|months?)\b', caseSensitive: false),
    ];

    // Weekly patterns (per week, weekly, 7 days, etc.)
    final weeklyPatterns = [
      RegExp(
          r'\b(weekly|per\s+week|every\s+week|weekly\s+subscription|7\s+days?)\b',
          caseSensitive: false),
      RegExp(r'\b(?:billed|charged|renewed?)\s+(?:weekly|per\s+week)\b',
          caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:week|wk|weeks?)\b', caseSensitive: false),
    ];

    // Check patterns in order of specificity

    // Check for yearly
    for (final pattern in yearlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final numStr = match!.group(1);
          if (numStr != null) {
            final num = int.tryParse(numStr);
            if (num != null && num == 1) {
              return BillingCycle.yearly;
            }
          }
        } else {
      return BillingCycle.yearly;
        }
      }
    }

    // Check for half-yearly
    for (final pattern in halfYearlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        return BillingCycle.halfYearly;
      }
    }

    // Check for quarterly
    for (final pattern in quarterlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        return BillingCycle.quarterly;
      }
    }

    // Check for monthly
    for (final pattern in monthlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final numStr = match!.group(1);
          if (numStr != null) {
            final num = int.tryParse(numStr);
            if (num != null && num == 1) {
              return BillingCycle.monthly;
            } else if (num == 2) {
              return BillingCycle.monthly;
            } else if (num == 3) {
      return BillingCycle.quarterly;
            } else if (num == 6) {
              return BillingCycle.halfYearly;
            } else if (num == 12) {
              return BillingCycle.yearly;
            }
          }
    } else {
      return BillingCycle.monthly;
    }
      }
    }

    // Check for weekly
    for (final pattern in weeklyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final numStr = match!.group(1);
          if (numStr != null) {
            final num = int.tryParse(numStr);
            if (num != null && num == 1) {
              return BillingCycle.weekly;
            }
          }
        } else {
          return BillingCycle.weekly;
        }
      }
    }

    // Fallback: check for simple keywords
    if (lowerText.contains('year') || lowerText.contains('annual')) {
      return BillingCycle.yearly;
    } else if (lowerText.contains('quarter')) {
      return BillingCycle.quarterly;
    } else if (lowerText.contains('week')) {
      return BillingCycle.weekly;
    }

    // Default to monthly
    return BillingCycle.monthly;
  }

  String? _extractPaymentMethod(String body, String sender) {
    final lowerBody = body.toLowerCase();
    final lowerSender = sender.toLowerCase();

    if (lowerBody.contains('visa') ||
        lowerBody.contains('mastercard') ||
        lowerBody.contains('amex')) {
      return 'Credit Card';
    } else if (lowerBody.contains('momo') || lowerSender.contains('momo')) {
      return 'Mobile Money';
    } else if (lowerBody.contains('mtn') || lowerSender.contains('mtn')) {
      return 'MTN Mobile Money';
    } else if (lowerBody.contains('vodafone') ||
        lowerSender.contains('vodafone')) {
      return 'Vodafone Cash';
    } else if (lowerBody.contains('airtel') || lowerSender.contains('airtel')) {
      return 'Airtel Money';
    }
    return 'Unknown';
  }

  double _calculateConfidence(String body, String serviceName) {
    double confidence = 0.4; // Base confidence for SMS

    // Increase confidence if service name is recognized
    final knownServices = ['netflix', 'spotify', 'amazon', 'disney', 'adobe'];
    if (knownServices.any((s) => serviceName.toLowerCase().contains(s))) {
      confidence += 0.3;
    }

    // Increase confidence if cost is mentioned
    if (_extractCost(body) != null) {
      confidence += 0.2;
    }

    // Increase confidence if keywords are present
    if (body.toLowerCase().contains('subscription') ||
        body.toLowerCase().contains('renewal')) {
      confidence += 0.1;
    }

    return confidence.clamp(0.0, 1.0);
  }

  static Future<void> _backgroundMessageHandler(SmsMessage message) async {
    // Handle SMS in background (for Android)
    // This is called when app is in background
  }
}

class SubscriptionMatch {
  SubscriptionMatch({
    required this.serviceName,
    required this.cost,
    required this.currencyCode,
    required this.renewalDate,
    required this.billingCycle,
    required this.confidence,
    this.paymentMethod,
    this.source,
    this.sourceData,
  });

  final String serviceName;
  final double cost;
  final String currencyCode;
  final DateTime renewalDate;
  final BillingCycle billingCycle;
  final double confidence;
  final String? paymentMethod;
  final String? source;
  final String? sourceData;

  Subscription toSubscription() {
    return Subscription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      serviceName: serviceName,
      billingCycle: billingCycle,
      renewalDate: renewalDate,
      currencyCode: currencyCode,
      cost: cost,
      autoRenew: true,
      category: _inferCategory(serviceName, sourceData ?? ''),
      paymentMethod: paymentMethod ?? 'Unknown',
      reminderDays: [7, 3, 1],
    );
  }

  SubscriptionCategory _inferCategory(String serviceName, [String? fullText]) {
    final text = fullText != null
        ? '${serviceName.toLowerCase()} ${fullText.toLowerCase()}'
        : serviceName.toLowerCase();

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
          score += 1;
        }
      }
      if (score > 0) {
        categoryScores[category] = (categoryScores[category] ?? 0) + score;
      }
    }

    // Score all categories
    scoreCategory(SubscriptionCategory.entertainment, streamingKeywords);
    scoreCategory(SubscriptionCategory.music, musicKeywords);
    scoreCategory(SubscriptionCategory.productivity, productivityKeywords);
    scoreCategory(SubscriptionCategory.cloudStorage, cloudStorageKeywords);
    scoreCategory(SubscriptionCategory.development, devKeywords);
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

    // Return category with highest score
    if (categoryScores.isEmpty) {
      return SubscriptionCategory.other;
    }

    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories.first.key;
  }
}
