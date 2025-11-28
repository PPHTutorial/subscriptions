import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  File? _selectedImage;
  bool _isProcessing = false;
  ReceiptExtractionResult? _result;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool fromCamera) async {
    final image = await _ocrService.pickImage(fromCamera: fromCamera);
    setState(() {
      _selectedImage = image;
      _result = null;
    });
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final result =
          await _ocrService.extractSubscriptionDetails(_selectedImage!);
      setState(() {
        _result = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Upload'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(ResponsiveHelper.spacing(20)),
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
                  ],
                ),
              ),
            ),
            if (_selectedImage != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(20)),
              Card(
                child: Column(
                  children: [
                    Image.file(
                      _selectedImage!,
                      height: ResponsiveHelper.height(200),
                      fit: BoxFit.contain,
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
            ],
            if (_result != null) ...[
              SizedBox(height: ResponsiveHelper.spacing(20)),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(ResponsiveHelper.spacing(16)),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
