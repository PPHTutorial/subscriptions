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
    return ReceiptExtractionResult(
      success: true,
      serviceName: data['service'] ?? data['serviceName'] ?? data['provider'],
      cost: _parseCost(data['amount'] ?? data['cost'] ?? data['price']),
      currencyCode: data['currency'] ?? data['currencyCode'] ?? 'USD',
      renewalDate:
          _parseDate(data['date'] ?? data['renewalDate'] ?? data['expiryDate']),
      billingCycle: _parseBillingCycle(data['billingCycle'] ?? data['cycle']),
      paymentMethod: data['paymentMethod'] ?? data['payment'],
      rawText: data.toString(),
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
    return ReceiptExtractionResult(
      success: true,
      serviceName: json['serviceName'] as String? ??
          json['service'] as String? ??
          json['provider'] as String?,
      cost: _parseCost(json['cost'] ?? json['amount'] ?? json['price']),
      currencyCode: json['currencyCode'] as String? ??
          json['currency'] as String? ??
          'USD',
      renewalDate: _parseDate(json['renewalDate'] ??
          json['date'] ??
          json['expiryDate'] ??
          json['expiresOn']),
      billingCycle: _parseBillingCycle(json['billingCycle'] ?? json['cycle']),
      paymentMethod:
          json['paymentMethod'] as String? ?? json['payment'] as String?,
      rawText: jsonEncode(json),
    );
  }

  /// Parse HTML content from URL
  ReceiptExtractionResult _parseHtmlContent(String html, String url) {
    // Extract text from HTML (simple extraction)
    final text = _extractTextFromHtml(html);

    // Try to extract subscription info from text
    final serviceName = _extractServiceName(text, url);
    final cost = _extractCost(text);
    final date = _extractDate(text);

    return ReceiptExtractionResult(
      success: serviceName != null && cost != null,
      serviceName: serviceName,
      cost: cost,
      currencyCode: _extractCurrency(text) ?? 'USD',
      renewalDate: date,
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
    final patterns = [
      RegExp(r'amount[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'cost[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'price[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'\$([0-9.]+)', caseSensitive: false),
      RegExp(r'([0-9.]+)\s*(USD|EUR|GBP|GHS|NGN)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        return double.tryParse(match.group(1) ?? '');
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
}
