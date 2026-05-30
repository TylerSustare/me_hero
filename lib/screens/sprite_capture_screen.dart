import 'eraser_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sprite_processor.dart';
import '../models/hero_character.dart';
import '../providers.dart';

enum SpritePose {
  idle1, idle2,
}

extension SpritePoseDetails on SpritePose {
  String get instructionText {
    switch (this) {
      case SpritePose.idle1: return "Stand relaxed, facing sideways.";
      case SpritePose.idle2: return "Same pose, chest slightly puffed out.";
    }
  }

  String get maskAssetPath => 'assets/masks/${name}_mask.png';
}

class SpriteCaptureScreen extends ConsumerStatefulWidget {
  final List<CameraDescription> cameras;
  final String heroName;
  final List<SpritePose> requiredPoses;

  const SpriteCaptureScreen({
    super.key,
    required this.cameras,
    required this.heroName,
    required this.requiredPoses,
  });

  @override
  ConsumerState<SpriteCaptureScreen> createState() => _SpriteCaptureScreenState();
}

class _SpriteCaptureScreenState extends ConsumerState<SpriteCaptureScreen> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  bool _isProcessingSession = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.front;
  
  int _currentPoseIndex = 0;
  SpritePose get currentPose => widget.requiredPoses[_currentPoseIndex];
  
  final List<String> _erasedFrames = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == _currentLensDirection,
      orElse: () => widget.cameras.first,
    );

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      if (_isCameraInitialized) {
        setState(() => _isCameraInitialized = false);
      }
      await _controller.initialize();
      await _controller.lockCaptureOrientation();
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  void _toggleCamera() {
    setState(() {
      _currentLensDirection = _currentLensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });
    _initCamera();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureFrame() async {
    if (!_controller.value.isInitialized || _isProcessingSession) return;

    try {
      setState(() => _isProcessingSession = true);
      final file = await _controller.takePicture();
      
      if (!mounted) return;

      // Crop the raw photo down to a tight square so the user doesn't have to erase empty space
      final croppedPath = await SpriteProcessor.cropToCenterSquare(file.path);

      if (!mounted) return;

      // Slice out 85% of the static background cleanly using ML Kit 
      final segmentedPath = await SpriteProcessor.segmentImageToPath(croppedPath);

      if (!mounted) return;

      // Pass the fully pre-processed image to the Eraser for micro-touchups
      final String? erasedPath = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EraserScreen(
            imagePath: segmentedPath ?? croppedPath, 
            poseName: currentPose.name
          ),
        ),
      );

      if (!mounted) return;
      
      // If they pressed back/cancelled on EraserScreen, let them retake
      if (erasedPath == null) {
        setState(() => _isProcessingSession = false);
        return; 
      }

      // Step 3: Accept the erased image, advance or finish
      setState(() {
        _erasedFrames.add(erasedPath);
        _isProcessingSession = false;
        
        if (_currentPoseIndex < widget.requiredPoses.length - 1) {
          _currentPoseIndex++;
        } else {
          _isProcessingSession = true; // Lock UI for final render
          _processAndFinish();
        }
      });
    } catch (e) {
      debugPrint("Error capturing frame: $e");
      if (mounted) {
         setState(() => _isProcessingSession = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to segment image: $e')));
      }
    }
  }
  
  Future<void> _processAndFinish() async {
    try {
      final heroId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final spritePath = await SpriteProcessor.generateHeroSpriteSheet(heroId, _erasedFrames);
      
      if (spritePath != null) {
        final newHero = HeroCharacter(
          id: heroId,
          name: widget.heroName,
          spriteSheetPath: spritePath,
          createdAt: DateTime.now(),
        );
        
        // Save using Riverpod
        await ref.read(heroesProvider.notifier).addHero(newHero);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Hero ${widget.heroName} created successfully!'))
           );
           // Pop back to Heroes List Page
           Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        throw Exception("Sprite processing returned null path.");
      }
    } catch (e, stack) {
      debugPrint("Processing error captured in UI: $e\n$stack");
      if (mounted) {
        setState(() => _isProcessingSession = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Processing Error'),
            content: SingleChildScrollView(
              child: Text(
                'Something crashed while generating your sprites:\n\n$e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text('Dismiss'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Try to reset the capture flow so they can retake it
                  setState(() {
                    _erasedFrames.clear();
                    _currentPoseIndex = 0;
                  });
                },
                child: const Text('Restart Photos'),
              )
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_isProcessingSession) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.deepPurpleAccent),
              const SizedBox(height: 24),
              Text(
                "Pixelating ${widget.heroName}...",
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRect(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Square Camera Feed mapped precisely cleanly over the crop bounds
                      Transform.scale(
                        scale: _controller.value.aspectRatio < 1.0
                            ? 1.0 / _controller.value.aspectRatio
                            : _controller.value.aspectRatio,
                        child: Center(
                          child: CameraPreview(_controller),
                        ),
                      ),
                      // The new 600x600 square mask perfectly aligned natively
                      IgnorePointer(
                        child: Opacity(
                          opacity: 0.8, 
                          child: Image.asset(
                            currentPose.maskAssetPath,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FloatingActionButton(
                        heroTag: 'capture_button',
                        onPressed: _captureFrame,
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.camera_alt, color: Colors.black),
                      ),
                      const SizedBox(width: 20),
                      FloatingActionButton(
                        heroTag: 'flip_button',
                        onPressed: _toggleCamera,
                        backgroundColor: Colors.black54,
                        child: const Icon(Icons.flip_camera_ios, color: Colors.white),
                      ),
                    ],
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
