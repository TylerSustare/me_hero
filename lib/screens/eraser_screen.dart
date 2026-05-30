import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class EraserScreen extends StatefulWidget {
  final String imagePath;
  final String poseName;

  const EraserScreen({super.key, required this.imagePath, required this.poseName});

  @override
  State<EraserScreen> createState() => _EraserScreenState();
}

class EraserStroke {
  final Path path;
  final double width;
  bool isDot = false;
  Offset? dotCenter;

  EraserStroke({required this.path, required this.width});
}

class _EraserScreenState extends State<EraserScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final List<EraserStroke> _strokes = [];
  double _strokeWidth = 30.0;
  bool _isSaving = false;
  ui.Image? _uiImage;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await File(widget.imagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _uiImage = frame.image;
        });
      }
    } catch (e) {
      debugPrint("Failed to load ui.Image for Eraser: $e");
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      final path = Path()..moveTo(details.localPosition.dx, details.localPosition.dy);
      _strokes.add(EraserStroke(path: path, width: _strokeWidth)..isDot = true..dotCenter = details.localPosition);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (_strokes.isNotEmpty) {
        _strokes.last.isDot = false;
        _strokes.last.path.lineTo(details.localPosition.dx, details.localPosition.dy);
      }
    });
  }
  
  void _onTapDown(TapDownDetails details) {
    setState(() {
      final path = Path()..moveTo(details.localPosition.dx, details.localPosition.dy);
      _strokes.add(EraserStroke(path: path, width: _strokeWidth)..isDot = true..dotCenter = details.localPosition);
    });
  }

  Future<void> _saveWipedImage() async {
    setState(() => _isSaving = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // We capture the view preserving its transparency
      final img = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final erasedFile = File(p.join(tempDir.path, 'erased_${DateTime.now().millisecondsSinceEpoch}.png'));
      await erasedFile.writeAsBytes(pngBytes);
      
      if (!mounted) return;
      Navigator.pop(context, erasedFile.path); // Return the final erased path
    } catch (e) {
      debugPrint("Error saving erased image: $e");
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save erased image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark background to easily see transparency
      appBar: AppBar(
        title: Text("Erase Background - ${widget.poseName}"),
        backgroundColor: Colors.deepPurple,
        actions: [
          _isSaving 
            ? const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: CircularProgressIndicator(color: Colors.white)))
            : IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveWipedImage,
                tooltip: 'Confirm and Pixelate',
              )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const Icon(Icons.brush, color: Colors.white),
                Expanded(
                  child: Slider(
                    value: _strokeWidth,
                    min: 10,
                    max: 80,
                    activeColor: Colors.deepPurpleAccent,
                    onChanged: (val) => setState(() => _strokeWidth = val),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.undo, color: Colors.white),
                  onPressed: _strokes.isEmpty ? null : () {
                    setState(() => _strokes.removeLast());
                  },
                )
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Wipe away any remaining background noise with your finger.",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: InteractiveViewer(
              panEnabled: false, // Must be disabled so we can draw instead of panning the viewport
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 1.0,
              maxScale: 4.0,
              child: Center(
                child: _uiImage == null 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : AspectRatio(
                      aspectRatio: _uiImage!.width / _uiImage!.height, 
                      child: RepaintBoundary(
                        key: _repaintKey,
                        // The core canvas
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: _onPanStart,
                          onPanUpdate: _onPanUpdate,
                          onTapDown: _onTapDown,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _EraserPainter(_uiImage!, _strokes, _strokeWidth),
                          ),
                        ),
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EraserPainter extends CustomPainter {
  final ui.Image image;
  final List<EraserStroke> strokes;
  final double strokeWidth;

  _EraserPainter(this.image, this.strokes, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Create an isolated layer so BlendMode.clear correctly punches a transparent hole 
    // down to the void, rather than just clearing to a black background.
    canvas.saveLayer(Offset.zero & size, Paint());
    
    // 2. Pain the base segmented image perfectly flush
    paintImage(
      canvas: canvas,
      image: image,
      rect: Offset.zero & size,
      fit: BoxFit.fill, 
    );
    
    // 3. Draw the user strokes with transparency
    final paint = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    for (var stroke in strokes) {
      paint.strokeWidth = stroke.width;
      canvas.drawPath(stroke.path, paint);
      
      if (stroke.isDot && stroke.dotCenter != null) {
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(stroke.dotCenter!, stroke.width / 6, paint);
        paint.style = PaintingStyle.stroke; // restore
      }
    }
    
    // 4. Flatten the transparent layer out
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EraserPainter oldDelegate) {
    return true; 
  }
}
