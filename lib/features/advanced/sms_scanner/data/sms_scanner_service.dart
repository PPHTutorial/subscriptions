import 'dart:async';
import 'package:telephony/telephony.dart';
import '../../../subscriptions/domain/subscription.dart';

/// Service for scanning SMS messages to detect subscription transactions
class SmsScannerService {
  final Telephony _telephony = Telephony.instance;
  StreamSubscription<List<SmsMessage>>? _smsSubscription;
  final List<SmsMessage> _scannedMessages = [];

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
    // Match currency patterns: GHS 9.99, NGN 1000, USD 10.00, etc.
    final patterns = [
      RegExp(r'(GHS|NGN|USD|EUR|GBP|INR)\s*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*(GHS|NGN|USD|EUR|GBP|INR)', caseSensitive: false),
      RegExp(r'[\$€£¥₹]\s*(\d+\.?\d*)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        String? currency;
        double? amount;

        if (match.groupCount >= 2) {
          currency = match.group(1)?.toUpperCase();
          amount = double.tryParse(match.group(2) ?? '');
          if (amount == null) {
            currency = match.group(2)?.toUpperCase();
            amount = double.tryParse(match.group(1) ?? '');
          }
        } else {
          amount = double.tryParse(match.group(1) ?? '');
          currency = 'USD'; // Default
        }

        if (amount != null && amount > 0) {
          return {'cost': amount, 'currency': currency ?? 'USD'};
        }
      }
    }
    return null;
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
    final lowerBody = body.toLowerCase();

    if (lowerBody.contains('yearly') || lowerBody.contains('annual')) {
      return BillingCycle.yearly;
    } else if (lowerBody.contains('quarterly')) {
      return BillingCycle.quarterly;
    } else if (lowerBody.contains('weekly')) {
      return BillingCycle.weekly;
    } else {
      // Check frequency by analyzing past messages
      // For now, default to monthly
      return BillingCycle.monthly;
    }
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
      category: _inferCategory(serviceName),
      paymentMethod: paymentMethod ?? 'Unknown',
      reminderDays: [7, 3, 1],
    );
  }

  SubscriptionCategory _inferCategory(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('netflix') ||
        name.contains('spotify') ||
        name.contains('disney') ||
        name.contains('hulu')) {
      return SubscriptionCategory.entertainment;
    } else if (name.contains('adobe') ||
        name.contains('microsoft') ||
        name.contains('office')) {
      return SubscriptionCategory.productivity;
    } else {
      return SubscriptionCategory.other;
    }
  }
}
