import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'eraser_screen.dart';
import '../services/sprite_processor.dart';
import '../models/hero_character.dart';
import '../providers.dart';

enum SpritePose { idle1, idle2, run1, run2, jump }

extension SpritePoseDetails on SpritePose {
  String get instructionText {
    switch (this) {
      case SpritePose.idle1:
        return "Turn sideways and stand naturally.";
      case SpritePose.idle2:
        return "Stay sideways, then lift your chest a little.";
      case SpritePose.run1:
        return "Freeze mid-run: left leg and right arm forward.";
      case SpritePose.run2:
        return "Switch sides: right leg and left arm forward.";
      case SpritePose.jump:
        return "Reach up and bend your knees like you're airborne.";
    }
  }

  String get title {
    switch (this) {
      case SpritePose.idle1:
        return 'Hero stance';
      case SpritePose.idle2:
        return 'Power stance';
      case SpritePose.run1:
        return 'Run · first stride';
      case SpritePose.run2:
        return 'Run · second stride';
      case SpritePose.jump:
        return 'Super jump';
    }
  }
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
  ConsumerState<SpriteCaptureScreen> createState() =>
      _SpriteCaptureScreenState();
}

class _SpriteCaptureScreenState extends ConsumerState<SpriteCaptureScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isProcessingSession = false;
  String _processingMessage = 'Finding your outline…';
  String? _cameraError;
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
    if (widget.cameras.isEmpty) {
      setState(() => _cameraError = 'No camera was found on this device.');
      return;
    }
    final camera = widget.cameras.firstWhere(
      (c) => c.lensDirection == _currentLensDirection,
      orElse: () => widget.cameras.first,
    );

    final previousController = _controller;
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _controller = controller;

    try {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraError = null;
        });
      }
      await previousController?.dispose();
      await controller.initialize();
      await controller.lockCaptureOrientation();
      if (mounted && identical(_controller, controller)) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
      if (mounted && identical(_controller, controller)) {
        setState(
          () => _cameraError =
              'We couldn’t start the camera. Check camera access and try again.',
        );
      }
    }
  }

  Future<void> _toggleCamera() async {
    if (widget.cameras.map((camera) => camera.lensDirection).toSet().length <
        2) {
      return;
    }
    setState(() {
      _currentLensDirection = _currentLensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });
    await _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _captureFrame() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _isProcessingSession) {
      return;
    }

    try {
      setState(() {
        _isProcessingSession = true;
        _processingMessage = 'Finding your outline…';
      });
      final file = await controller.takePicture();

      if (!mounted) return;

      // Crop the raw photo down to a tight square so the user doesn't have to erase empty space
      final croppedPath = await SpriteProcessor.cropToCenterSquare(file.path);

      if (!mounted) return;

      // Slice out 85% of the static background cleanly using ML Kit
      final segmentedPath = await SpriteProcessor.segmentImageToPath(
        croppedPath,
      );

      if (!mounted) return;

      // Pass the fully pre-processed image to the Eraser for micro-touchups
      final String? erasedPath = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EraserScreen(
            imagePath: segmentedPath ?? croppedPath,
            sourceImagePath: croppedPath,
            poseName: currentPose.title,
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
          _processingMessage = 'Building ${widget.heroName}…';
          _processAndFinish();
        }
      });
    } catch (e) {
      debugPrint("Error capturing frame: $e");
      if (mounted) {
        setState(() => _isProcessingSession = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That photo didn’t process correctly. Please try it again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _processAndFinish() async {
    try {
      final heroId = DateTime.now().millisecondsSinceEpoch.toString();

      final spritePath = await SpriteProcessor.generateHeroSpriteSheet(
        heroId,
        _erasedFrames,
      );

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
            SnackBar(
              content: Text('Hero ${widget.heroName} created successfully!'),
            ),
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
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF090A10),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.no_photography_outlined,
                    color: Colors.white70,
                    size: 56,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _cameraError!,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _initCamera,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF090A10),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B7CFF)),
        ),
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
                _processingMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This usually takes just a moment.',
                style: TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;
    final canFlip =
        widget.cameras.map((camera) => camera.lensDirection).toSet().length > 1;
    return Scaffold(
      backgroundColor: const Color(0xFF090A10),
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
                        scale: controller.value.aspectRatio < 1.0
                            ? 1.0 / controller.value.aspectRatio
                            : controller.value.aspectRatio,
                        child: Center(child: CameraPreview(controller)),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _PoseGuidePainter(currentPose),
                        ),
                      ),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white24),
                            gradient: const RadialGradient(
                              colors: [Colors.transparent, Color(0x66000000)],
                              stops: [0.62, 1],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value:
                            (_currentPoseIndex + 1) /
                            widget.requiredPoses.length,
                        backgroundColor: Colors.white24,
                        color: const Color(0xFF8B7CFF),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_currentPoseIndex + 1}/${widget.requiredPoses.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 70,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xD9141520),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    Text(
                      currentPose.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentPose.instructionText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 52),
                  const Spacer(),
                  Semantics(
                    button: true,
                    label: 'Take photo for ${currentPose.title}',
                    child: GestureDetector(
                      onTap: _captureFrame,
                      child: Container(
                        width: 78,
                        height: 78,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: canFlip ? _toggleCamera : null,
                    icon: const Icon(Icons.cameraswitch_outlined),
                    tooltip: 'Switch camera',
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

class _PoseGuidePainter extends CustomPainter {
  _PoseGuidePainter(this.pose);

  final SpritePose pose;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (pose == SpritePose.run2) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    Offset point(double x, double y) => Offset(x * size.width, y * size.height);
    final glow = Paint()
      ..color = const Color(0x669F8CFF)
      ..strokeWidth = size.shortestSide * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.86)
      ..strokeWidth = size.shortestSide * 0.013
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    late Offset head;
    late List<List<Offset>> limbs;
    if (pose == SpritePose.idle1 || pose == SpritePose.idle2) {
      head = point(pose == SpritePose.idle2 ? .52 : .50, .25);
      limbs = [
        [point(.50, .34), point(.50, .55), point(.49, .73), point(.51, .88)],
        [point(.50, .40), point(.44, .55), point(.47, .67)],
        [point(.51, .40), point(.56, .55), point(.54, .67)],
        [point(.49, .71), point(.44, .86)],
        [point(.50, .71), point(.56, .86)],
      ];
    } else if (pose == SpritePose.jump) {
      head = point(.52, .25);
      limbs = [
        [point(.51, .34), point(.48, .53), point(.46, .66)],
        [point(.50, .39), point(.40, .28), point(.35, .16)],
        [point(.52, .39), point(.61, .27), point(.66, .15)],
        [point(.46, .64), point(.36, .70), point(.31, .82)],
        [point(.47, .64), point(.59, .69), point(.65, .80)],
      ];
    } else {
      head = point(.50, .23);
      limbs = [
        [point(.50, .32), point(.49, .51), point(.48, .65)],
        [point(.50, .38), point(.38, .43), point(.31, .55)],
        [point(.51, .38), point(.62, .48), point(.70, .39)],
        [point(.48, .63), point(.37, .71), point(.24, .68)],
        [point(.49, .63), point(.62, .70), point(.67, .87)],
      ];
    }

    void drawSkeleton(Paint paint) {
      canvas.drawCircle(head, size.shortestSide * .058, paint);
      for (final limb in limbs) {
        final path = Path()..moveTo(limb.first.dx, limb.first.dy);
        for (var index = 1; index < limb.length; index++) {
          path.lineTo(limb[index].dx, limb[index].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    drawSkeleton(glow);
    drawSkeleton(line);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PoseGuidePainter oldDelegate) =>
      oldDelegate.pose != pose;
}
