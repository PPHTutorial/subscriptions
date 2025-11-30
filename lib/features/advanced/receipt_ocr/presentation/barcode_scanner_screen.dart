import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/responsive/responsive_helper.dart';
import '../data/barcode_scan_result.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    required this.onDataScanned,
  });

  final Function(BarcodeScanResult) onDataScanned;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.all],
  );

  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onBarcodeDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;

    if (rawValue == null || rawValue == _lastScannedCode) return;

    _lastScannedCode = rawValue;
    setState(() => _isProcessing = true);

    // Process the scanned data
    _processScannedData(rawValue, barcode.type);
  }

  Future<void> _processScannedData(String data, BarcodeType type) async {
    try {
      // Parse the scanned data
      final result = _parseBarcodeData(data, type);

      if (mounted) {
        // Callback will handle navigation
        widget.onDataScanned(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing barcode: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  BarcodeScanResult _parseBarcodeData(String data, BarcodeType type) {
    // Try to parse as URL
    if (data.startsWith('http://') || data.startsWith('https://')) {
      return BarcodeScanResult(
        type: BarcodeScanType.url,
        rawData: data,
        url: data,
      );
    }

    // Try to parse as JSON
    try {
      final json = Uri.splitQueryString(data);
      if (json.isNotEmpty) {
        return BarcodeScanResult(
          type: BarcodeScanType.structured,
          rawData: data,
          parsedData: json,
        );
      }
    } catch (_) {
      // Not a query string, try JSON
      try {
        final jsonData = data;
        // Check if it looks like JSON
        if (jsonData.trim().startsWith('{') ||
            jsonData.trim().startsWith('[')) {
          return BarcodeScanResult(
            type: BarcodeScanType.json,
            rawData: data,
            jsonData: jsonData,
          );
        }
      } catch (_) {
        // Not JSON either
      }
    }

    // Try to extract subscription info from text patterns
    final subscriptionInfo = _extractSubscriptionInfo(data);

    return BarcodeScanResult(
      type: BarcodeScanType.text,
      rawData: data,
      subscriptionInfo: subscriptionInfo,
    );
  }

  Map<String, dynamic>? _extractSubscriptionInfo(String data) {
    final info = <String, dynamic>{};

    // Extract service name patterns
    final servicePatterns = [
      RegExp(r'service[:\s]+([^\n,]+)', caseSensitive: false),
      RegExp(r'provider[:\s]+([^\n,]+)', caseSensitive: false),
      RegExp(r'company[:\s]+([^\n,]+)', caseSensitive: false),
    ];

    for (final pattern in servicePatterns) {
      final match = pattern.firstMatch(data);
      if (match != null) {
        info['serviceName'] = match.group(1)?.trim();
        break;
      }
    }

    // Extract cost patterns
    final costPatterns = [
      RegExp(r'amount[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'cost[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'price[:\s]+([0-9.]+)', caseSensitive: false),
      RegExp(r'([0-9.]+)\s*(USD|EUR|GBP|GHS|NGN)', caseSensitive: false),
    ];

    for (final pattern in costPatterns) {
      final match = pattern.firstMatch(data);
      if (match != null) {
        final cost = double.tryParse(match.group(1) ?? '');
        if (cost != null) {
          info['cost'] = cost;
          if (match.groupCount > 1 && match.group(2) != null) {
            info['currencyCode'] = match.group(2)?.toUpperCase();
          }
          break;
        }
      }
    }

    // Extract date patterns
    final datePatterns = [
      RegExp(r'date[:\s]+([0-9]{4}[-/][0-9]{2}[-/][0-9]{2})',
          caseSensitive: false),
      RegExp(r'expir[ey][:\s]+([0-9]{4}[-/][0-9]{2}[-/][0-9]{2})',
          caseSensitive: false),
      RegExp(r'([0-9]{4}[-/][0-9]{2}[-/][0-9]{2})', caseSensitive: false),
    ];

    for (final pattern in datePatterns) {
      final match = pattern.firstMatch(data);
      if (match != null) {
        try {
          final dateStr = match.group(1)?.replaceAll('/', '-');
          if (dateStr != null) {
            info['renewalDate'] = DateTime.tryParse(dateStr);
          }
        } catch (_) {
          // Invalid date format
        }
        break;
      }
    }

    return info.isEmpty ? null : info;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Scan Barcode/QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner view
          MobileScanner(
            controller: _controller,
            onDetect: _onBarcodeDetect,
          ),
          // Overlay with scanning frame
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(),
            ),
          ),
          // Instructions
          Positioned(
            top: ResponsiveHelper.spacing(16),
            left: ResponsiveHelper.spacing(16),
            right: ResponsiveHelper.spacing(16),
            child: Container(
              padding: EdgeInsets.all(ResponsiveHelper.spacing(12)),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Position the barcode/QR code within the frame',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveHelper.fontSize(14),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Processing indicator
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Calculate frame size (80% of screen)
    final frameWidth = size.width * 0.8;
    final frameHeight = size.height * 0.4;
    final frameLeft = (size.width - frameWidth) / 2;
    final frameTop = (size.height - frameHeight) / 2;

    // Draw dark overlay
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create transparent frame
    final framePath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight),
          const Radius.circular(12),
        ),
      );

    final combinedPath = Path.combine(
      PathOperation.difference,
      path,
      framePath,
    );

    canvas.drawPath(combinedPath, paint);

    // Draw frame border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(frameLeft, frameTop, frameWidth, frameHeight),
        const Radius.circular(12),
      ),
      borderPaint,
    );

    // Draw corner guides
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerLength = 30.0;

    // Top-left corner
    canvas.drawLine(
      Offset(frameLeft, frameTop),
      Offset(frameLeft + cornerLength, frameTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft, frameTop),
      Offset(frameLeft, frameTop + cornerLength),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop),
      Offset(frameLeft + frameWidth - cornerLength, frameTop),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop),
      Offset(frameLeft + frameWidth, frameTop + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(frameLeft, frameTop + frameHeight),
      Offset(frameLeft + cornerLength, frameTop + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft, frameTop + frameHeight),
      Offset(frameLeft, frameTop + frameHeight - cornerLength),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop + frameHeight),
      Offset(frameLeft + frameWidth - cornerLength, frameTop + frameHeight),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frameLeft + frameWidth, frameTop + frameHeight),
      Offset(frameLeft + frameWidth, frameTop + frameHeight - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(_ScannerOverlayPainter oldDelegate) => false;
}
