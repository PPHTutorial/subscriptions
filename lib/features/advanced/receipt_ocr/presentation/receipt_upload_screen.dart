import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import '../../../../core/ads/banner_ad_widget.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../data/receipt_ocr_service.dart';
import '../data/barcode_parser_service.dart';
import '../data/barcode_scan_result.dart';
import 'barcode_scanner_screen.dart';
import 'camera_mask_screen.dart';

class ReceiptUploadScreen extends ConsumerStatefulWidget {
  const ReceiptUploadScreen({super.key});

  @override
  ConsumerState<ReceiptUploadScreen> createState() =>
      _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends ConsumerState<ReceiptUploadScreen> {
  final _ocrService = ReceiptOcrService();
  final _barcodeParser = BarcodeParserService();
  final _permissionService = PermissionService();
  File? _selectedImage;
  ReceiptFile? _selectedFile;
  bool _isProcessing = false;
  ReceiptExtractionResult? _result;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool fromCamera) async {
    // Request all permissions when receipt upload is accessed
    await _permissionService.requestAllPermissions();

    // Request specific permission based on source
    if (fromCamera) {
      final hasCamera = await _permissionService.requestCameraPermission();
      if (!hasCamera && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to take photos'),
          ),
        );
        return;
      }
    } else {
      final hasPhotos = await _permissionService.requestPhotosPermission();
      if (!hasPhotos && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photos permission is required to select images'),
          ),
        );
        return;
      }
    }

    try {
      // Use pickImageFile for images (works reliably with image_picker)
      final file = await _ocrService.pickImageFile(fromCamera: fromCamera);
      setState(() {
        _selectedFile = file;
        _selectedImage = file?.file;
        _result = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking image: $e',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _openCameraWithMask() async {
    // Request camera permission
    await _permissionService.requestAllPermissions();
    final hasCamera = await _permissionService.requestCameraPermission();
    if (!hasCamera && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to take photos'),
        ),
      );
      return;
    }

    if (!mounted) return;

    // Open camera with mask screen
    final capturedImage = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (context) => CameraMaskScreen(
          onImageCaptured: (imageFile) {
            // Pop and return the image file
            Navigator.of(context).pop(imageFile);
          },
        ),
      ),
    );

    if (capturedImage != null && mounted) {
      setState(() {
        _selectedFile = ReceiptFile(
          file: capturedImage,
          type: ReceiptFileType.image,
        );
        _selectedImage = capturedImage;
        _result = null;
      });
      // Automatically process the image after selection
      _processImage();
    }
  }

  Future<void> _pickDocument() async {
    // Request all permissions when receipt upload is accessed
    await _permissionService.requestAllPermissions();

    // Request storage permission for documents
    // Note: On Android 11+, file_picker uses scoped storage and may not need explicit permission
    // But we still request it for compatibility with older Android versions
    await _permissionService.requestStoragePermission();

    try {
      // Use pickDocumentFile for PDF/DOCX files
      // file_picker handles its own permissions on modern Android versions
      final file = await _ocrService.pickDocumentFile();

      if (file == null) {
        // User cancelled or no file selected
        return;
      }

      setState(() {
        _selectedFile = file;
        // For documents, we might not have an image to display
        _selectedImage = file.type == ReceiptFileType.image ? file.file : null;
        _result = null;
      });
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error picking document: $e';

        // Provide more helpful error messages
        if (e.toString().contains('permission') ||
            e.toString().contains('Permission')) {
          errorMessage =
              'Storage permission is required to select documents. Please grant permission in app settings.';

          // Optionally show a button to open settings
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => _permissionService.openAppSettings(),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _openBarcodeScanner() async {
    // Request camera permission
    await _permissionService.requestAllPermissions();
    final hasCamera = await _permissionService.requestCameraPermission();
    if (!hasCamera && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to scan barcodes'),
        ),
      );
      return;
    }

    if (!mounted) return;

    // Open barcode scanner screen
    final scanResult = await Navigator.of(context).push<BarcodeScanResult>(
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          onDataScanned: (result) {
            Navigator.of(context).pop(result);
          },
        ),
      ),
    );

    if (scanResult != null && mounted) {
      setState(() => _isProcessing = true);

      try {
        // Parse barcode data
        final result = await _barcodeParser.parseBarcodeResult(scanResult);
        setState(() {
          _result = result;
          _isProcessing = false;
        });

        if (result.success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Barcode scanned successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to parse barcode: $e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _processImage() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _ocrService.extractSubscriptionDetailsFromFile(
        _selectedFile!,
      );
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing file: $e')),
        );
      }
    }
  }

  Future<void> _addSubscription() async {
    if (_result == null || !_result!.success) return;

    final subscription = _result!.toSubscription();
    if (subscription == null) return;

    try {
      final notifier = ref.read(subscriptionControllerProvider.notifier);
      await notifier.addSubscription(subscription);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription added')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add subscription: $e')),
        );
      }
    }
  }

  void _showImageDialog(BuildContext context, File imageFile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final margin = screenWidth * 0.075; // 7.5% margin (between 5-10%)

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: margin),
        child: Stack(
          children: [
            PhotoView(
              imageProvider: FileImage(imageFile),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              initialScale: PhotoViewComputedScale.contained,
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
            ),
            Positioned(
              top: ResponsiveHelper.spacing(8),
              right: ResponsiveHelper.spacing(8),
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Receipt Upload'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload Receipt',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(12)),
                    Text(
                      'Take a photo or select an image of your subscription receipt or invoice.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(16)),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickImage(false),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                          ),
                        ),
                        SizedBox(width: ResponsiveHelper.spacing(12)),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openCameraWithMask(),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(12)),
                    OutlinedButton.icon(
                      onPressed: _pickDocument,
                      icon: const Icon(Icons.insert_drive_file),
                      label: const Text('Pick Document (PDF/DOCX)'),
                    ),
                    SizedBox(height: ResponsiveHelper.spacing(12)),
                    OutlinedButton.icon(
                      onPressed: _openBarcodeScanner,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Barcode/QR Code'),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedFile != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(20)),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Padding(
                  padding: EdgeInsets.only(top: ResponsiveHelper.spacing(24)),
                  child: Column(
                    children: [
                      if (_selectedImage != null)
                        GestureDetector(
                          onTap: () =>
                              _showImageDialog(context, _selectedImage!),
                          child: Image.file(
                            _selectedImage!,
                            height: ResponsiveHelper.height(200),
                            fit: BoxFit.contain,
                          ),
                        )
                      else
                        Padding(
                          padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                          child: Column(
                            children: [
                              Icon(
                                _selectedFile!.type == ReceiptFileType.pdf
                                    ? Icons.picture_as_pdf
                                    : Icons.description,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(12)),
                              Text(
                                _selectedFile!.type == ReceiptFileType.pdf
                                    ? 'PDF Document'
                                    : 'DOCX Document',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              SizedBox(height: ResponsiveHelper.spacing(4)),
                              Text(
                                _selectedFile!.file.path.split('/').last,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _processImage,
                          child: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Extract Details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_result != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(20)),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _result!.success
                            ? 'Extraction Successful'
                            : 'Extraction Failed',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: ResponsiveHelper.spacing(12)),
                      if (_result!.success) ...[
                        _DetailRow('Service', _result!.serviceName ?? ''),
                        _DetailRow('Cost',
                            '${_result!.currencyCode} ${_result!.cost?.toStringAsFixed(2)}'),
                        _DetailRow(
                            'Renewal Date',
                            _result!.renewalDate?.toString().split(' ').first ??
                                ''),
                        _DetailRow(
                            'Billing Cycle', _result!.billingCycle?.name ?? ''),
                        if (_result!.rawText != null &&
                            _result!.rawText!.isNotEmpty) ...[
                          SizedBox(height: ResponsiveHelper.spacing(16)),
                          Divider(),
                          SizedBox(height: ResponsiveHelper.spacing(12)),
                          Text(
                            'Extracted Text',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: ResponsiveHelper.spacing(8)),
                          _FormattedTextDisplay(text: _result!.rawText!),
                        ],
                        SizedBox(height: ResponsiveHelper.spacing(16)),
                        ElevatedButton(
                          onPressed: _addSubscription,
                          child: const Text('Add Subscription'),
                        ),
                      ] else ...[
                        Text(
                          _result!.error ?? 'Unknown error',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: ResponsiveHelper.spacing(20)),
            ],
            SizedBox(height: ResponsiveHelper.spacing(20)),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveHelper.spacing(8)),
      child: Row(
        //mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
          SizedBox(width: ResponsiveHelper.spacing(8)),
          Text(
            value,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display formatted text preserving layout structure
class _FormattedTextDisplay extends StatelessWidget {
  const _FormattedTextDisplay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = text.split('\n');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: SelectableText.rich(
        _buildFormattedTextSpan(context, lines, theme),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: ResponsiveHelper.fontSize(13),
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  TextSpan _buildFormattedTextSpan(
      BuildContext context, List<String> lines, ThemeData theme) {
    final spans = <TextSpan>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Check if line is empty (preserve spacing)
      if (line.trim().isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }

      // Preserve tabs and multiple spaces for alignment
      final preservedLine = _preserveSpacing(line);

      // Check if line looks like a header (all caps, short, or has special formatting)
      final isHeader = _isHeaderLine(line);

      spans.add(
        TextSpan(
          text: preservedLine,
          style: TextStyle(
            fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            fontSize: isHeader
                ? ResponsiveHelper.fontSize(14)
                : ResponsiveHelper.fontSize(13),
            color: isHeader
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
          ),
        ),
      );

      // Add newline except for last line
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: spans);
  }

  /// Preserve spacing structure (tabs and multiple spaces for alignment)
  String _preserveSpacing(String line) {
    // Replace tabs with multiple spaces for better display
    // Tabs are preserved but converted to visible spacing
    String result = line.replaceAll('\t', '    '); // 4 spaces per tab

    // Preserve multiple spaces for alignment
    return result.replaceAllMapped(RegExp(r' {2,}'), (match) {
      // Preserve spacing but limit excessive spaces
      final spaceCount = match.group(0)!.length;
      return ' ' * spaceCount.clamp(1, 20);
    });
  }

  /// Detect if a line is likely a header/title
  bool _isHeaderLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;

    // All caps and short (likely header)
    if (trimmed == trimmed.toUpperCase() && trimmed.length < 30) {
      return true;
    }

    // Contains common header patterns
    final headerPatterns = [
      RegExp(r'^[A-Z][A-Z\s]+$'), // All caps words
      RegExp(r'^[A-Z][^a-z]{0,20}$'), // Starts with capital, no lowercase
    ];

    for (final pattern in headerPatterns) {
      if (pattern.hasMatch(trimmed)) {
        return true;
      }
    }

    return false;
  }
}
