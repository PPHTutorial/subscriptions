import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../../../subscriptions/application/subscription_controller.dart';
import '../data/receipt_ocr_service.dart';

class ReceiptUploadScreen extends ConsumerStatefulWidget {
  const ReceiptUploadScreen({super.key});

  @override
  ConsumerState<ReceiptUploadScreen> createState() =>
      _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends ConsumerState<ReceiptUploadScreen> {
  final _ocrService = ReceiptOcrService();
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

  Future<void> _pickDocument() async {
    // Request all permissions when receipt upload is accessed
    await _permissionService.requestAllPermissions();

    // Request storage permission for documents
    final hasStorage = await _permissionService.requestStoragePermission();
    if (!hasStorage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Storage permission is required to select documents'),
        ),
      );
      return;
    }

    try {
      // Use pickDocumentFile for PDF/DOCX files
      final file = await _ocrService.pickDocumentFile();
      setState(() {
        _selectedFile = file;
        // For documents, we might not have an image to display
        _selectedImage =
            file?.type == ReceiptFileType.image ? file?.file : null;
        _result = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error picking document: $e',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
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

    final notifier = ref.read(subscriptionControllerProvider.notifier);
    await notifier.addSubscription(subscription);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription added')),
      );
      Navigator.pop(context);
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
      appBar: AppBar(
        title: const Text('Receipt Upload'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
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
                            onPressed: () => _pickImage(true),
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
                  ],
                ),
              ),
            ),
            if (_selectedFile != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(20)),
              Card(
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
            ],
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
