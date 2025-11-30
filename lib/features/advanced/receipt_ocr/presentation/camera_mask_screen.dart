import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
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

      if (mounted) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;

        // Open image cropper for cropping
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: imageFile.path,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Receipt',
              toolbarColor: colorScheme.primary,
              toolbarWidgetColor: colorScheme.onPrimary,
              backgroundColor:
                  isDark ? colorScheme.surface : colorScheme.surface,
              activeControlsWidgetColor: colorScheme.primary,
              dimmedLayerColor: Colors.black.withOpacity(0.5),
              cropFrameColor: colorScheme.primary,
              cropFrameStrokeWidth: 2,
              cropGridColor: colorScheme.primary.withOpacity(0.3),
              cropGridStrokeWidth: 1,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Crop Receipt',
              doneButtonTitle: 'Done',
              cancelButtonTitle: 'Cancel',
              aspectRatioPresets: [
                CropAspectRatioPreset.original,
                CropAspectRatioPreset.square,
                CropAspectRatioPreset.ratio3x2,
                CropAspectRatioPreset.ratio4x3,
                CropAspectRatioPreset.ratio16x9,
              ],
            ),
          ],
        );

        if (croppedFile != null && mounted) {
          // Return the cropped file via callback
          widget.onImageCaptured(File(croppedFile.path));
        } else if (mounted) {
          // Use original image if user cancelled cropping
          widget.onImageCaptured(imageFile);
        }
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(title: const Text('Camera')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
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
