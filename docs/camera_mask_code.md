```dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:me_hero/services/sprite_processor.dart';

/// Defines the exhaustive list of poses we need the user to capture.
enum SpritePose {
  idle1, idle2,
  walk1, walk2,
  run1, run2, run3,
  jump1, fall1, celebrate1,
  attack1, attack2,
  takeDamage1, defeat1,
  crouch1, climb1, climb2
}

extension SpritePoseDetails on SpritePose {
  String get instructionText {
    switch (this) {
      case SpritePose.idle1: return "Stand relaxed, facing sideways.";
      case SpritePose.idle2: return "Same pose, chest slightly puffed out.";
      case SpritePose.run1: return "Take a deep running stride!";
      case SpritePose.jump1: return "Reach up and tuck your knees!";
      case SpritePose.defeat1: return "Slump over, arms dangling.";
      default: return "Strike the pose shown on screen!";
    }
  }

  /// The path to the transparent PNG that acts as the "ghost" alignment mask.
  String get maskAssetPath => 'assets/masks/${this.name}_mask.png';
}

/// The main camera interface for capturing sprite frames.
class SpriteCaptureScreen extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  final List<SpritePose> requiredPoses;

  const SpriteCaptureScreen({
    Key? key,
    required this.cameras,
    required this.requiredPoses,
  }) : super(key: key);

  @override
  ConsumerState<SpriteCaptureScreen> createState() => _SpriteCaptureScreenState();
}

class _SpriteCaptureScreenState extends ConsumerState<SpriteCaptureScreen> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  
  int _currentPoseIndex = 0;
  SpritePose get currentPose => widget.requiredPoses[_currentPoseIndex];
  
  // To hold the captured images in memory for the session
  final Map<SpritePose, XFile> _capturedFrames = {};

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller.initialize();
      await _controller.lockCaptureOrientation();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureFrame() async {
    if (!_controller.value.isInitialized || _controller.value.isTakingPicture || _isProcessing) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final XFile rawImage = await _controller.takePicture();
      _capturedFrames[currentPose] = rawImage;

      if (_currentPoseIndex < widget.requiredPoses.length - 1) {
        setState(() {
          _currentPoseIndex++;
          _isProcessing = false;
        });
      } else {
        // All frames for this session are captured.
        // Return the captured frames back to the creation flow
        if (mounted) {
          Navigator.pop(context, _capturedFrames);
        }
      }
    } catch (e) {
      debugPrint("Capture error: $e");
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CameraPreview(_controller),
            ),
            IgnorePointer(
              child: Opacity(
                opacity: 0.4,
                child: Image.asset(
                  currentPose.maskAssetPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentPose.instructionText,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              child: Column(
                children: [
                  Text(
                    "Pose ${_currentPoseIndex + 1} of ${widget.requiredPoses.length}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _isProcessing 
                      ? const CircularProgressIndicator()
                      : FloatingActionButton(
                          onPressed: _captureFrame,
                          backgroundColor: Colors.white,
                          child: const Icon(Icons.camera_alt, color: Colors.black),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```
