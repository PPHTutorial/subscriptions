import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../subscriptions/domain/subscription.dart';
import 'barcode_scan_result.dart';
import 'receipt_ocr_service.dart';

/// Service for parsing barcode/QR code data and extracting subscription information
class BarcodeParserService {
  /// Parse barcode scan result and extract subscription details
  Future<ReceiptExtractionResult> parseBarcodeResult(
    BarcodeScanResult scanResult,
  ) async {
    try {
      // Handle different barcode types
      switch (scanResult.type) {
        case BarcodeScanType.url:
          return await _parseUrlBarcode(scanResult.url!);
        case BarcodeScanType.json:
          return _parseJsonBarcode(scanResult.jsonData!);
        case BarcodeScanType.structured:
          return _parseStructuredBarcode(scanResult.parsedData!);
        case BarcodeScanType.text:
          return _parseTextBarcode(
              scanResult.rawData, scanResult.subscriptionInfo);
      }
    } catch (e) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Failed to parse barcode: $e',
        rawText: scanResult.rawData,
      );
    }
  }

  /// Parse URL barcode - fetch content from URL if it's a receipt/invoice link
  Future<ReceiptExtractionResult> _parseUrlBarcode(String url) async {
    try {
      // Check if URL is a receipt/invoice link
      final isReceiptUrl = _isReceiptUrl(url);
      if (!isReceiptUrl) {
        return ReceiptExtractionResult(
          success: false,
          error: 'URL does not appear to be a receipt or invoice',
          rawText: url,
        );
      }

      // Try to fetch content from URL
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        // Try to parse as JSON first
        try {
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return _parseJsonData(json);
        } catch (_) {
          // Not JSON, try to extract from HTML/text
          return _parseHtmlContent(response.body, url);
        }
      }

      return ReceiptExtractionResult(
        success: false,
        error: 'Failed to fetch content from URL',
        rawText: url,
      );
    } catch (e) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Error processing URL: $e',
        rawText: url,
      );
    }
  }

  /// Parse JSON barcode data
  ReceiptExtractionResult _parseJsonBarcode(String jsonData) {
    try {
      final json = jsonDecode(jsonData) as Map<String, dynamic>;
      return _parseJsonData(json);
    } catch (e) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Invalid JSON format: $e',
        rawText: jsonData,
      );
    }
  }

  /// Parse structured data (query string format)
  ReceiptExtractionResult _parseStructuredBarcode(Map<String, String> data) {
    final serviceName =
        data['service'] ?? data['serviceName'] ?? data['provider'];
    final rawText = data.toString();
    return ReceiptExtractionResult(
      success: true,
      serviceName: serviceName,
      cost: _parseCost(data['amount'] ?? data['cost'] ?? data['price']),
      currencyCode: data['currency'] ?? data['currencyCode'] ?? 'USD',
      renewalDate:
          _parseDate(data['date'] ?? data['renewalDate'] ?? data['expiryDate']),
      billingCycle: _parseBillingCycle(data['billingCycle'] ?? data['cycle']),
      category:
          serviceName != null ? _inferCategory(serviceName, rawText) : null,
      paymentMethod: data['paymentMethod'] ?? data['payment'],
      rawText: rawText,
    );
  }

  /// Parse text barcode with extracted subscription info
  ReceiptExtractionResult _parseTextBarcode(
    String rawData,
    Map<String, dynamic>? subscriptionInfo,
  ) {
    if (subscriptionInfo == null || subscriptionInfo.isEmpty) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Could not extract subscription information from barcode',
        rawText: rawData,
      );
    }

    return ReceiptExtractionResult(
      success: true,
      serviceName: subscriptionInfo['serviceName'] as String?,
      cost: subscriptionInfo['cost'] as double?,
      currencyCode: subscriptionInfo['currencyCode'] as String? ?? 'USD',
      renewalDate: subscriptionInfo['renewalDate'] as DateTime?,
      rawText: rawData,
    );
  }

  /// Parse JSON data structure
  ReceiptExtractionResult _parseJsonData(Map<String, dynamic> json) {
    final serviceName = json['serviceName'] as String? ??
        json['service'] as String? ??
        json['provider'] as String?;
    final rawText = jsonEncode(json);
    return ReceiptExtractionResult(
      success: true,
      serviceName: serviceName,
      cost: _parseCost(json['cost'] ?? json['amount'] ?? json['price']),
      currencyCode: json['currencyCode'] as String? ??
          json['currency'] as String? ??
          'USD',
      renewalDate: _parseDate(json['renewalDate'] ??
          json['date'] ??
          json['expiryDate'] ??
          json['expiresOn']),
      billingCycle: _parseBillingCycle(json['billingCycle'] ?? json['cycle']),
      category:
          serviceName != null ? _inferCategory(serviceName, rawText) : null,
      paymentMethod:
          json['paymentMethod'] as String? ?? json['payment'] as String?,
      rawText: rawText,
    );
  }

  /// Parse HTML content from URL
  ReceiptExtractionResult _parseHtmlContent(String html, String url) {
    // Extract text from HTML (simple extraction)
    final text = _extractTextFromHtml(html);

    // First, check if this is a job application or other non-subscription text
    if (_isJobApplication(text) || _isNonSubscriptionText(text)) {
      return ReceiptExtractionResult(
        success: false,
        error:
            'Text appears to be a job application or non-subscription content',
        rawText: text,
      );
    }

    // Try to extract subscription info from text
    final serviceName = _extractServiceName(text, url);
    final cost = _extractCost(text);
    final date = _extractDate(text);
    final billingCycle = _extractBillingCycleFromText(text);

    return ReceiptExtractionResult(
      success: serviceName != null && cost != null,
      serviceName: serviceName,
      cost: cost,
      currencyCode: _extractCurrency(text) ?? 'USD',
      renewalDate: date,
      billingCycle: billingCycle,
      category: serviceName != null ? _inferCategory(serviceName, text) : null,
      rawText: text,
    );
  }

  bool _isReceiptUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.contains('receipt') ||
        lowerUrl.contains('invoice') ||
        lowerUrl.contains('billing') ||
        lowerUrl.contains('subscription') ||
        lowerUrl.contains('payment');
  }

  double? _parseCost(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Remove currency symbols and parse
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned);
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        // Try common date formats
        final formats = [
          'yyyy-MM-dd',
          'MM/dd/yyyy',
          'dd/MM/yyyy',
          'yyyy/MM/dd',
        ];
        for (final format in formats) {
          try {
            // Simple parsing attempt
            final parts = value.split(RegExp(r'[/-]'));
            if (parts.length == 3) {
              if (format.startsWith('yyyy')) {
                return DateTime(int.parse(parts[0]), int.parse(parts[1]),
                    int.parse(parts[2]));
              } else {
                return DateTime(int.parse(parts[2]), int.parse(parts[0]),
                    int.parse(parts[1]));
              }
            }
          } catch (_) {
            continue;
          }
        }
      }
    }
    return null;
  }

  BillingCycle? _parseBillingCycle(dynamic value) {
    if (value == null) return null;
    final cycleStr = value.toString().toLowerCase();
    // Check for half-yearly patterns first (more specific)
    if (cycleStr.contains('semi-annual') ||
        cycleStr.contains('semi annual') ||
        cycleStr.contains('bi-annual') ||
        cycleStr.contains('bi annual') ||
        cycleStr.contains('half-yearly') ||
        cycleStr.contains('half yearly') ||
        cycleStr.contains('6 months')) {
      return BillingCycle.halfYearly;
    }
    if (cycleStr.contains('month')) return BillingCycle.monthly;
    if (cycleStr.contains('year') || cycleStr.contains('annual'))
      return BillingCycle.yearly;
    if (cycleStr.contains('quarter')) return BillingCycle.quarterly;
    if (cycleStr.contains('week')) return BillingCycle.weekly;
    return null;
  }

  String _extractTextFromHtml(String html) {
    // Simple HTML tag removal
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _extractServiceName(String text, String url) {
    // Try to extract from URL domain
    try {
      final uri = Uri.parse(url);
      final host = uri.host;
      if (host.isNotEmpty && !host.contains('localhost')) {
        final parts = host.split('.');
        if (parts.length >= 2) {
          return parts[parts.length - 2].split('-').map((p) {
            if (p.isEmpty) return p;
            return p[0].toUpperCase() + p.substring(1);
          }).join(' ');
        }
      }
    } catch (_) {
      // Invalid URL
    }

    // Try to extract from text
    final patterns = [
      RegExp(r'service[:\s]+([^\n,]+)', caseSensitive: false),
      RegExp(r'provider[:\s]+([^\n,]+)', caseSensitive: false),
      RegExp(r'company[:\s]+([^\n,]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return match.group(1)?.trim();
      }
    }

    return null;
  }

  double? _extractCost(String text) {
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
      RegExp(r'amount[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'cost[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'price[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'[\$€£¥₹¢₵]\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*(USD|EUR|GBP|GHS|NGN|INR|ZAR|KES|UGX|TZS)',
          caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
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
        } else {
          // Standard pattern without K/M
          final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
          amount = double.tryParse(amountStr);
        }

        // Validate amount (reasonable subscription range: $0.01 to $100,000)
        if (amount != null && amount > 0 && amount <= 100000) {
          return amount;
        }
      }
    }

    return null;
  }

  DateTime? _extractDate(String text) {
    final patterns = [
      RegExp(r'date[:\s]+([0-9]{4}[-/][0-9]{2}[-/][0-9]{2})',
          caseSensitive: false),
      RegExp(r'expir[ey][:\s]+([0-9]{4}[-/][0-9]{2}[-/][0-9]{2})',
          caseSensitive: false),
      RegExp(r'([0-9]{4}[-/][0-9]{2}[-/][0-9]{2})', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          final dateStr = match.group(1)?.replaceAll('/', '-');
          if (dateStr != null) {
            return DateTime.tryParse(dateStr);
          }
        } catch (_) {
          // Invalid date format
        }
      }
    }

    return null;
  }

  String? _extractCurrency(String text) {
    final patterns = [
      RegExp(r'currency[:\s]+([A-Z]{3})', caseSensitive: false),
      RegExp(r'([0-9.]+)\s*(USD|EUR|GBP|GHS|NGN|INR)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount > 0) {
        return match.group(match.groupCount)?.toUpperCase();
      }
    }

    return null;
  }

  /// Check if text is a job application (to exclude false positives)
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

  /// Extract billing cycle from text (enhanced version matching email scanner)
  BillingCycle? _extractBillingCycleFromText(String text) {
    final lowerText = text.toLowerCase();

    // Yearly/Annual patterns
    final yearlyPatterns = [
      RegExp(
          r'\b(annual|annually|yearly|per\s+year|every\s+year|12\s+months?|yearly\s+subscription|annual\s+plan)\b',
          caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:year|yr|years?)\b', caseSensitive: false),
    ];

    // Half-yearly/Semi-annual patterns
    final halfYearlyPatterns = [
      RegExp(
          r'\b(semi-?annual|bi-?annual|half-?yearly|half-?year|6\s+months?|every\s+6\s+months?)\b',
          caseSensitive: false),
    ];

    // Quarterly patterns
    final quarterlyPatterns = [
      RegExp(
          r'\b(quarterly|per\s+quarter|every\s+quarter|3\s+months?|every\s+3\s+months?)\b',
          caseSensitive: false),
    ];

    // Monthly patterns
    final monthlyPatterns = [
      RegExp(
          r'\b(monthly|per\s+month|every\s+month|monthly\s+subscription|30\s+days?)\b',
          caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:month|mo|months?)\b', caseSensitive: false),
    ];

    // Weekly patterns
    final weeklyPatterns = [
      RegExp(
          r'\b(weekly|per\s+week|every\s+week|weekly\s+subscription|7\s+days?)\b',
          caseSensitive: false),
      RegExp(r'\b(\d+)\s*(?:week|wk|weeks?)\b', caseSensitive: false),
    ];

    // Check in order of specificity
    for (final pattern in yearlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final num = int.tryParse(match!.group(1)!);
          if (num != null && num == 1) return BillingCycle.yearly;
        } else {
          return BillingCycle.yearly;
        }
      }
    }

    for (final pattern in halfYearlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        return BillingCycle.halfYearly;
      }
    }

    for (final pattern in quarterlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        return BillingCycle.quarterly;
      }
    }

    for (final pattern in monthlyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final num = int.tryParse(match!.group(1)!);
          if (num != null) {
            if (num == 1 || num == 2) return BillingCycle.monthly;
            if (num == 3) return BillingCycle.quarterly;
            if (num == 6) return BillingCycle.halfYearly;
            if (num == 12) return BillingCycle.yearly;
          }
        }
        return BillingCycle.monthly;
      }
    }

    for (final pattern in weeklyPatterns) {
      if (pattern.hasMatch(lowerText)) {
        final match = pattern.firstMatch(lowerText);
        if (match?.groupCount == 1 && match?.group(1) != null) {
          final num = int.tryParse(match!.group(1)!);
          if (num != null && num == 1) return BillingCycle.weekly;
        } else {
          return BillingCycle.weekly;
        }
      }
    }

    // Fallback
    if (lowerText.contains('year') || lowerText.contains('annual')) {
      return BillingCycle.yearly;
    } else if (lowerText.contains('quarter')) {
      return BillingCycle.quarterly;
    } else if (lowerText.contains('week')) {
      return BillingCycle.weekly;
    }

    return BillingCycle.monthly;
  }

  /// Comprehensive category detection (matching email scanner)
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
