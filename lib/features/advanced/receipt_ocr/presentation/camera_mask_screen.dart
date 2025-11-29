import 'dart:io';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/responsive/responsive_helper.dart';

class CameraMaskScreen extends StatefulWidget {
  const CameraMaskScreen({
    super.key,
    required this.onImageCaptured,
  });

  final Function(File) onImageCaptured;

  @override
  State<CameraMaskScreen> createState() => _CameraMaskScreenState();
}

class _CameraMaskScreenState extends State<CameraMaskScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isCapturing = false;

  // Mask bounds (normalized 0.0 to 1.0)
  Offset _topLeft = const Offset(0.1, 0.2);
  Offset _topRight = const Offset(0.9, 0.2);
  Offset _bottomLeft = const Offset(0.1, 0.8);
  Offset _bottomRight = const Offset(0.9, 0.8);
  Offset? _draggingCorner;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available')),
          );
          Navigator.pop(context);
        }
        return;
      }

      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize camera: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureAndCrop() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isCapturing = true);

    try {
      final image = await _controller!.takePicture();
      final imageFile = File(image.path);

      // Get the actual image dimensions
      final imageSize = await _getImageSize(imageFile);
      if (imageSize == null) {
        throw Exception('Failed to get image size');
      }

      // Calculate crop area from mask bounds
      final cropRect = _calculateCropRect(imageSize);

      // Crop the image based on mask bounds
      final croppedFile = await _cropImageToMask(imageFile, cropRect);

      if (croppedFile != null && mounted) {
        // Open image cropper for fine-tuning if needed
        final finalCropped = await ImageCropper().cropImage(
          sourcePath: croppedFile.path,
          cropStyle: CropStyle.rectangle,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Fine-tune Crop',
              toolbarColor: Theme.of(context).colorScheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
            ),
            IOSUiSettings(
              title: 'Fine-tune Crop',
            ),
          ],
        );

        if (finalCropped != null && mounted) {
          widget.onImageCaptured(File(finalCropped.path));
          Navigator.pop(context);
        } else if (mounted) {
          // Use the mask-cropped image if user cancelled fine-tuning
          widget.onImageCaptured(croppedFile);
          Navigator.pop(context);
        }
      } else if (mounted) {
        // Fallback to original image if cropping failed
        widget.onImageCaptured(imageFile);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to capture image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Future<Size?> _getImageSize(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    } catch (e) {
      return null;
    }
  }

  Rect _calculateCropRect(Size imageSize) {
    // Convert normalized mask coordinates to pixel coordinates
    final left = _topLeft.dx * imageSize.width;
    final top = _topLeft.dy * imageSize.height;
    final right = _bottomRight.dx * imageSize.width;
    final bottom = _bottomRight.dy * imageSize.height;

    // Ensure valid rectangle
    final width = (right - left).clamp(10.0, imageSize.width);
    final height = (bottom - top).clamp(10.0, imageSize.height);

    return Rect.fromLTWH(
      left.clamp(0.0, imageSize.width - width),
      top.clamp(0.0, imageSize.height - height),
      width,
      height,
    );
  }

  Future<File?> _cropImageToMask(File imageFile, Rect cropRect) async {
    try {
      // Read image bytes
      final bytes = await imageFile.readAsBytes();

      // Decode image
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      // Crop the image
      final cropped = img.copyCrop(
        image,
        x: cropRect.left.toInt(),
        y: cropRect.top.toInt(),
        width: cropRect.width.toInt(),
        height: cropRect.height.toInt(),
      );

      // Encode as JPEG
      final croppedBytes = img.encodeJpg(cropped, quality: 90);

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final croppedFile = File(
          '${tempDir.path}/cropped_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await croppedFile.writeAsBytes(croppedBytes);

      return croppedFile;
    } catch (e) {
      return null;
    }
  }

  void _onPanStart(DragStartDetails details, Offset corner) {
    _draggingCorner = corner;
  }

  void _onPanUpdate(DragUpdateDetails details, Size screenSize) {
    if (_draggingCorner == null) return;

    final delta = details.delta;
    final normalizedDelta = Offset(
      delta.dx / screenSize.width,
      delta.dy / screenSize.height,
    );

    setState(() {
      if (_draggingCorner == _topLeft) {
        final newX =
            (_topLeft.dx + normalizedDelta.dx).clamp(0.0, _topRight.dx - 0.05);
        final newY = (_topLeft.dy + normalizedDelta.dy)
            .clamp(0.0, _bottomLeft.dy - 0.05);
        _topLeft = Offset(newX, newY);
        _bottomLeft = Offset(newX, _bottomLeft.dy);
        _topRight = Offset(_topRight.dx, newY);
      } else if (_draggingCorner == _topRight) {
        final newX =
            (_topRight.dx + normalizedDelta.dx).clamp(_topLeft.dx + 0.05, 1.0);
        final newY = (_topRight.dy + normalizedDelta.dy)
            .clamp(0.0, _bottomRight.dy - 0.05);
        _topRight = Offset(newX, newY);
        _topLeft = Offset(_topLeft.dx, newY);
        _bottomRight = Offset(newX, _bottomRight.dy);
      } else if (_draggingCorner == _bottomLeft) {
        final newX = (_bottomLeft.dx + normalizedDelta.dx)
            .clamp(0.0, _bottomRight.dx - 0.05);
        final newY = (_bottomLeft.dy + normalizedDelta.dy)
            .clamp(_topLeft.dy + 0.05, 1.0);
        _bottomLeft = Offset(newX, newY);
        _topLeft = Offset(newX, _topLeft.dy);
        _bottomRight = Offset(_bottomRight.dx, newY);
      } else if (_draggingCorner == _bottomRight) {
        final newX = (_bottomRight.dx + normalizedDelta.dx)
            .clamp(_bottomLeft.dx + 0.05, 1.0);
        final newY = (_bottomRight.dy + normalizedDelta.dy)
            .clamp(_topRight.dy + 0.05, 1.0);
        _bottomRight = Offset(newX, newY);
        _topRight = Offset(newX, _topRight.dy);
        _bottomLeft = Offset(_bottomLeft.dx, newY);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _draggingCorner = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Capture Receipt'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          // Mask overlay
          Positioned.fill(
            child: CustomPaint(
              painter: _MaskPainter(
                topLeft: _topLeft,
                topRight: _topRight,
                bottomLeft: _bottomLeft,
                bottomRight: _bottomRight,
                screenSize: screenSize,
              ),
            ),
          ),
          // Corner handlers
          _CornerHandler(
            position: _topLeft,
            screenSize: screenSize,
            onPanStart: (details) => _onPanStart(details, _topLeft),
            onPanUpdate: (details) => _onPanUpdate(details, screenSize),
            onPanEnd: _onPanEnd,
          ),
          _CornerHandler(
            position: _topRight,
            screenSize: screenSize,
            onPanStart: (details) => _onPanStart(details, _topRight),
            onPanUpdate: (details) => _onPanUpdate(details, screenSize),
            onPanEnd: _onPanEnd,
          ),
          _CornerHandler(
            position: _bottomLeft,
            screenSize: screenSize,
            onPanStart: (details) => _onPanStart(details, _bottomLeft),
            onPanUpdate: (details) => _onPanUpdate(details, screenSize),
            onPanEnd: _onPanEnd,
          ),
          _CornerHandler(
            position: _bottomRight,
            screenSize: screenSize,
            onPanStart: (details) => _onPanStart(details, _bottomRight),
            onPanUpdate: (details) => _onPanUpdate(details, screenSize),
            onPanEnd: _onPanEnd,
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
                'Adjust the corners to frame your receipt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: ResponsiveHelper.fontSize(14),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Capture button
          Positioned(
            bottom: ResponsiveHelper.spacing(32),
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _isCapturing ? null : _captureAndCrop,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: _isCapturing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.camera_alt, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaskPainter extends CustomPainter {
  _MaskPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.screenSize,
  });

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomLeft;
  final Offset bottomRight;
  final Size screenSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create mask hole
    final maskPath = Path()
      ..moveTo(topLeft.dx * size.width, topLeft.dy * size.height)
      ..lineTo(topRight.dx * size.width, topRight.dy * size.height)
      ..lineTo(bottomRight.dx * size.width, bottomRight.dy * size.height)
      ..lineTo(bottomLeft.dx * size.width, bottomLeft.dy * size.height)
      ..close();

    final combinedPath = Path.combine(
      PathOperation.difference,
      path,
      maskPath,
    );

    canvas.drawPath(combinedPath, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(maskPath, borderPaint);

    // Draw corner guides
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final cornerSize = 20.0;
    _drawCornerGuide(
      canvas,
      cornerPaint,
      topLeft.dx * size.width,
      topLeft.dy * size.height,
      cornerSize,
    );
    _drawCornerGuide(
      canvas,
      cornerPaint,
      topRight.dx * size.width,
      topRight.dy * size.height,
      cornerSize,
    );
    _drawCornerGuide(
      canvas,
      cornerPaint,
      bottomLeft.dx * size.width,
      bottomLeft.dy * size.height,
      cornerSize,
    );
    _drawCornerGuide(
      canvas,
      cornerPaint,
      bottomRight.dx * size.width,
      bottomRight.dy * size.height,
      cornerSize,
    );
  }

  void _drawCornerGuide(
      Canvas canvas, Paint paint, double x, double y, double size) {
    // Draw L-shaped corner guide
    canvas.drawLine(Offset(x, y), Offset(x + size, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + size), paint);
  }

  @override
  bool shouldRepaint(_MaskPainter oldDelegate) {
    return topLeft != oldDelegate.topLeft ||
        topRight != oldDelegate.topRight ||
        bottomLeft != oldDelegate.bottomLeft ||
        bottomRight != oldDelegate.bottomRight;
  }
}

class _CornerHandler extends StatelessWidget {
  const _CornerHandler({
    required this.position,
    required this.screenSize,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final Offset position;
  final Size screenSize;
  final Function(DragStartDetails) onPanStart;
  final Function(DragUpdateDetails) onPanUpdate;
  final Function(DragEndDetails) onPanEnd;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx * screenSize.width - 20,
      top: position.dy * screenSize.height - 20,
      child: GestureDetector(
        onPanStart: onPanStart,
        onPanUpdate: onPanUpdate,
        onPanEnd: onPanEnd,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
                color: Theme.of(context).colorScheme.primary, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.drag_handle,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
