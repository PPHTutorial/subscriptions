import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../../subscriptions/domain/subscription.dart';

/// Service for extracting subscription details from receipt/invoice images using OCR
class ReceiptOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  /// Pick an image from gallery or camera
  Future<File?> pickImage({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return null;
    return File(image.path);
  }

  /// Extract text from image using OCR
  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    final text = recognizedText.text;
    return text;
  }

  /// Extract subscription details from receipt/invoice image
  Future<ReceiptExtractionResult> extractSubscriptionDetails(
      File imageFile) async {
    try {
      final text = await extractText(imageFile);
      return _parseReceiptText(text);
    } catch (e) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Failed to process image: $e',
      );
    }
  }

  ReceiptExtractionResult _parseReceiptText(String text) {
    final lowerText = text.toLowerCase();

    // Extract service name
    final serviceName = _extractServiceName(text, lowerText);

    // Extract cost
    final costMatch = _extractCost(text, lowerText);

    // Extract date
    final date = _extractDate(text, lowerText);

    // Extract billing cycle
    final billingCycle = _extractBillingCycle(lowerText);

    // Extract currency
    final currency = costMatch?['currency'] as String? ?? 'USD';
    final cost = costMatch?['cost'] as double?;

    if (serviceName == null || cost == null) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Could not extract required information from receipt',
        rawText: text,
      );
    }

    return ReceiptExtractionResult(
      success: true,
      serviceName: serviceName,
      cost: cost,
      currencyCode: currency,
      renewalDate: date ?? DateTime.now().add(const Duration(days: 30)),
      billingCycle: billingCycle,
      category: _inferCategory(serviceName),
      paymentMethod: _extractPaymentMethod(text, lowerText),
      rawText: text,
    );
  }

  String? _extractServiceName(String text, String lowerText) {
    // Look for common service names
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
      if (lowerText.contains(service)) {
        return service.split(' ').map((word) {
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
      }
    }

    // Try to extract from invoice header
    final headerPattern = RegExp(
        r'^([A-Z][A-Za-z\s&]+?)(?:\s+invoice|\s+receipt|\s+bill)',
        caseSensitive: false);
    final headerMatch = headerPattern.firstMatch(text);
    if (headerMatch != null) {
      final name = headerMatch.group(1)?.trim();
      if (name != null && name.length < 50) {
        return name;
      }
    }

    // Try to extract from "Subscription to" or "Service:" patterns
    final patterns = [
      RegExp(r'subscription\s+to\s+([A-Za-z\s&]+)', caseSensitive: false),
      RegExp(r'service[:\s]+([A-Za-z\s&]+)', caseSensitive: false),
      RegExp(r'([A-Z][A-Za-z\s&]+)\s+subscription', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null &&
            name.length < 50 &&
            !name.toLowerCase().contains('invoice')) {
          return name;
        }
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractCost(String text, String lowerText) {
    // Look for total amount patterns
    final patterns = [
      RegExp(r'total[:\s]+[\$€£¥₹]?\s*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'amount[:\s]+[\$€£¥₹]?\s*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'[\$€£¥₹]\s*(\d+\.?\d*)', caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*(USD|EUR|GBP|INR|GHS|NGN)', caseSensitive: false),
    ];

    double? maxAmount;
    String? currency;

    for (final pattern in patterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final amount = double.tryParse(match.group(1) ?? '');
        if (amount != null && amount > 0) {
          if (maxAmount == null || amount > maxAmount) {
            maxAmount = amount;

            // Extract currency
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
              currency = 'USD'; // Default
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

  DateTime? _extractDate(String text, String lowerText) {
    // Look for date patterns
    final datePatterns = [
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'(\w+\s+\d{1,2},?\s+\d{4})', caseSensitive: false),
      RegExp(r'date[:\s]+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
          caseSensitive: false),
      RegExp(r'(\d{1,2}\s+\w+\s+\d{4})', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            return date;
          }
        }
      }
    }

    return null;
  }

  BillingCycle _extractBillingCycle(String lowerText) {
    if (lowerText.contains('yearly') ||
        lowerText.contains('annual') ||
        lowerText.contains('year')) {
      return BillingCycle.yearly;
    } else if (lowerText.contains('quarterly') ||
        lowerText.contains('quarter')) {
      return BillingCycle.quarterly;
    } else if (lowerText.contains('weekly') || lowerText.contains('week')) {
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
    } else {
      return SubscriptionCategory.other;
    }
  }

  String? _extractPaymentMethod(String text, String lowerText) {
    if (lowerText.contains('visa') ||
        lowerText.contains('mastercard') ||
        lowerText.contains('amex') ||
        lowerText.contains('american express')) {
      return 'Credit Card';
    } else if (lowerText.contains('paypal')) {
      return 'PayPal';
    } else if (lowerText.contains('apple pay')) {
      return 'Apple Pay';
    } else if (lowerText.contains('google pay')) {
      return 'Google Pay';
    } else if (lowerText.contains('debit')) {
      return 'Debit Card';
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}

class ReceiptExtractionResult {
  ReceiptExtractionResult({
    required this.success,
    this.serviceName,
    this.cost,
    this.currencyCode,
    this.renewalDate,
    this.billingCycle,
    this.category,
    this.paymentMethod,
    this.error,
    this.rawText,
  });

  final bool success;
  final String? serviceName;
  final double? cost;
  final String? currencyCode;
  final DateTime? renewalDate;
  final BillingCycle? billingCycle;
  final SubscriptionCategory? category;
  final String? paymentMethod;
  final String? error;
  final String? rawText;

  Subscription? toSubscription() {
    if (!success ||
        serviceName == null ||
        cost == null ||
        renewalDate == null) {
      return null;
    }

    return Subscription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      serviceName: serviceName!,
      billingCycle: billingCycle ?? BillingCycle.monthly,
      renewalDate: renewalDate!,
      currencyCode: currencyCode ?? 'USD',
      cost: cost!,
      autoRenew: true,
      category: category ?? SubscriptionCategory.other,
      paymentMethod: paymentMethod ?? 'Unknown',
      reminderDays: [7, 3, 1],
      notes: rawText,
    );
  }
}
