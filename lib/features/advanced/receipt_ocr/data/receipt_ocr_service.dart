import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
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

  /// Pick an image from camera or gallery
  /// Uses image_picker which works reliably for images
  Future<ReceiptFile?> pickImageFile({bool fromCamera = false}) async {
    final image = await pickImage(fromCamera: fromCamera);
    if (image == null) return null;
    return ReceiptFile(
      file: image,
      type: ReceiptFileType.image,
    );
  }

  /// Pick a document file (PDF or DOCX)
  /// Uses file_picker for document selection
  Future<ReceiptFile?> pickDocumentFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
        allowMultiple: false,
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.single.path == null) {
        return null;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final extension = result.files.single.extension?.toLowerCase();

      ReceiptFileType fileType;
      if (extension == 'pdf') {
        fileType = ReceiptFileType.pdf;
      } else if (extension == 'docx') {
        fileType = ReceiptFileType.docx;
      } else {
        // Default to PDF if extension is unclear
        fileType = ReceiptFileType.pdf;
      }

      return ReceiptFile(
        file: file,
        type: fileType,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Pick a file (image, PDF, or DOCX) - legacy method for backward compatibility
  /// For images, use pickImageFile() instead
  @Deprecated(
      'Use pickImageFile() for images or pickDocumentFile() for documents')
  Future<ReceiptFile?> pickFile({bool fromCamera = false}) async {
    // Always use image_picker for images (works reliably)
    return pickImageFile(fromCamera: fromCamera);
  }

  /// Extract text from image using OCR
  /// Uses Google ML Kit Text Recognition with improved processing
  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    // Get all text blocks and combine them with proper spacing
    final textBuffer = StringBuffer();

    // Process text blocks to maintain structure
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        textBuffer.writeln(line.text);
      }
      textBuffer.writeln(''); // Add spacing between blocks
    }

    final text = textBuffer.toString();

    // Clean up common OCR errors
    return _cleanOcrText(text);
  }

  /// Clean common OCR errors and normalize text
  String _cleanOcrText(String text) {
    // Fix common OCR mistakes
    return text
        .replaceAll(RegExp(r'\s+'), ' ') // Multiple spaces to single
        .replaceAll(RegExp(r'[|]'), 'I') // Pipe to I
        .replaceAll(RegExp(r'[0O]'), '0') // O to 0 in numbers
        .replaceAll(RegExp(r'[Il1]'), '1') // I/l to 1 in numbers
        .trim();
  }

  /// Extract text from PDF file
  /// Note: The pdf package doesn't directly extract text, so we return a placeholder
  /// In production, consider using a server-side PDF text extraction service
  Future<String> extractTextFromPdf(File pdfFile) async {
    try {
      // PDF text extraction requires additional libraries
      // For now, we'll show an error message suggesting to use image or DOCX
      throw UnimplementedError(
        'PDF text extraction is not yet fully implemented. Please convert PDF to image or use DOCX format.',
      );
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  /// Extract text from DOCX file
  Future<String> extractTextFromDocx(File docxFile) async {
    try {
      final bytes = await docxFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final text = StringBuffer();

      // DOCX files are ZIP archives containing XML files
      // Extract text from document.xml
      for (final file in archive) {
        if (file.name == 'word/document.xml') {
          final xmlContent = String.fromCharCodes(file.content as List<int>);
          // Simple regex to extract text between <w:t> tags
          final textPattern = RegExp(r'<w:t[^>]*>([^<]*)</w:t>');
          final matches = textPattern.allMatches(xmlContent);
          for (final match in matches) {
            text.write(match.group(1) ?? '');
            text.write(' ');
          }
        }
      }

      return text.toString().trim();
    } catch (e) {
      throw Exception('Failed to extract text from DOCX: $e');
    }
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

  /// Extract subscription details from receipt file (image, PDF, or DOCX)
  Future<ReceiptExtractionResult> extractSubscriptionDetailsFromFile(
      ReceiptFile receiptFile) async {
    try {
      String text;

      switch (receiptFile.type) {
        case ReceiptFileType.image:
          text = await extractText(receiptFile.file);
          break;
        case ReceiptFileType.pdf:
          text = await extractTextFromPdf(receiptFile.file);
          break;
        case ReceiptFileType.docx:
          text = await extractTextFromDocx(receiptFile.file);
          break;
      }

      return _parseReceiptText(text);
    } catch (e) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Failed to process file: $e',
      );
    }
  }

  ReceiptExtractionResult _parseReceiptText(String text) {
    if (text.trim().isEmpty) {
      return ReceiptExtractionResult(
        success: false,
        error: 'No text found in receipt',
        rawText: text,
      );
    }

    final lowerText = text.toLowerCase();
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Extract all fields using improved parsing
    final serviceName = _extractServiceName(text, lowerText, lines);
    final costMatch = _extractCost(text, lowerText, lines);
    final date = _extractDate(text, lowerText, lines);

    // Extract additional fields (for future use or debugging)
    _extractCustomer(text, lowerText, lines);
    _extractPhone(text, lowerText, lines);
    _extractReference(text, lowerText, lines);

    final currency =
        costMatch?['currency'] as String? ?? _extractCurrency(text, lowerText);
    final cost = costMatch?['cost'] as double?;

    // Extract billing cycle
    final billingCycle = _extractBillingCycle(lowerText);

    // Validate required fields
    if (serviceName == null || cost == null) {
      return ReceiptExtractionResult(
        success: false,
        error:
            'Could not extract required information (Service: ${serviceName != null ? "✓" : "✗"}, Amount: ${cost != null ? "✓" : "✗"})',
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

  String? _extractServiceName(
      String text, String lowerText, List<String> lines) {
    // Look for common service names (expanded list)
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

    // First, try exact service name matches
    for (final service in services) {
      if (lowerText.contains(service)) {
        // Find the actual service name in the original text (preserve case)
        final servicePattern = RegExp(service, caseSensitive: false);
        final match = servicePattern.firstMatch(text);
        if (match != null) {
          return match.group(0)?.split(' ').map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              }).join(' ') ??
              service;
        }
      }
    }

    // Try to extract from invoice/receipt header (first few lines)
    for (int i = 0; i < lines.length.clamp(0, 5); i++) {
      final line = lines[i];
      final headerPatterns = [
        RegExp(
            r'^([A-Z][A-Za-z0-9\s&.,-]+?)(?:\s+(?:invoice|receipt|bill|statement|payment))',
            caseSensitive: false),
        RegExp(r'^([A-Z][A-Za-z0-9\s&.,-]{3,40})$'), // Standalone company name
      ];

      for (final pattern in headerPatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          final name = match.group(1)?.trim();
          if (name != null &&
              name.length >= 3 &&
              name.length <= 50 &&
              !name.toLowerCase().contains('invoice') &&
              !name.toLowerCase().contains('receipt') &&
              !name.toLowerCase().contains('date') &&
              !name.toLowerCase().contains('amount')) {
            return name;
          }
        }
      }
    }

    // Try key-value patterns
    final keyValuePatterns = [
      RegExp(
          r'(?:service|company|merchant|vendor|provider)[:\s]+([A-Za-z0-9\s&.,-]+)',
          caseSensitive: false),
      RegExp(
          r'(?:subscription\s+to|billed\s+by|charged\s+by)[:\s]+([A-Za-z0-9\s&.,-]+)',
          caseSensitive: false),
      RegExp(r'^([A-Z][A-Za-z0-9\s&.,-]+)\s+subscription',
          caseSensitive: false),
    ];

    for (final pattern in keyValuePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null &&
            name.length >= 3 &&
            name.length <= 50 &&
            !name.toLowerCase().contains('invoice') &&
            !name.toLowerCase().contains('receipt')) {
          return name;
        }
      }
    }

    // Last resort: use first substantial line that looks like a company name
    for (final line in lines.take(10)) {
      if (line.length >= 3 &&
          line.length <= 50 &&
          RegExp(r'^[A-Z]').hasMatch(line) &&
          !RegExp(r'(?:invoice|receipt|bill|date|amount|total|phone|tel|email|reference)',
                  caseSensitive: true)
              .hasMatch(line.toLowerCase()) &&
          !RegExp(r'^\d').hasMatch(line)) {
        return line;
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractCost(
      String text, String lowerText, List<String> lines) {
    // Comprehensive amount extraction patterns
    final amountPatterns = [
      // Total amount patterns (highest priority)
      RegExp(
          r'(?:total|amount\s+due|balance|charge|payment)[:\s]+[\$€£¥₹¢]?\s*([\d,]+\.?\d*)',
          caseSensitive: false),
      RegExp(r'(?:total|amount)[:\s]+([\d,]+\.?\d*)\s*([A-Z]{3})?',
          caseSensitive: false),

      // Currency symbol patterns
      RegExp(r'[\$€£¥₹¢]\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*[\$€£¥₹¢]', caseSensitive: false),

      // Currency code patterns
      RegExp(
          r'([\d,]+\.?\d*)\s*(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS|RWF|ETB|CAD|AUD|NZD|JPY|CNY|SGD|HKD|CHF|SEK|NOK|DKK|PLN|CZK|HUF|RON|BGN|HRK)',
          caseSensitive: false),
      RegExp(
          r'(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS|RWF|ETB|CAD|AUD|NZD|JPY|CNY|SGD|HKD|CHF|SEK|NOK|DKK|PLN|CZK|HUF|RON|BGN|HRK)\s*([\d,]+\.?\d*)',
          caseSensitive: false),

      // Generic number patterns (last resort)
      RegExp(r'\b([\d,]+\.\d{2})\b', caseSensitive: false), // Decimal amounts
    ];

    List<Map<String, dynamic>> amounts = [];

    for (final pattern in amountPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(amountStr);

        if (amount != null && amount > 0 && amount < 1000000) {
          // Reasonable range
          String? currency;

          // Extract currency from match
          if (match.groupCount >= 2 && match.group(2) != null) {
            currency = match.group(2)!.toUpperCase();
          } else {
            // Detect from symbol or context
            currency = _detectCurrencyFromContext(match.group(0) ?? '', text);
          }

          final matchText = match.group(0);
          amounts.add({
            'amount': amount,
            'currency': currency.isNotEmpty ? currency : 'USD',
            'priority': _getAmountPriority(matchText ?? '', lowerText),
          });
        }
      }
    }

    if (amounts.isEmpty) return null;

    // Sort by priority and take the highest (most likely to be the total)
    amounts
        .sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
    final bestMatch = amounts.first;

    return {
      'cost': bestMatch['amount'] as double,
      'currency': bestMatch['currency'] as String,
    };
  }

  int _getAmountPriority(String match, String lowerText) {
    int priority = 0;
    final lowerMatch = match.toLowerCase();

    // Higher priority for "total" mentions
    if (lowerMatch.contains('total') || lowerText.contains('total'))
      priority += 10;
    if (lowerMatch.contains('amount') || lowerText.contains('amount'))
      priority += 8;
    if (lowerMatch.contains('due') || lowerText.contains('due')) priority += 7;
    if (lowerMatch.contains('balance') || lowerText.contains('balance'))
      priority += 6;

    // Lower priority for subtotals
    if (lowerMatch.contains('subtotal') || lowerText.contains('subtotal'))
      priority -= 5;
    if (lowerMatch.contains('tax') || lowerText.contains('tax')) priority -= 3;

    return priority;
  }

  String _detectCurrencyFromContext(String match, String text) {
    // Check for currency symbols
    if (match.contains('\$') || text.contains('\$')) return 'USD';
    if (match.contains('€') || text.contains('€')) return 'EUR';
    if (match.contains('£') || text.contains('£')) return 'GBP';
    if (match.contains('₹') || text.contains('₹')) return 'INR';
    if (match.contains('¥') || text.contains('¥')) return 'JPY';
    if (match.contains('¢') || text.contains('¢')) return 'GHS';

    // Check for currency codes in text
    final currencyCodes = [
      'USD',
      'EUR',
      'GBP',
      'INR',
      'GHS',
      'NGN',
      'ZAR',
      'KES'
    ];
    for (final code in currencyCodes) {
      if (text.contains(code)) return code;
    }

    return 'USD'; // Default
  }

  DateTime? _extractDate(String text, String lowerText, List<String> lines) {
    // Comprehensive date patterns
    final datePatterns = [
      // Date: MM/DD/YYYY or DD/MM/YYYY
      RegExp(
          r'(?:date|issued|billed|paid|transaction)[:\s]+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
          caseSensitive: false),
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),

      // Date: Month DD, YYYY
      RegExp(r'(?:date|issued|billed|paid)[:\s]+(\w+\s+\d{1,2},?\s+\d{4})',
          caseSensitive: false),
      RegExp(r'(\w+\s+\d{1,2},?\s+\d{4})', caseSensitive: false),

      // Date: DD Month YYYY
      RegExp(r'(\d{1,2}\s+\w+\s+\d{4})', caseSensitive: false),

      // Date: YYYY-MM-DD
      RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})', caseSensitive: false),

      // Date: DD.MM.YYYY
      RegExp(r'(\d{1,2}\.\d{1,2}\.\d{2,4})', caseSensitive: false),
    ];

    List<DateTime> foundDates = [];

    for (final pattern in datePatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          // Try parsing with different formats
          DateTime? date = _parseDate(dateStr);
          if (date != null &&
              date.isAfter(DateTime(2020)) &&
              date.isBefore(DateTime(2030))) {
            foundDates.add(date);
          }
        }
      }
    }

    // Return the most recent date (likely the transaction date)
    if (foundDates.isNotEmpty) {
      foundDates.sort((a, b) => b.compareTo(a));
      return foundDates.first;
    }

    return null;
  }

  DateTime? _parseDate(String dateStr) {
    // Try standard parsing first
    DateTime? date = DateTime.tryParse(dateStr);
    if (date != null) return date;

    // Try common formats
    final formats = [
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})'),
      RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{2,4})'),
    ];

    for (final format in formats) {
      final match = format.firstMatch(dateStr);
      if (match != null) {
        final day = int.tryParse(match.group(1) ?? '');
        final month = int.tryParse(match.group(2) ?? '');
        var year = int.tryParse(match.group(3) ?? '');

        if (day != null && month != null && year != null) {
          // Handle 2-digit years
          if (year < 100) {
            year += year < 50 ? 2000 : 1900;
          }

          try {
            return DateTime(year, month, day);
          } catch (e) {
            continue;
          }
        }
      }
    }

    // Try named month format
    final monthNames = <String, int>{
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };

    final namedPattern =
        RegExp(r'(\w+)\s+(\d{1,2}),?\s+(\d{4})', caseSensitive: false);
    final namedMatch = namedPattern.firstMatch(dateStr);
    if (namedMatch != null) {
      final monthName = namedMatch.group(1)?.toLowerCase() ?? '';
      final day = int.tryParse(namedMatch.group(2) ?? '');
      final year = int.tryParse(namedMatch.group(3) ?? '');

      if (monthNames.containsKey(monthName) && day != null && year != null) {
        try {
          return DateTime(year, monthNames[monthName]!, day);
        } catch (e) {
          return null;
        }
      }
    }

    return null;
  }

  String? _extractCustomer(String text, String lowerText, List<String> lines) {
    final customerPatterns = [
      RegExp(
          r'(?:customer|client|name|bill\s+to|account\s+holder)[:\s]+([A-Za-z\s.,-]+)',
          caseSensitive: false),
      RegExp(r'(?:customer\s+name|client\s+name)[:\s]+([A-Za-z\s.,-]+)',
          caseSensitive: false),
    ];

    for (final pattern in customerPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final customer = match.group(1)?.trim();
        if (customer != null &&
            customer.length >= 2 &&
            customer.length <= 100) {
          return customer;
        }
      }
    }

    return null;
  }

  String? _extractPhone(String text, String lowerText, List<String> lines) {
    final phonePatterns = [
      RegExp(r'(?:phone|tel|telephone|mobile|cell)[:\s]*([+]?[\d\s\-()]{7,20})',
          caseSensitive: false),
      RegExp(r'([+]?\d{1,3}[\s\-]?\(?\d{1,4}\)?[\s\-]?\d{1,4}[\s\-]?\d{1,9})',
          caseSensitive: false),
    ];

    for (final pattern in phonePatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final phone = match.group(1)?.replaceAll(RegExp(r'[\s\-()]'), '');
        if (phone != null && phone.length >= 7 && phone.length <= 15) {
          return phone;
        }
      }
    }

    return null;
  }

  String? _extractReference(String text, String lowerText, List<String> lines) {
    final refPatterns = [
      RegExp(
          r'(?:reference|ref|transaction\s+id|invoice\s+no|receipt\s+no|order\s+no)[:\s#]+([A-Za-z0-9\-]+)',
          caseSensitive: false),
      RegExp(r'(?:ref\s+no|ref\s+number)[:\s#]+([A-Za-z0-9\-]+)',
          caseSensitive: false),
      RegExp(r'#([A-Z0-9]{6,20})',
          caseSensitive: false), // Standalone reference numbers
    ];

    for (final pattern in refPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final ref = match.group(1)?.trim();
        if (ref != null && ref.length >= 4 && ref.length <= 30) {
          return ref;
        }
      }
    }

    return null;
  }

  String _extractCurrency(String text, String lowerText) {
    // Check for currency symbols first
    if (text.contains('\$')) return 'USD';
    if (text.contains('€')) return 'EUR';
    if (text.contains('£')) return 'GBP';
    if (text.contains('₹')) return 'INR';
    if (text.contains('¥')) return 'JPY';
    if (text.contains('¢')) return 'GHS';

    // Check for currency codes
    final currencyCodes = [
      'USD',
      'EUR',
      'GBP',
      'INR',
      'GHS',
      'NGN',
      'ZAR',
      'KES',
      'UGX',
      'TZS'
    ];
    for (final code in currencyCodes) {
      if (text.contains(code)) return code;
    }

    return 'USD'; // Default
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

/// Enum for receipt file types
enum ReceiptFileType {
  image,
  pdf,
  docx,
}

/// Class to represent a receipt file with its type
class ReceiptFile {
  ReceiptFile({
    required this.file,
    required this.type,
  });

  final File file;
  final ReceiptFileType type;
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
