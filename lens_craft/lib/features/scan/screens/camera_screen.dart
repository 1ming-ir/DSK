import 'dart:io'; // Add this import
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lens_craft/core/theme/app_theme.dart';
import 'package:lens_craft/features/editor/screens/editor_screen.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isReady = false;
  final List<XFile> _capturedImages = [];
  FlashMode _flashMode = FlashMode.auto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    final controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } on CameraException catch (e) {
      debugPrint('Camera Error: $e');
    }
  }

  Future<void> _takePicture() async {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (cameraController.value.isTakingPicture) {
      return;
    }

    try {
      HapticFeedback.mediumImpact();
      final XFile file = await cameraController.takePicture();
      
      if (mounted) {
        setState(() {
          _capturedImages.add(file);
        });
        
        // Show a quick flash animation or sound could go here
      }
    } on CameraException catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  void _toggleFlash() {
    if (_controller == null) return;

    FlashMode nextMode;
    IconData icon;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        icon = Icons.flash_auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        icon = Icons.flash_on;
        break;
      default:
        nextMode = FlashMode.off;
        icon = Icons.flash_off;
        break;
    }

    _controller!.setFlashMode(nextMode);
    setState(() {
      _flashMode = nextMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Camera Preview
            Center(
              child: CameraPreview(_controller!),
            ),

            // 2. Top Controls
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.black45,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    IconButton(
                      icon: Icon(
                        _flashMode == FlashMode.auto
                            ? Icons.flash_auto
                            : _flashMode == FlashMode.always
                                ? Icons.flash_on
                                : Icons.flash_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFlash,
                    ),
                  ],
                ),
              ),
            ),

            // 3. Edge Detection Overlay (Placeholder for now)
            // We will add CustomPainter here later for the blue box

            // 4. Bottom Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(bottom: 32, top: 20),
                color: Colors.black54,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Preview/Gallery Thumbnail
                    _capturedImages.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              // TODO: Go to gallery/editor with images
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 2),
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(File(_capturedImages.last.path)), // Changed from XFileImage to FileImage
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${_capturedImages.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(width: 48),

                    // Shutter Button
                    GestureDetector(
                      onTap: _takePicture,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          color: Colors.white24,
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // Done Button
                    TextButton(
                      onPressed: _capturedImages.isNotEmpty
                          ? () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EditorScreen(images: _capturedImages),
                                ),
                              );
                              // If document was saved, pop camera screen
                              if (result == true && mounted) {
                                Navigator.of(context).pop(true);
                              }
                            }
                          : null,
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: _capturedImages.isNotEmpty ? AppTheme.primaryColor : Colors.grey,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

