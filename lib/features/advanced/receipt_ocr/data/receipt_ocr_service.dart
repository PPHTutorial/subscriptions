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
            // If gap is significant (likely intentional spacing for columns), use tab
            if (horizontalGap > 20) {
              // Large gap indicates column separation - use tab
              textBuffer.write('\t');
            } else if (horizontalGap > 5) {
              // Medium gap - add spaces proportional to gap
              final spaces = (horizontalGap / 8).round().clamp(1, 5);
              textBuffer.write(' ' * spaces);
            } else {
              // Small gap - normal word spacing
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
    // Step 0: Preserve and fix currency symbols (do this first before other replacements)
    // Common OCR errors for currency symbols
    String cleaned = text
        // Fix Euro symbol (€) - common OCR mistakes
        .replaceAll(RegExp(r'[C][\s]*[=]'), '€') // C= to €
        .replaceAll(RegExp(r'[C][\s]*[-]'), '€') // C- to €
        .replaceAll(RegExp(r'\bC\s+(?=\d)'), '€') // C before number to €
        .replaceAll(RegExp(r'[E][\s]*[U][\s]*[R]'), '€') // EUR text to €
        // Fix Pound symbol (£) - common OCR mistakes
        .replaceAll(RegExp(r'[L][\s]*[=]'), '£') // L= to £
        .replaceAll(RegExp(r'[L][\s]*[-]'), '£') // L- to £
        .replaceAll(RegExp(r'\bL\s+(?=\d)'),
            '£') // L before number to £ (if not followed by letter)
        // Fix Dollar symbol ($) - common OCR mistakes
        .replaceAll(RegExp(r'[S][\s]*[=]'), '\$') // S= to $
        .replaceAll(RegExp(r'[S][\s]*[-]'), '\$') // S- to $
        // Fix other currency symbols
        .replaceAll(RegExp(r'[Y][\s]*[=]'), '¥') // Y= to ¥
        .replaceAll(RegExp(r'[R][\s]*[=]'), '₹') // R= to ₹
        .replaceAll(RegExp(r'[C][\s]*[/]'), '¢') // C/ to ¢
        .replaceAll(RegExp(r'[C][\s]*[.]'), '¢'); // C. to ¢

    // Step 1: Fix common OCR character recognition errors (but preserve currency symbols)
    cleaned = cleaned
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

    // First, check if this is a job application or other non-subscription text
    if (_isJobApplication(text) || _isNonSubscriptionText(text)) {
      return ReceiptExtractionResult(
        success: false,
        error:
            'Text appears to be a job application or non-subscription content',
        rawText: text,
      );
    }

    // Then, analyze if this text is subscription-related using intelligent scoring
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
            category: _inferCategory(inferredName, text),
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
      category: serviceName != null ? _inferCategory(serviceName, text) : null,
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

  /// Intelligent cost extraction with flexible pattern matching and total calculation
  Map<String, dynamic>? _intelligentExtractCost(
      String text, String lowerText, List<String> lines) {
    // First, try to calculate total from line items, VATs, and discounts
    final calculatedTotal = _calculateTotalFromReceipt(text, lowerText, lines);
    if (calculatedTotal != null) {
      return calculatedTotal;
    }

    // More flexible amount patterns that handle various formats
    // Enhanced currency symbol patterns (including more symbols)
    // Common currency symbols: $ € £ ¥ ₹ ¢ ₵ ₦ ₨ ₩ ₪ ₫ ₭ ₮ ₯ ₰ ₱ ₲ ₳ ₴ ₵ ₶ ₷ ₸ ₹ ₺ ₻ ₼ ₽ ₾ ₿
    final currencySymbolsPattern = r'[\$€£¥₹¢₵₦₨₩₪₫₭₮₯₰₱₲₳₴₵₶₷₸₹₺₻₼₽₾₿]';

    final flexibleAmountPatterns = [
      // Patterns with total keywords (highest priority) - comprehensive total labels
      // These MUST have currency symbols or codes for validation
      RegExp(
          '(?:total\\s+(?:amount|paid|due|cost|price|charge|balance|to\\s+pay|payable|payable\\s+amount|take\\s+home)|amount\\s+due|total\\s+due|grand\\s+total|final\\s+total|net\\s+total|total\\s+payable|total\\s+to\\s+pay)[:\\s]+$currencySymbolsPattern?\\s*([\\d,]+\\.?\\d*)',
          caseSensitive: false),
      RegExp(
          '(?:total|amount\\s+due|balance|charge|payment|cost|price|fee|subscription\\s+cost|take\\s+home)[:\\s]+$currencySymbolsPattern?\\s*([\\d,]+\\.?\\d*)',
          caseSensitive: false),
      RegExp(
          r'(?:total|amount|cost|price|take\s+home)[:\s]+([\d,]+\.?\d*)\s*([A-Z]{3})',
          caseSensitive: false),

      // Patterns with K/M suffixes: $124K, GHS500K, ₵1M, USD 50.77k
      RegExp(
          r'(?:total|amount|charge|payment|cost|price|fee|paid|pay|billed)[:\s]*([\$€£¥₹¢₵]|USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS)\s*([\d,]+\.?\d*)\s*([kmKM]|thousand|million)\b',
          caseSensitive: false),
      RegExp(r'([\$€£¥₹¢₵])\s*([\d,]+\.?\d*)\s*([kmKM]|thousand|million)\b',
          caseSensitive: false),
      RegExp(
          r'\b(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS)\s*([\d,]+\.?\d*)\s*([kmKM]|thousand|million)\b',
          caseSensitive: false),
      // Currency symbol patterns (REQUIRED for validation) - these are more reliable
      RegExp('$currencySymbolsPattern\\s*([\\d,]+\\.?\\d{1,2})',
          caseSensitive: false),
      RegExp('([\\d,]+\\.?\\d{1,2})\\s*$currencySymbolsPattern',
          caseSensitive: false),

      // Currency code patterns (REQUIRED for validation)
      RegExp(
          r'([\d,]+\.?\d{1,2})\s+(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS|RWF|ETB|CAD|AUD|NZD|JPY|CNY|SGD|HKD|CHF|SEK|NOK|DKK|PLN|CZK|HUF|RON|BGN|HRK|BRL|MXN|ARS|CLP|COP|PEN|UYU|VES|TRY|RUB|ILS|AED|SAR|QAR|KWD|BHD|OMR|JOD|EGP|MAD|TND|DZD|LYD|SDG|ETB|DJF|SOS|ERN|SSP|AOA|ZMW|BWP|SZL|LSL|MZN|MGA|SCR|MUR|KMF|CDF|RWF|BIF|UGX|TZS|KES|ETB|DJF|SOS|SSP|ERN)',
          caseSensitive: false),
      RegExp(
          r'(USD|EUR|GBP|INR|GHS|NGN|ZAR|KES|UGX|TZS|RWF|ETB|CAD|AUD|NZD|JPY|CNY|SGD|HKD|CHF|SEK|NOK|DKK|PLN|CZK|HUF|RON|BGN|HRK|BRL|MXN|ARS|CLP|COP|PEN|UYU|VES|TRY|RUB|ILS|AED|SAR|QAR|KWD|BHD|OMR|JOD|EGP|MAD|TND|DZD|LYD|SDG|ETB|DJF|SOS|ERN|SSP|AOA|ZMW|BWP|SZL|LSL|MZN|MGA|SCR|MUR|KMF|CDF|RWF|BIF|UGX|TZS|KES|ETB|DJF|SOS|SSP|ERN)\s+([\d,]+\.?\d{1,2})',
          caseSensitive: false),

      // Generic number patterns with decimals (lower priority, but still valid)
      // Only accept if they have at least 2 decimal places (more likely to be money)
      RegExp(r'\b([\d,]+\.\d{2})\b', caseSensitive: false),
    ];

    List<Map<String, dynamic>> amounts = [];

    for (final pattern in flexibleAmountPatterns) {
      final matches = pattern.allMatches(text);
      for (final match in matches) {
        double? amount;
        String? currency;
        String? amountStr;

        // Check if this pattern has K/M suffix (patterns 0-2)
        if (match.groupCount >= 3 && match.group(3) != null) {
          // Pattern with K/M suffix
          amountStr = match.group(2)?.replaceAll(',', '') ?? '';
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
        } else {
          // Standard pattern without K/M
          amountStr = match.group(1)?.replaceAll(',', '') ?? '';
          amount = double.tryParse(amountStr);

          // Extract currency from match
          if (match.groupCount >= 2 && match.group(2) != null) {
            currency = _normalizeCurrency(match.group(2)!);
          } else {
            currency = _detectCurrencyFromContext(match.group(0) ?? '', text);
          }
        }

        if (amount != null && amount > 0) {
          // VALIDATION: Filter out invalid amounts (reasonable subscription range: $0.01 to $100,000)
          if (amount > 100000) {
            continue; // Too large for subscription
          }

          final amountStrForValidation =
              amountStr.isNotEmpty ? amountStr : amount.toString();
          if (!_isValidAmount(
              amount, amountStrForValidation, match.group(0) ?? '', text)) {
            continue; // Skip invalid amounts
          }

          final matchText = match.group(0);
          final hasCurrencySymbol =
              RegExp(currencySymbolsPattern).hasMatch(matchText ?? '');
          final hasCurrencyCode = match.groupCount >= 2 &&
              match.group(2) != null &&
              match.group(2)!.length == 3;

          amounts.add({
            'amount': amount,
            'currency':
                (currency != null && currency.isNotEmpty) ? currency : 'USD',
            'priority': _getAmountPriority(
                matchText ?? '', lowerText, hasCurrencySymbol, hasCurrencyCode),
            'hasCurrencySymbol': hasCurrencySymbol,
            'hasCurrencyCode': hasCurrencyCode,
            'matchText': matchText,
          });
        }
      }
    }

    if (amounts.isEmpty) return null;

    // Sort by priority (highest first), then by currency presence, then by amount (larger is better)
    amounts.sort((a, b) {
      final priorityCompare =
          (b['priority'] as int).compareTo(a['priority'] as int);
      if (priorityCompare != 0) return priorityCompare;

      // Prefer amounts with currency symbols
      final aHasCurrency =
          (a['hasCurrencySymbol'] as bool) || (a['hasCurrencyCode'] as bool);
      final bHasCurrency =
          (b['hasCurrencySymbol'] as bool) || (b['hasCurrencyCode'] as bool);
      if (aHasCurrency != bHasCurrency) {
        return bHasCurrency ? 1 : -1;
      }

      // Prefer larger amounts (more likely to be totals)
      return (b['amount'] as double).compareTo(a['amount'] as double);
    });

    final bestMatch = amounts.first;

    return {
      'cost': bestMatch['amount'] as double,
      'currency': bestMatch['currency'] as String,
    };
  }

  /// Validate if an amount is likely a real cost (not a date, phone number, ID, etc.)
  bool _isValidAmount(
      double amount, String amountStr, String matchText, String fullText) {
    // Filter out years (1900-2100)
    if (amount >= 1900 && amount <= 2100 && amount == amount.roundToDouble()) {
      // Check if it's actually part of a date pattern
      final datePattern = RegExp(
          r'\b(19|20)\d{2}\b.*(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|\d{1,2}[/-]\d{1,2,4})',
          caseSensitive: false);
      if (datePattern.hasMatch(fullText)) {
        return false; // Likely a year in a date
      }
      // Also check if it's near date-like patterns
      final yearStr = amount.toInt().toString();
      final nearDatePattern = RegExp(
          '\\b$yearStr\\b.*[/-].*\\d|.*[/-].*\\b$yearStr\\b',
          caseSensitive: false);
      if (nearDatePattern.hasMatch(fullText)) {
        return false; // Likely a year
      }
    }

    // Filter out phone numbers (long sequences without decimals, typically 7-15 digits)
    if (amount == amount.roundToDouble() &&
        amountStr.length >= 7 &&
        amountStr.length <= 15 &&
        !amountStr.contains('.')) {
      // Check if it looks like a phone number pattern
      final phonePattern = RegExp(
          r'\b(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4,}\b',
          caseSensitive: false);
      if (phonePattern.hasMatch(matchText)) {
        return false; // Likely a phone number
      }
    }

    // Filter out very long sequences without decimals (likely IDs, account numbers, etc.)
    if (amount == amount.roundToDouble() &&
        amountStr.length > 8 &&
        !amountStr.contains('.')) {
      // Unless it has a currency symbol/code, it's probably not a cost
      final hasCurrency = RegExp(
              r'[\$€£¥₹¢₵₦₨₩₪₫₭₮₯₰₱₲₳₴₵₶₷₸₹₺₻₼₽₾₿]|USD|EUR|GBP|INR|GHS|NGN',
              caseSensitive: false)
          .hasMatch(matchText);
      if (!hasCurrency) {
        return false; // Likely an ID or account number
      }
    }

    // Filter out very small amounts without currency (likely quantities, percentages, etc.)
    if (amount < 1.0 && amount > 0) {
      final hasCurrency = RegExp(
              r'[\$€£¥₹¢₵₦₨₩₪₫₭₮₯₰₱₲₳₴₵₶₷₸₹₺₻₼₽₾₿]|USD|EUR|GBP|INR|GHS|NGN',
              caseSensitive: false)
          .hasMatch(matchText);
      if (!hasCurrency) {
        return false; // Likely a quantity or percentage
      }
    }

    // Filter out amounts that are too large (unlikely subscription costs)
    if (amount > 100000) {
      // Only accept if it has explicit total label and currency
      final hasTotalLabel = RegExp(
              r'total|amount|due|payable|balance|charge|payment|cost|price',
              caseSensitive: false)
          .hasMatch(matchText);
      final hasCurrency = RegExp(
              r'[\$€£¥₹¢₵₦₨₩₪₫₭₮₯₰₱₲₳₴₵₶₷₸₹₺₻₼₽₾₿]|USD|EUR|GBP|INR|GHS|NGN',
              caseSensitive: false)
          .hasMatch(matchText);
      if (!hasTotalLabel || !hasCurrency) {
        return false; // Too large without context
      }
    }

    // Prefer amounts with decimal places (more likely to be money)
    // But allow whole numbers if they have currency symbols
    final hasDecimals = amountStr.contains('.');
    final hasCurrency = RegExp(
            r'[\$€£¥₹¢₵₦₨₩₪₫₭₮₯₰₱₲₳₴₵₶₷₸₹₺₻₼₽₾₿]|USD|EUR|GBP|INR|GHS|NGN',
            caseSensitive: false)
        .hasMatch(matchText);

    // If no currency and no decimals, be more strict
    if (!hasCurrency && !hasDecimals && amount >= 100) {
      return false; // Likely not a cost
    }

    return true;
  }

  /// Calculate total from receipt by finding subtotals, VATs, and discounts
  Map<String, dynamic>? _calculateTotalFromReceipt(
      String text, String lowerText, List<String> lines) {
    // Find all amounts with their labels
    final amountEntries = <Map<String, dynamic>>[];

    // Enhanced currency symbol pattern
    final currencySymbolsPattern = r'[\$€£¥₹¢₵₦₨₩₪₫₭₮₯₰₱₲₳₴₵₶₷₸₹₺₻₼₽₾₿]';

    for (final line in lines) {
      // Try multiple patterns for better detection
      // Pattern 1: Label: Amount
      final pattern1 = RegExp(
          '([A-Za-z\\s]+?)[:\\s]+($currencySymbolsPattern?\\s*)([\\d,]+\\.?\\d*)',
          caseSensitive: false);
      // Pattern 2: Amount Label
      final pattern2 = RegExp(
          '($currencySymbolsPattern?\\s*)([\\d,]+\\.?\\d*)\\s+([A-Za-z\\s]+)',
          caseSensitive: false);
      // Pattern 3: Label Amount (no symbol)
      final pattern3 = RegExp(
          r'([A-Za-z\s]+?)[:\s]+([\d,]+\.?\d*)\s*([A-Z]{3})?',
          caseSensitive: false);

      final allPatterns = [pattern1, pattern2, pattern3];

      for (final pattern in allPatterns) {
        final matches = pattern.allMatches(line);
        for (final match in matches) {
          String? label;
          String? amountStr;

          if (pattern == pattern1) {
            label = match.group(1)?.trim().toLowerCase();
            amountStr = match.group(3)?.replaceAll(',', '');
          } else if (pattern == pattern2) {
            label = match.group(3)?.trim().toLowerCase();
            amountStr = match.group(2)?.replaceAll(',', '');
          } else if (pattern == pattern3) {
            label = match.group(1)?.trim().toLowerCase();
            amountStr = match.group(2)?.replaceAll(',', '');
          }

          if (label != null && amountStr != null) {
            final amount = double.tryParse(amountStr);

            if (amount != null && amount > 0) {
              // Validate amount before adding
              final matchText = match.group(0) ?? '';
              if (!_isValidAmount(amount, amountStr, matchText, text)) {
                continue; // Skip invalid amounts
              }

              final currency = _detectCurrencyFromContext(matchText, text);
              amountEntries.add({
                'label': label,
                'amount': amount,
                'currency': currency,
                'line': line,
              });
            }
          }
        }
      }
    }

    if (amountEntries.isEmpty) return null;

    if (amountEntries.isEmpty) return null;

    // Group amounts by currency
    final amountsByCurrency = <String, List<Map<String, dynamic>>>{};
    for (final entry in amountEntries) {
      final currency = entry['currency'] as String;
      amountsByCurrency.putIfAbsent(currency, () => []).add(entry);
    }

    // Process each currency group separately
    for (final currencyGroup in amountsByCurrency.entries) {
      final currency = currencyGroup.key;
      final entries = currencyGroup.value;

      // Find subtotal/base amount
      double? subtotal;

      // Look for subtotal, base amount, or first significant amount
      for (final entry in entries) {
        final label = entry['label'] as String;
        if (label.contains('subtotal') ||
            label.contains('base') ||
            (label.contains('amount') && !label.contains('total'))) {
          subtotal = entry['amount'] as double;
          break;
        }
      }

      // If no subtotal found, try to find the largest amount that's not a total/tax/discount
      if (subtotal == null) {
        final nonTotalEntries = entries.where((e) {
          final label = e['label'] as String;
          return !label.contains('total') &&
              !label.contains('vat') &&
              !label.contains('tax') &&
              !label.contains('gst') &&
              !label.contains('discount') &&
              !label.contains('deduction');
        }).toList();

        if (nonTotalEntries.isNotEmpty) {
          // Use the largest amount as base
          nonTotalEntries.sort((a, b) =>
              (b['amount'] as double).compareTo(a['amount'] as double));
          subtotal = nonTotalEntries.first['amount'] as double;
        } else if (entries.isNotEmpty) {
          // Fallback to first amount
          subtotal = entries.first['amount'] as double;
        }
      }

      if (subtotal == null) continue;

      // Find and add VATs/Taxes
      double total = subtotal;
      for (final entry in entries) {
        final label = entry['label'] as String;
        final amount = entry['amount'] as double;

        if (label.contains('vat') ||
            label.contains('tax') ||
            label.contains('gst') ||
            label.contains('hst') ||
            label.contains('pst') ||
            label.contains('service tax') ||
            label.contains('sales tax') ||
            label.contains('value added tax')) {
          total += amount; // Add taxes
        }
      }

      // Find and subtract discounts
      for (final entry in entries) {
        final label = entry['label'] as String;
        final amount = entry['amount'] as double;

        if (label.contains('discount') ||
            label.contains('deduction') ||
            label.contains('rebate') ||
            label.contains('promotion') ||
            label.contains('coupon') ||
            label.contains('voucher') ||
            label.contains('off') ||
            label.contains('reduction')) {
          total -= amount; // Subtract discounts
        }
      }

      // Ensure total is positive
      if (total <= 0) continue;

      // Now look for explicit "Total" labels to verify or use
      for (final entry in entries) {
        final label = entry['label'] as String;
        final amount = entry['amount'] as double;

        // Check if this is a total label (comprehensive list)
        final isTotalLabel = (label.contains('total') &&
                (label.contains('paid') ||
                    label.contains('due') ||
                    label.contains('amount') ||
                    label.contains('payable') ||
                    label.contains('final') ||
                    label.contains('grand') ||
                    label.contains('net') ||
                    label.contains('take home'))) ||
            label.contains('amount due') ||
            label.contains('total due') ||
            label.contains('total payable') ||
            label.contains('total to pay') ||
            label.contains('grand total') ||
            label.contains('final total') ||
            label.contains('net total') ||
            label.contains('take home');

        if (isTotalLabel) {
          // Use the explicit total if it's close to our calculated total (within 10%)
          // or if calculated total seems wrong, use explicit total
          final diff = (amount - total).abs();
          if (diff / total < 0.10 || total < amount * 0.5) {
            return {
              'cost': amount,
              'currency': currency,
            };
          }
        }
      }

      // Return calculated total for this currency
      return {
        'cost': total,
        'currency': currency,
      };
    }

    return null;
  }

  int _getAmountPriority(String match, String lowerText,
      [bool hasCurrencySymbol = false, bool hasCurrencyCode = false]) {
    int priority = 0;
    final lowerMatch = match.toLowerCase();

    // CRITICAL: Highest priority for amounts with currency symbols/codes
    // This ensures we prefer $4,000 over 2025 or 12345678
    if (hasCurrencySymbol) {
      priority += 50; // Massive boost for currency symbols
    }
    if (hasCurrencyCode) {
      priority += 45; // Large boost for currency codes
    }

    // Highest priority for explicit total labels
    if (lowerMatch.contains('total paid') || lowerText.contains('total paid'))
      priority += 30;
    if (lowerMatch.contains('total amount') ||
        lowerText.contains('total amount')) priority += 30;
    if (lowerMatch.contains('take home') || lowerText.contains('take home'))
      priority += 30; // Added "take home" as high priority
    if (lowerMatch.contains('total due') || lowerText.contains('total due'))
      priority += 30;
    if (lowerMatch.contains('amount due') || lowerText.contains('amount due'))
      priority += 29;
    if (lowerMatch.contains('grand total') || lowerText.contains('grand total'))
      priority += 30;
    if (lowerMatch.contains('final total') || lowerText.contains('final total'))
      priority += 30;
    if (lowerMatch.contains('net total') || lowerText.contains('net total'))
      priority += 29;
    if (lowerMatch.contains('total payable') ||
        lowerText.contains('total payable')) priority += 30;
    if (lowerMatch.contains('total to pay') ||
        lowerText.contains('total to pay')) priority += 28;
    if (lowerMatch.contains('to pay') || lowerText.contains('to pay'))
      priority += 18;

    // High priority for subscription-related context
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
    if (lowerMatch.contains('balance') || lowerText.contains('balance'))
      priority += 7;

    // Lower priority for subtotals, taxes, and discounts (these are components, not totals)
    if (lowerMatch.contains('subtotal') || lowerText.contains('subtotal'))
      priority -= 15; // Heavily penalize subtotals
    if (lowerMatch.contains('tax') || lowerText.contains('tax')) priority -= 12;
    if (lowerMatch.contains('vat') || lowerText.contains('vat')) priority -= 12;
    if (lowerMatch.contains('gst') || lowerText.contains('gst')) priority -= 12;
    if (lowerMatch.contains('discount') || lowerText.contains('discount'))
      priority -= 15; // Heavily penalize discounts
    if (lowerMatch.contains('deduction') || lowerText.contains('deduction'))
      priority -= 15;

    // HEAVILY penalize amounts that look like dates, years, or IDs
    // Check if the match contains date-like patterns
    if (RegExp(r'\b(19|20)\d{2}\b|^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}',
            caseSensitive: false)
        .hasMatch(match)) {
      priority -= 100; // Heavily penalize dates/years
    }

    // Penalize very long sequences without currency (likely IDs)
    if (!hasCurrencySymbol &&
        !hasCurrencyCode &&
        match.replaceAll(RegExp(r'[^\d]'), '').length > 8) {
      priority -= 50; // Heavily penalize long sequences without currency
    }

    return priority;
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

  String _detectCurrencyFromContext(String match, String text) {
    // Check for currency symbols (enhanced detection)
    // Check match first (more specific), then text (broader context)
    final checkText = match.isNotEmpty ? match : text;

    // Euro (€) - check various representations
    if (checkText.contains('€') ||
        checkText.contains('EUR') ||
        RegExp(r'\bEUR\b', caseSensitive: false).hasMatch(text)) return 'EUR';

    // Pound (£) - check various representations
    if (checkText.contains('£') ||
        checkText.contains('GBP') ||
        RegExp(r'\bGBP\b', caseSensitive: false).hasMatch(text)) return 'GBP';

    // Dollar ($) - USD
    if (checkText.contains('\$') ||
        checkText.contains('USD') ||
        RegExp(r'\bUSD\b', caseSensitive: false).hasMatch(text)) return 'USD';

    // Indian Rupee (₹)
    if (checkText.contains('₹') ||
        checkText.contains('INR') ||
        RegExp(r'\bINR\b', caseSensitive: false).hasMatch(text)) return 'INR';

    // Japanese Yen (¥)
    if (checkText.contains('¥') ||
        checkText.contains('JPY') ||
        RegExp(r'\bJPY\b', caseSensitive: false).hasMatch(text)) return 'JPY';

    // Ghanaian Cedi (₵)
    if (checkText.contains('₵') ||
        checkText.contains('GHS') ||
        RegExp(r'\bGHS\b', caseSensitive: false).hasMatch(text)) return 'GHS';

    // Nigerian Naira (₦)
    if (checkText.contains('₦') ||
        checkText.contains('NGN') ||
        RegExp(r'\bNGN\b', caseSensitive: false).hasMatch(text)) return 'NGN';

    // Check for currency codes (expanded list with word boundaries)
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
      'HRK',
      'BRL',
      'MXN',
      'ARS',
      'CLP',
      'COP',
      'PEN',
      'UYU',
      'VES',
      'TRY',
      'RUB',
      'ILS',
      'AED',
      'SAR',
      'QAR',
      'KWD',
      'BHD',
      'OMR',
      'JOD',
      'EGP',
      'MAD',
      'TND',
      'DZD',
      'LYD',
      'SDG',
      'DJF',
      'SOS',
      'ERN',
      'SSP',
      'AOA',
      'ZMW',
      'BWP',
      'SZL',
      'LSL',
      'MZN',
      'MGA',
      'SCR',
      'MUR',
      'KMF',
      'CDF',
      'BIF',
      'XOF',
      'XAF',
      'THB',
      'MYR',
      'IDR',
      'PHP',
      'VND',
      'KRW',
      'TWD',
    ];

    // Check for currency codes with word boundaries to avoid false matches
    for (final code in currencyCodes) {
      if (RegExp('\\b$code\\b', caseSensitive: false).hasMatch(text)) {
        return code;
      }
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
    // Check for currency symbols first (enhanced detection)
    // Euro (€)
    if (text.contains('€') ||
        RegExp(r'\bEUR\b', caseSensitive: false).hasMatch(text)) return 'EUR';

    // Pound (£)
    if (text.contains('£') ||
        RegExp(r'\bGBP\b', caseSensitive: false).hasMatch(text)) return 'GBP';

    // Dollar ($)
    if (text.contains('\$') ||
        RegExp(r'\bUSD\b', caseSensitive: false).hasMatch(text)) return 'USD';

    // Indian Rupee (₹)
    if (text.contains('₹') ||
        RegExp(r'\bINR\b', caseSensitive: false).hasMatch(text)) return 'INR';

    // Japanese Yen (¥)
    if (text.contains('¥') ||
        RegExp(r'\bJPY\b', caseSensitive: false).hasMatch(text)) return 'JPY';

    // Ghanaian Cedi (₵)
    if (text.contains('₵') ||
        RegExp(r'\bGHS\b', caseSensitive: false).hasMatch(text)) return 'GHS';

    // Nigerian Naira (₦)
    if (text.contains('₦') ||
        RegExp(r'\bNGN\b', caseSensitive: false).hasMatch(text)) return 'NGN';

    // Check for currency codes (expanded list)
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
      'HRK',
      'BRL',
      'MXN',
      'ARS',
      'CLP',
      'COP',
      'PEN',
      'UYU',
      'VES',
      'TRY',
      'RUB',
      'ILS',
      'AED',
      'SAR',
      'QAR',
      'KWD',
      'BHD',
      'OMR',
      'JOD',
      'EGP',
      'MAD',
      'TND',
      'DZD',
      'LYD',
      'SDG',
      'DJF',
      'SOS',
      'ERN',
      'SSP',
      'AOA',
      'ZMW',
      'BWP',
      'SZL',
      'LSL',
      'MZN',
      'MGA',
      'SCR',
      'MUR',
      'KMF',
      'CDF',
      'BIF',
      'XOF',
      'XAF',
      'THB',
      'MYR',
      'IDR',
      'PHP',
      'VND',
      'KRW',
      'TWD',
    ];

    // Check for currency codes with word boundaries to avoid false matches
    for (final code in currencyCodes) {
      if (RegExp(r'\b$code\b', caseSensitive: false).hasMatch(text)) {
        return code;
      }
    }

    return 'USD'; // Default
  }

  BillingCycle _extractBillingCycle(String lowerText) {
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

    // Check for half-yearly (6 months, semi-annual, bi-annual)
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

    // Return category with highest score
    if (categoryScores.isEmpty) {
      return SubscriptionCategory.other;
    }

    final sortedCategories = categoryScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedCategories.first.key;
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
