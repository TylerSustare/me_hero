import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum TouchUpTool { erase, restore }

class EraserScreen extends StatefulWidget {
  const EraserScreen({
    super.key,
    required this.imagePath,
    required this.poseName,
    this.sourceImagePath,
  });

  final String imagePath;
  final String poseName;
  final String? sourceImagePath;

  @override
  State<EraserScreen> createState() => _EraserScreenState();
}

class EraserStroke {
  EraserStroke({
    required this.path,
    required this.width,
    required this.tool,
    this.dotCenter,
  });

  final Path path;
  final double width;
  final TouchUpTool tool;
  Offset? dotCenter;
}

class _EraserScreenState extends State<EraserScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<EraserStroke> _strokes = [];
  final List<EraserStroke> _redoStrokes = [];

  double _strokeWidth = 34;
  bool _isSaving = false;
  bool _showOriginal = false;
  TouchUpTool _tool = TouchUpTool.erase;
  ui.Image? _cutoutImage;
  ui.Image? _sourceImage;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void dispose() {
    _cutoutImage?.dispose();
    _sourceImage?.dispose();
    super.dispose();
  }

  Future<ui.Image> _decodeImage(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _loadImages() async {
    try {
      final images = await Future.wait([
        _decodeImage(widget.imagePath),
        _decodeImage(widget.sourceImagePath ?? widget.imagePath),
      ]);
      if (!mounted) {
        for (final image in images) {
          image.dispose();
        }
        return;
      }
      setState(() {
        _cutoutImage = images[0];
        _sourceImage = images[1];
      });
    } catch (error) {
      debugPrint('Failed to load touch-up images: $error');
      if (mounted) {
        setState(
          () =>
              _loadError = 'This photo could not be opened. Please retake it.',
        );
      }
    }
  }

  void _startStroke(Offset position, {bool dot = false}) {
    setState(() {
      _redoStrokes.clear();
      _strokes.add(
        EraserStroke(
          path: Path()..moveTo(position.dx, position.dy),
          width: _strokeWidth,
          tool: _tool,
          dotCenter: dot ? position : null,
        ),
      );
    });
  }

  void _onPanStart(DragStartDetails details) =>
      _startStroke(details.localPosition);

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (_strokes.isNotEmpty) {
        _strokes.last.path.lineTo(
          details.localPosition.dx,
          details.localPosition.dy,
        );
      }
    });
  }

  void _onTapUp(TapUpDetails details) =>
      _startStroke(details.localPosition, dot: true);

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _redoStrokes.add(_strokes.removeLast()));
  }

  void _redo() {
    if (_redoStrokes.isEmpty) return;
    setState(() => _strokes.add(_redoStrokes.removeLast()));
  }

  Future<void> _saveWipedImage() async {
    final renderObject = _repaintKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || _cutoutImage == null) return;

    setState(() {
      _isSaving = true;
      _showOriginal = false;
    });
    await WidgetsBinding.instance.endOfFrame;

    try {
      final pixelRatio = (_cutoutImage!.width / renderObject.size.width)
          .clamp(1.0, 4.0)
          .toDouble();
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Could not encode the touch-up.');

      final tempDir = await getTemporaryDirectory();
      final erasedFile = File(
        p.join(
          tempDir.path,
          'hero_cutout_${DateTime.now().microsecondsSinceEpoch}.png',
        ),
      );
      await erasedFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

      if (mounted) Navigator.pop(context, erasedFile.path);
    } catch (error) {
      debugPrint('Error saving touched-up image: $error');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('We couldn’t save that edit. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090A10),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090A10),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Polish the cutout',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              widget.poseName,
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cutoutImage == null || _isSaving
                ? null
                : _saveWipedImage,
            child: _isSaving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Use photo',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _loadError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }
    if (_cutoutImage == null || _sourceImage == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF8B7CFF)),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _tool == TouchUpTool.erase
                      ? 'Brush over anything that isn’t you.'
                      : 'Brush over details the auto cutout missed.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTapDown: (_) => setState(() => _showOriginal = true),
                onTapUp: (_) => setState(() => _showOriginal = false),
                onTapCancel: () => setState(() => _showOriginal = false),
                child: const Chip(
                  avatar: Icon(Icons.visibility_outlined, size: 18),
                  label: Text('Hold to compare'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: AspectRatio(
                aspectRatio: _cutoutImage!.width / _cutoutImage!.height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const CustomPaint(painter: _CheckerboardPainter()),
                      RepaintBoundary(
                        key: _repaintKey,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _showOriginal ? null : _onPanStart,
                          onPanUpdate: _showOriginal ? null : _onPanUpdate,
                          onTapUp: _showOriginal ? null : _onTapUp,
                          child: CustomPaint(
                            painter: _TouchUpPainter(
                              cutout: _cutoutImage!,
                              source: _sourceImage!,
                              strokes: List<EraserStroke>.unmodifiable(
                                _strokes,
                              ),
                              showOriginal: _showOriginal,
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: const BoxDecoration(
            color: Color(0xFF141520),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<TouchUpTool>(
                  segments: const [
                    ButtonSegment(
                      value: TouchUpTool.erase,
                      icon: Icon(Icons.auto_fix_off_outlined),
                      label: Text('Remove'),
                    ),
                    ButtonSegment(
                      value: TouchUpTool.restore,
                      icon: Icon(Icons.add_circle_outline),
                      label: Text('Bring back'),
                    ),
                  ],
                  selected: {_tool},
                  onSelectionChanged: (selection) =>
                      setState(() => _tool = selection.first),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 10, color: Colors.white54),
                    Expanded(
                      child: Slider(
                        value: _strokeWidth,
                        min: 12,
                        max: 84,
                        divisions: 12,
                        label: _strokeWidth.round().toString(),
                        onChanged: (value) =>
                            setState(() => _strokeWidth = value),
                      ),
                    ),
                    const Icon(Icons.circle, size: 24, color: Colors.white54),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _strokes.isEmpty ? null : _undo,
                      icon: const Icon(Icons.undo),
                      tooltip: 'Undo',
                    ),
                    IconButton(
                      onPressed: _redoStrokes.isEmpty ? null : _redo,
                      icon: const Icon(Icons.redo),
                      tooltip: 'Redo',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TouchUpPainter extends CustomPainter {
  const _TouchUpPainter({
    required this.cutout,
    required this.source,
    required this.strokes,
    required this.showOriginal,
  });

  final ui.Image cutout;
  final ui.Image source;
  final List<EraserStroke> strokes;
  final bool showOriginal;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    paintImage(
      canvas: canvas,
      image: showOriginal ? source : cutout,
      rect: bounds,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.high,
    );

    if (!showOriginal) {
      final sourceShader = ui.ImageShader(
        source,
        TileMode.clamp,
        TileMode.clamp,
        Float64List.fromList([
          size.width / source.width,
          0,
          0,
          0,
          0,
          size.height / source.height,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ]),
        filterQuality: FilterQuality.high,
      );

      for (final stroke in strokes) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = stroke.width
          ..blendMode = stroke.tool == TouchUpTool.erase
              ? BlendMode.clear
              : BlendMode.srcOver;
        if (stroke.tool == TouchUpTool.restore) paint.shader = sourceShader;

        canvas.drawPath(stroke.path, paint);
        if (stroke.dotCenter != null) {
          paint.style = PaintingStyle.fill;
          canvas.drawCircle(stroke.dotCenter!, stroke.width / 2, paint);
        }
      }
      sourceShader.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TouchUpPainter oldDelegate) =>
      oldDelegate.cutout != cutout ||
      oldDelegate.source != source ||
      oldDelegate.strokes != strokes ||
      oldDelegate.strokes.length != strokes.length ||
      oldDelegate.showOriginal != showOriginal;
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const square = 18.0;
    final light = Paint()..color = const Color(0xFF30313A);
    final dark = Paint()..color = const Color(0xFF22232B);
    for (var y = 0.0; y < size.height; y += square) {
      for (var x = 0.0; x < size.width; x += square) {
        final alternate = ((x / square).floor() + (y / square).floor()).isEven;
        canvas.drawRect(
          Rect.fromLTWH(x, y, square, square),
          alternate ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
