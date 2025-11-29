import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/currency/currency_conversion_service.dart';
import '../../../subscriptions/domain/subscription.dart';

/// Service for extracting subscription details from receipt/invoice images using OCR
/// Uses Google ML Kit Text Recognition with intelligent text analysis and currency conversion
class ReceiptOcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  final CurrencyConversionService _currencyService =
      CurrencyConversionService();

  ReceiptOcrService();

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
  /// Uses Google ML Kit Text Recognition with intelligent text processing for better accuracy
  Future<String> extractText(File imageFile) async {
    final extractedText = await _extractWithGoogleMLKit(imageFile);

    // Apply intelligent text cleaning and normalization
    return _intelligentTextCleaning(extractedText);
  }

  /// Extract text using Google ML Kit with layout preservation
  Future<String> _extractWithGoogleMLKit(File imageFile) async {
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final RecognizedText recognizedText =
        await _textRecognizer.processImage(inputImage);

    // Extract text with layout preservation (similar to Google Lens)
    return _formatTextWithLayout(recognizedText);
  }

  /// Format text preserving layout structure from OCR blocks
  /// Uses bounding box positions to maintain spacing and alignment
  String _formatTextWithLayout(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return '';
    }

    // Sort blocks by vertical position (top to bottom)
    final sortedBlocks = List<TextBlock>.from(recognizedText.blocks)
      ..sort((a, b) {
        final aTop = a.boundingBox.top;
        final bTop = b.boundingBox.top;
        // Allow some tolerance for blocks on same line
        if ((aTop - bTop).abs() < 20) {
          return a.boundingBox.left.compareTo(b.boundingBox.left);
        }
        return aTop.compareTo(bTop);
      });

    final textBuffer = StringBuffer();
    double? previousBlockBottom;

    for (int i = 0; i < sortedBlocks.length; i++) {
      final block = sortedBlocks[i];
      final blockTop = block.boundingBox.top;
      final blockBottom = block.boundingBox.bottom;

      // Add spacing between blocks based on vertical distance
      if (previousBlockBottom != null) {
        final verticalGap = blockTop - previousBlockBottom;
        // If gap is significant (new section), add extra spacing
        if (verticalGap > 30) {
          textBuffer.writeln('');
        }
      }

      // Process lines within block, preserving horizontal alignment
      final sortedLines = List<TextLine>.from(block.lines)
        ..sort((a, b) {
          final aTop = a.boundingBox.top;
          final bTop = b.boundingBox.top;
          // Lines on same horizontal level
          if ((aTop - bTop).abs() < 15) {
            return a.boundingBox.left.compareTo(b.boundingBox.left);
          }
          return aTop.compareTo(bTop);
        });

      double? previousLineBottom;
      for (int j = 0; j < sortedLines.length; j++) {
        final line = sortedLines[j];
        final lineTop = line.boundingBox.top;

        // Add line break if there's vertical gap
        if (previousLineBottom != null) {
          final lineGap = lineTop - previousLineBottom;
          if (lineGap > 10) {
            textBuffer.writeln('');
          }
        }

        // Process elements (words) in line to preserve spacing
        final sortedElements = List<TextElement>.from(line.elements)
          ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

        double? previousElementRight;
        for (final element in sortedElements) {
          final elementLeft = element.boundingBox.left;

          // Add spacing based on horizontal gap between elements
          if (previousElementRight != null) {
            final horizontalGap = elementLeft - previousElementRight;
            // If gap is significant (likely intentional spacing), add spaces
            if (horizontalGap > 5) {
              // Calculate approximate number of spaces based on gap
              final spaces = (horizontalGap / 8).round().clamp(1, 10);
              textBuffer.write(' ' * spaces);
            } else {
              textBuffer.write(' ');
            }
          }

          textBuffer.write(element.text);
          previousElementRight = element.boundingBox.right;
        }

        textBuffer.writeln('');
        previousLineBottom = line.boundingBox.bottom;
      }

      previousBlockBottom = blockBottom;
    }

    return textBuffer.toString();
  }

  /// Intelligent text cleaning with OCR error correction
  String _intelligentTextCleaning(String text) {
    // Step 1: Fix common OCR character recognition errors
    String cleaned = text
        .replaceAll(RegExp(r'[|]'), 'I') // Pipe to I
        .replaceAll(RegExp(r'\b0([a-z])', caseSensitive: false),
            'O\$1') // 0 to O in words
        .replaceAll(RegExp(r'\b([a-z])0\b', caseSensitive: false),
            '\$1O') // 0 to O at word end
        .replaceAll(RegExp(r'\b1([a-z])', caseSensitive: false),
            'l\$1') // 1 to l in words
        .replaceAll(RegExp(r'\b([a-z])1\b', caseSensitive: false),
            '\$1l') // 1 to l at word end
        .replaceAll(RegExp(r'[Il1](?=\d)'), '1') // I/l to 1 before numbers
        .replaceAll(RegExp(r'(?<=\d)[Il1]'), '1'); // I/l to 1 after numbers

    // Step 2: Normalize whitespace while preserving structure
    cleaned = cleaned
        .replaceAll(
            RegExp(r'[ \t]+'), ' ') // Multiple spaces/tabs to single space
        .replaceAll(
            RegExp(r'\n\s*\n\s*\n'), '\n\n') // Multiple newlines to double
        .trim();

    // Step 3: Fix common word recognition errors
    final wordCorrections = {
      'subscnptlon': 'subscription',
      'subscnption': 'subscription',
      'subscrlptlon': 'subscription',
      'paymcnt': 'payment',
      'paymcnts': 'payments',
      'rcnewal': 'renewal',
      'rcnew': 'renew',
      'amazon prlme': 'amazon prime',
      'netflx': 'netflix',
      'spotlfy': 'spotify',
      'microsoft offlce': 'microsoft office',
      'microsoft office 365': 'microsoft 365',
    };

    for (final entry in wordCorrections.entries) {
      cleaned = cleaned.replaceAll(
          RegExp(entry.key, caseSensitive: false), entry.value);
    }

    return cleaned;
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
      return await _intelligentParseReceiptText(text);
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

      return await _intelligentParseReceiptText(text);
    } catch (e) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Failed to process file: $e',
      );
    }
  }

  /// Intelligent parsing that uses ML-like analysis to extract subscription details
  /// This method is more flexible and can handle varied text formats
  /// Automatically converts extracted amounts to base currency to prevent over/under-population
  Future<ReceiptExtractionResult> _intelligentParseReceiptText(
      String text) async {
    if (text.trim().isEmpty) {
      return ReceiptExtractionResult(
        success: false,
        error: 'No text found in receipt',
        rawText: text,
      );
    }

    // First, analyze if this text is subscription-related using intelligent scoring
    final subscriptionScore = _analyzeSubscriptionRelevance(text);
    if (subscriptionScore < 0.3) {
      return ReceiptExtractionResult(
        success: false,
        error: 'Text does not appear to be subscription-related',
        rawText: text,
      );
    }

    final lowerText = text.toLowerCase();
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Use intelligent extraction methods that don't rely on exact patterns
    final serviceName = _intelligentExtractServiceName(text, lowerText, lines);
    final costMatch = _intelligentExtractCost(text, lowerText, lines);
    final date = _intelligentExtractDate(text, lowerText, lines);

    final originalCurrency =
        costMatch?['currency'] as String? ?? _extractCurrency(text, lowerText);
    final originalCost = costMatch?['cost'] as double?;

    // Use original currency and cost - don't convert during save
    // Conversion will happen only when displaying for analytics
    double? finalCost = originalCost;
    String finalCurrency;

    if (originalCost != null && originalCurrency.isNotEmpty) {
      // Use original currency and cost as-is
      finalCost = originalCost;
      finalCurrency = originalCurrency;
    } else if (originalCost != null) {
      // If we have cost but no currency, use base currency
      finalCost = originalCost;
      finalCurrency = _currencyService.baseCurrency;
    } else {
      finalCurrency = _currencyService.baseCurrency;
    }

    // Extract billing cycle
    final billingCycle = _extractBillingCycle(lowerText);

    // More lenient validation - if we have high confidence in subscription relevance,
    // we can be more flexible with required fields
    if (serviceName == null && finalCost == null) {
      return ReceiptExtractionResult(
        success: false,
        error:
            'Could not extract required information (Service: ${serviceName != null ? "✓" : "✗"}, Amount: ${finalCost != null ? "✓" : "✗"})',
        rawText: text,
      );
    }

    // If we have at least one field and high subscription relevance, allow partial extraction
    if (serviceName == null || finalCost == null) {
      // Try to infer missing fields
      if (serviceName == null) {
        // Try to extract any company/service name from context
        final inferredName = _inferServiceNameFromContext(text, lines);
        if (inferredName != null && finalCost != null) {
          return ReceiptExtractionResult(
            success: true,
            serviceName: inferredName,
            cost: finalCost,
            currencyCode: finalCurrency,
            originalCost: originalCost,
            originalCurrency: originalCurrency,
            renewalDate: date ?? DateTime.now().add(const Duration(days: 30)),
            billingCycle: billingCycle,
            category: _inferCategory(inferredName),
            paymentMethod: _extractPaymentMethod(text, lowerText),
            rawText: text,
          );
        }
      }
    }

    return ReceiptExtractionResult(
      success: true,
      serviceName: serviceName ?? 'Unknown Service',
      cost: finalCost ?? 0.0,
      currencyCode: finalCurrency,
      originalCost: originalCost,
      originalCurrency: originalCurrency,
      renewalDate: date ?? DateTime.now().add(const Duration(days: 30)),
      billingCycle: billingCycle,
      category: serviceName != null ? _inferCategory(serviceName) : null,
      paymentMethod: _extractPaymentMethod(text, lowerText),
      rawText: text,
    );
  }

  /// Analyze if text is subscription-related using intelligent scoring
  /// Returns a score from 0.0 to 1.0 indicating subscription relevance
  double _analyzeSubscriptionRelevance(String text) {
    final lowerText = text.toLowerCase();
    double score = 0.0;

    // Subscription-related keywords (weighted)
    final subscriptionKeywords = {
      'subscription': 0.3,
      'renewal': 0.25,
      'renew': 0.2,
      'recurring': 0.25,
      'monthly': 0.15,
      'yearly': 0.15,
      'annual': 0.15,
      'billing': 0.2,
      'auto-renew': 0.25,
      'auto renew': 0.25,
      'charged': 0.15,
      'payment': 0.1,
      'invoice': 0.1,
      'receipt': 0.1,
    };

    // Service name indicators
    final serviceIndicators = [
      'netflix',
      'spotify',
      'amazon',
      'disney',
      'hulu',
      'hbo',
      'apple music',
      'youtube',
      'adobe',
      'microsoft',
      'office',
      'dropbox',
      'icloud',
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
    ];

    // Check for subscription keywords
    for (final entry in subscriptionKeywords.entries) {
      if (lowerText.contains(entry.key)) {
        score += entry.value;
      }
    }

    // Check for service names
    for (final service in serviceIndicators) {
      if (lowerText.contains(service)) {
        score += 0.2;
        break; // Only count once
      }
    }

    // Check for amount patterns (indicates financial transaction)
    if (RegExp(r'[\$€£¥₹¢]\s*\d+|\d+\s*(USD|EUR|GBP|GHS|NGN)',
            caseSensitive: false)
        .hasMatch(text)) {
      score += 0.15;
    }

    // Check for date patterns (indicates transaction date)
    if (RegExp(r'\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\w+\s+\d{1,2},?\s+\d{4}',
            caseSensitive: false)
        .hasMatch(text)) {
      score += 0.1;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Intelligent service name extraction using fuzzy matching and context analysis
  String? _intelligentExtractServiceName(
      String text, String lowerText, List<String> lines) {
    // Expanded service names with variations and common misspellings
    final serviceVariations = {
      'netflix': ['netflix', 'netflx', 'netfli', 'netflixx'],
      'spotify': ['spotify', 'spotlfy', 'spotif', 'spotfy'],
      'amazon prime': [
        'amazon prime',
        'amazon prlme',
        'amazon prme',
        'amzn prime'
      ],
      'amazon': ['amazon', 'amzn', 'amazn'],
      'disney': ['disney', 'disney+', 'disney plus', 'dsney'],
      'disney+': ['disney+', 'disney plus', 'disney +'],
      'hulu': ['hulu', 'hul', 'huloo'],
      'hbo': ['hbo', 'hbo max', 'hbo maxx'],
      'hbo max': ['hbo max', 'hbo maxx', 'hbomax'],
      'apple music': ['apple music', 'apple muslc', 'applemusic'],
      'youtube premium': ['youtube premium', 'youtube prm', 'yt premium'],
      'youtube': ['youtube', 'youtub', 'yt'],
      'adobe': ['adobe', 'adob', 'adobe creative'],
      'microsoft': ['microsoft', 'microsoft', 'msft', 'microsoft'],
      'office 365': ['office 365', 'office365', 'microsoft 365', 'ms office'],
      'microsoft 365': ['microsoft 365', 'ms 365', 'office 365'],
      'dropbox': ['dropbox', 'dropbx', 'drop box'],
      'icloud': ['icloud', 'icloud+', 'icloud plus'],
      'google drive': ['google drive', 'gdrive', 'google drve'],
      'google': ['google', 'googl', 'google one'],
      'grammarly': ['grammarly', 'grammarly', 'gramarly'],
      'canva': ['canva', 'canva pro', 'canva'],
      'notion': ['notion', 'noton', 'notion+'],
      'figma': ['figma', 'figma', 'figma pro'],
      'slack': ['slack', 'slak', 'slack workspace'],
      'zoom': ['zoom', 'zoom pro', 'zoom meeting'],
      'linkedin': ['linkedin', 'linked in', 'linkedln'],
      'github': ['github', 'git hub', 'github pro'],
      'aws': ['aws', 'amazon web services', 'amazon aws'],
      'azure': ['azure', 'microsoft azure', 'azure cloud'],
    };

    // Try fuzzy matching with variations
    for (final entry in serviceVariations.entries) {
      for (final variation in entry.value) {
        if (lowerText.contains(variation)) {
          // Find the actual service name in the original text
          final pattern = RegExp(variation, caseSensitive: false);
          final match = pattern.firstMatch(text);
          if (match != null) {
            return entry.key.split(' ').map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            }).join(' ');
          }
        }
      }
    }

    // Try context-based extraction from headers and prominent text
    for (int i = 0; i < lines.length.clamp(0, 10); i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();

      // Skip common non-service words
      if (_isCommonNonServiceWord(lowerLine)) continue;

      // Look for company/service name patterns
      if (RegExp(r'^[A-Z][A-Za-z0-9\s&.,-]{2,40}$').hasMatch(line) &&
          !_isCommonReceiptWord(lowerLine)) {
        // Check if it might be a service name
        if (line.length >= 3 && line.length <= 50) {
          return line;
        }
      }
    }

    // Try extracting from key-value patterns (more flexible)
    final flexiblePatterns = [
      RegExp(
          r'(?:service|company|merchant|vendor|provider|subscription\s+to|billed\s+by|charged\s+by|paid\s+to)[:\s]+([A-Za-z0-9\s&.,-]{3,50})',
          caseSensitive: false),
      RegExp(
          r'([A-Z][A-Za-z0-9\s&.,-]{3,40})\s+(?:subscription|renewal|payment|invoice)',
          caseSensitive: false),
      RegExp(r'(?:for|from)\s+([A-Z][A-Za-z0-9\s&.,-]{3,40})',
          caseSensitive: false),
    ];

    for (final pattern in flexiblePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)?.trim();
        if (name != null &&
            name.length >= 3 &&
            name.length <= 50 &&
            !_isCommonReceiptWord(name.toLowerCase())) {
          return name;
        }
      }
    }

    return null;
  }

  /// Infer service name from context when direct extraction fails
  String? _inferServiceNameFromContext(String text, List<String> lines) {
    // Look for any capitalized words that might be a company name
    for (final line in lines.take(10)) {
      if (RegExp(r'^[A-Z][a-z]+(\s+[A-Z][a-z]+)*$').hasMatch(line) &&
          line.length >= 3 &&
          line.length <= 40 &&
          !_isCommonReceiptWord(line.toLowerCase())) {
        return line;
      }
    }
    return null;
  }

  /// Check if a word is a common receipt/invoice word (not a service name)
  bool _isCommonReceiptWord(String word) {
    final commonWords = [
      'invoice',
      'receipt',
      'bill',
      'statement',
      'payment',
      'date',
      'amount',
      'total',
      'subtotal',
      'tax',
      'phone',
      'tel',
      'email',
      'reference',
      'ref',
      'customer',
      'client',
      'account',
      'transaction',
      'order',
      'number',
      'no',
      'id',
      'address',
      'city',
      'state',
      'zip',
      'country',
      'due',
      'paid',
      'balance',
      'credit',
      'debit',
      'card',
    ];
    return commonWords.contains(word.toLowerCase());
  }

  /// Check if a line is a common non-service word
  bool _isCommonNonServiceWord(String line) {
    return _isCommonReceiptWord(line) ||
        RegExp(r'^\d+$').hasMatch(line) ||
        RegExp(r'^[\$€£¥₹¢]\s*\d+').hasMatch(line) ||
        RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}').hasMatch(line);
  }

  /// Intelligent cost extraction with flexible pattern matching
  Map<String, dynamic>? _intelligentExtractCost(
      String text, String lowerText, List<String> lines) {
    // More flexible amount patterns that handle various formats
    final flexibleAmountPatterns = [
      // Patterns with context keywords (highest priority)
      RegExp(
          r'(?:total|amount\s+due|balance|charge|payment|cost|price|fee|subscription\s+cost)[:\s]*[\$€£¥₹¢]?\s*([\d,]+\.?\d*)',
          caseSensitive: false),
      RegExp(r'(?:total|amount|cost|price)[:\s]*([\d,]+\.?\d*)\s*([A-Z]{3})?',
          caseSensitive: false),

      // Currency symbol patterns (flexible spacing)
      RegExp(r'[\$€£¥₹¢]\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'([\d,]+\.?\d*)\s*[\$€£¥₹¢]', caseSensitive: false),

      // Currency code patterns (flexible)
      RegExp(
          r'([\d,]+\.?\d*)\s*(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS|RWF|ETB|CAD|AUD|NZD|JPY|CNY|SGD|HKD|CHF|SEK|NOK|DKK|PLN|CZK|HUF|RON|BGN|HRK)',
          caseSensitive: false),
      RegExp(
          r'(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS|RWF|ETB|CAD|AUD|NZD|JPY|CNY|SGD|HKD|CHF|SEK|NOK|DKK|PLN|CZK|HUF|RON|BGN|HRK)\s*([\d,]+\.?\d*)',
          caseSensitive: false),

      // Generic number patterns (with decimal places)
      RegExp(r'\b([\d,]+\.\d{2})\b', caseSensitive: false),
      RegExp(r'\b([\d,]+\.\d{1,2})\b', caseSensitive: false),
    ];

    List<Map<String, dynamic>> amounts = [];

    for (final pattern in flexibleAmountPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
        final amount = double.tryParse(amountStr);

        if (amount != null && amount > 0 && amount < 1000000) {
          String? currency;

          // Extract currency from match
          if (match.groupCount >= 2 && match.group(2) != null) {
            currency = match.group(2)!.toUpperCase();
          } else {
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

    // Sort by priority and take the highest
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

    // Higher priority for subscription-related context
    if (lowerMatch.contains('total') || lowerText.contains('total'))
      priority += 10;
    if (lowerMatch.contains('amount') || lowerText.contains('amount'))
      priority += 8;
    if (lowerMatch.contains('subscription') ||
        lowerText.contains('subscription')) priority += 9;
    if (lowerMatch.contains('due') || lowerText.contains('due')) priority += 7;
    if (lowerMatch.contains('charge') || lowerText.contains('charge'))
      priority += 6;
    if (lowerMatch.contains('payment') || lowerText.contains('payment'))
      priority += 5;

    // Lower priority for subtotals and taxes
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
      'KES',
      'UGX',
      'TZS',
      'RWF',
      'ETB',
      'CAD',
      'AUD',
      'NZD',
      'JPY',
      'CNY',
      'SGD',
      'HKD',
      'CHF',
      'SEK',
      'NOK',
      'DKK',
      'PLN',
      'CZK',
      'HUF',
      'RON',
      'BGN',
      'HRK'
    ];
    for (final code in currencyCodes) {
      if (text.contains(code)) return code;
    }

    return 'USD'; // Default
  }

  /// Intelligent date extraction with flexible patterns
  DateTime? _intelligentExtractDate(
      String text, String lowerText, List<String> lines) {
    // Comprehensive date patterns
    final datePatterns = [
      // Date with context keywords
      RegExp(
          r'(?:date|issued|billed|paid|transaction|renewal|renew|expires|expiring|next\s+payment)[:\s]+(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
          caseSensitive: false),
      RegExp(r'(?:date|issued|billed|paid)[:\s]+(\w+\s+\d{1,2},?\s+\d{4})',
          caseSensitive: false),

      // Standalone date patterns
      RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})', caseSensitive: false),
      RegExp(r'(\w+\s+\d{1,2},?\s+\d{4})', caseSensitive: false),
      RegExp(r'(\d{1,2}\s+\w+\s+\d{4})', caseSensitive: false),
      RegExp(r'(\d{4}[-/]\d{1,2}[-/]\d{1,2})', caseSensitive: false),
      RegExp(r'(\d{1,2}\.\d{1,2}\.\d{2,4})', caseSensitive: false),
    ];

    List<DateTime> foundDates = [];

    for (final pattern in datePatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        final dateStr = match.group(1);
        if (dateStr != null) {
          final date = _parseDate(dateStr);
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
      'TZS',
      'RWF',
      'ETB',
      'CAD',
      'AUD',
      'NZD',
      'JPY',
      'CNY',
      'SGD',
      'HKD',
      'CHF',
      'SEK',
      'NOK',
      'DKK',
      'PLN',
      'CZK',
      'HUF',
      'RON',
      'BGN',
      'HRK'
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

  /// Intelligent payment method extraction with fuzzy matching and context analysis
  /// Handles various payment methods including mobile money, banks, cards, and digital wallets
  String? _extractPaymentMethod(String text, String lowerText) {
    // Payment method patterns with variations and fuzzy matching
    final paymentMethodPatterns = {
      // Credit Cards
      'Credit Card': [
        'visa',
        'mastercard',
        'master card',
        'amex',
        'american express',
        'discover',
        'diners club',
        'dinersclub',
        'jcb',
        'credit card',
        'creditcard',
        'cc',
        'card ending',
        'card number',
      ],

      // Debit Cards
      'Debit Card': [
        'debit card',
        'debitcard',
        'debit',
        'atm card',
        'atmcard',
      ],

      // Mobile Money Services (African markets)
      'Mobile Money': [
        'momo',
        'mobile money',
        'mobilemoney',
        'm-money',
        'mmoney',
      ],

      'MTN Mobile Money': [
        'mtn mobile money',
        'mtn momo',
        'mtn money',
        'mtn mobile',
        'mtn m-money',
      ],

      'Vodafone Cash': [
        'vodafone cash',
        'vodafonecash',
        'vodacash',
        'vodafone',
      ],

      'Airtel Money': [
        'airtel money',
        'airtelmoney',
        'airtel',
        'airtel mobile money',
      ],

      'OPay': [
        'opay',
        'o-pay',
        'opay wallet',
        'opaywallet',
      ],

      'PalmPay': [
        'palmpay',
        'palm pay',
        'palm-pay',
      ],

      'Flutterwave': [
        'flutterwave',
        'flutter wave',
        'rave',
      ],

      'Paystack': [
        'paystack',
        'pay stack',
      ],

      // Bank Transfers
      'Bank Transfer': [
        'bank transfer',
        'banktransfer',
        'wire transfer',
        'wiretransfer',
        'bank payment',
        'bankpayment',
        'bank deposit',
        'bankdeposit',
        'ach transfer',
        'achtransfer',
        'swift transfer',
        'swifttransfer',
      ],

      // Digital Wallets
      'PayPal': [
        'paypal',
        'pay pal',
        'pay-pal',
      ],

      'Apple Pay': [
        'apple pay',
        'applepay',
        'apple-pay',
      ],

      'Google Pay': [
        'google pay',
        'googlepay',
        'google-pay',
        'gpay',
        'g-pay',
      ],

      'Samsung Pay': [
        'samsung pay',
        'samsungpay',
        'samsung-pay',
      ],

      'Venmo': [
        'venmo',
      ],

      'Cash App': [
        'cash app',
        'cashapp',
        'cash-app',
        'square cash',
      ],

      'Zelle': [
        'zelle',
      ],

      'Wise': [
        'wise',
        'transferwise',
        'transfer wise',
      ],

      'Revolut': [
        'revolut',
      ],

      // Cryptocurrency (if applicable)
      'Bitcoin': [
        'bitcoin',
        'btc',
        'crypto',
      ],

      // Other payment methods
      'Cash': [
        'cash payment',
        'cashpayment',
        'paid in cash',
        'cash',
      ],

      'Check': [
        'check',
        'cheque',
        'bank check',
        'bankcheck',
      ],

      'Direct Debit': [
        'direct debit',
        'directdebit',
        'auto debit',
        'autodebit',
        'automatic debit',
      ],

      'ACH': [
        'ach',
        'ach payment',
        'achpayment',
      ],

      'SEPA': [
        'sepa',
        'sepa transfer',
        'sepatransfer',
      ],
    };

    // Score-based matching for better accuracy
    final Map<String, double> methodScores = {};

    for (final entry in paymentMethodPatterns.entries) {
      final methodName = entry.key;
      final patterns = entry.value;

      for (final pattern in patterns) {
        // Exact match gets highest score
        if (lowerText.contains(pattern)) {
          methodScores[methodName] = (methodScores[methodName] ?? 0.0) + 1.0;
        }

        // Fuzzy matching for common OCR errors
        final fuzzyPatterns = [
          pattern.replaceAll(' ', ''), // Remove spaces
          pattern.replaceAll('-', ''), // Remove hyphens
        ];

        for (final fuzzyPattern in fuzzyPatterns) {
          if (lowerText.contains(fuzzyPattern)) {
            methodScores[methodName] = (methodScores[methodName] ?? 0.0) + 0.5;
          }
        }
      }
    }

    // Also check for bank names in context
    final bankKeywords = [
      'bank',
      'banking',
      'account',
      'account number',
      'routing',
      'iban',
      'swift code',
      'bic',
    ];

    bool hasBankContext =
        bankKeywords.any((keyword) => lowerText.contains(keyword));

    // If bank context exists and no specific payment method found, default to Bank Transfer
    if (hasBankContext && methodScores.isEmpty) {
      // Check if it's not already a mobile money service
      if (!lowerText.contains('mobile money') &&
          !lowerText.contains('momo') &&
          !lowerText.contains('mtn') &&
          !lowerText.contains('vodafone') &&
          !lowerText.contains('airtel') &&
          !lowerText.contains('opay')) {
        return 'Bank Transfer';
      }
    }

    // Return the method with highest score
    if (methodScores.isNotEmpty) {
      final sortedMethods = methodScores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return sortedMethods.first.key;
    }

    // Check for generic payment method indicators
    if (lowerText.contains('payment method') ||
        lowerText.contains('paid via') ||
        lowerText.contains('paid with') ||
        lowerText.contains('payment via') ||
        lowerText.contains('payment with')) {
      // Try to extract from context
      final contextPatterns = [
        RegExp(r'paid\s+via\s+([A-Za-z\s]+)', caseSensitive: false),
        RegExp(r'paid\s+with\s+([A-Za-z\s]+)', caseSensitive: false),
        RegExp(r'payment\s+via\s+([A-Za-z\s]+)', caseSensitive: false),
        RegExp(r'payment\s+with\s+([A-Za-z\s]+)', caseSensitive: false),
        RegExp(r'payment\s+method[:\s]+([A-Za-z\s]+)', caseSensitive: false),
      ];

      for (final pattern in contextPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          final extracted = match.group(1)?.trim();
          if (extracted != null &&
              extracted.length >= 2 &&
              extracted.length <= 30) {
            // Capitalize first letter of each word
            return extracted.split(' ').map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            }).join(' ');
          }
        }
      }
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
    this.originalCost,
    this.originalCurrency,
    this.renewalDate,
    this.billingCycle,
    this.category,
    this.paymentMethod,
    this.error,
    this.rawText,
  });

  final bool success;
  final String? serviceName;
  final double? cost; // Converted to base currency
  final String? currencyCode; // Base currency
  final double? originalCost; // Original amount from receipt
  final String? originalCurrency; // Original currency from receipt
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

    // Use original currency and cost if available, otherwise use extracted values
    // This ensures we save the native currency and value, not converted values
    final finalCurrency = originalCurrency?.isNotEmpty == true
        ? originalCurrency!
        : (currencyCode ?? 'USD');
    final finalCost = originalCost ?? cost!;

    return Subscription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      serviceName: serviceName!,
      billingCycle: billingCycle ?? BillingCycle.monthly,
      renewalDate: renewalDate!,
      currencyCode: finalCurrency,
      cost: finalCost,
      autoRenew: true,
      category: category ?? SubscriptionCategory.other,
      paymentMethod: paymentMethod ?? 'Unknown',
      reminderDays: [7, 3, 1],
      notes: rawText,
    );
  }
}
