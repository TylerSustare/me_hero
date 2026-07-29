import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'; // for Isolate.run / compute
import 'package:image/image.dart' as img;
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class SpriteProcessor {
  /// Slices the raw camera capture down to a perfect center square so the user
  /// doesn't have to manually erase massive blocks of empty ceiling/floor.
  static Future<String> cropToCenterSquare(String imagePath) async {
    try {
      final rawBytes = await File(imagePath).readAsBytes();

      final croppedBytes = await Isolate.run(() {
        img.Image? decoded = img.decodeImage(rawBytes);
        if (decoded == null) throw Exception("Failed to decode camera output.");
        decoded = img.bakeOrientation(decoded);

        final int size = decoded.width < decoded.height
            ? decoded.width
            : decoded.height;
        final int x = (decoded.width - size) ~/ 2;
        final int y = (decoded.height - size) ~/ 2;

        img.Image cropped = img.copyCrop(
          decoded,
          x: x,
          y: y,
          width: size,
          height: size,
        );
        return img.encodePng(cropped);
      });

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        join(
          tempDir.path,
          'cropped_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await tempFile.writeAsBytes(croppedBytes);
      return tempFile.path;
    } catch (e, stack) {
      debugPrint("Error cropping image: $e\n$stack");
      rethrow;
    }
  }

  /// Builds a soft person matte with ML Kit, preserving hair, fingers, and
  /// anti-aliased edges for the touch-up screen.
  static Future<String?> segmentImageToPath(String imagePath) async {
    SelfieSegmenter? segmenter;
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      segmenter = SelfieSegmenter(
        mode: SegmenterMode.single,
        // The model-size mask is faster to transfer from native code. We
        // resample it smoothly onto the full-resolution photo below.
        enableRawSizeMask: false,
      );

      final mask = await segmenter.processImage(inputImage);

      if (mask == null) {
        return imagePath;
      }

      final rawBytes = await File(imagePath).readAsBytes();

      final segmentedBytes = await Isolate.run(() {
        return applySegmentationMask(
          rawBytes: rawBytes,
          maskConfidences: mask.confidences,
          maskWidth: mask.width,
          maskHeight: mask.height,
        );
      });

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        join(
          tempDir.path,
          'segmented_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await tempFile.writeAsBytes(segmentedBytes);
      return tempFile.path;
    } catch (e) {
      debugPrint("ML Kit segment failure: $e");
      return imagePath; // gracefully fail down to pure manual
    } finally {
      await segmenter?.close();
    }
  }

  /// Converts ML Kit confidence values into a clean, feathered alpha matte.
  ///
  /// Keeping only the largest connected person candidate removes the floating
  /// background islands that selfie segmentation occasionally produces.
  @visibleForTesting
  static Uint8List applySegmentationMask({
    required Uint8List rawBytes,
    required List<double> maskConfidences,
    required int maskWidth,
    required int maskHeight,
  }) {
    img.Image? decodedImage = img.decodeImage(rawBytes);
    if (decodedImage == null) {
      throw Exception("Failed to decode raw image segment.");
    }
    decodedImage = img.bakeOrientation(decodedImage);
    if (maskConfidences.length != maskWidth * maskHeight) {
      throw ArgumentError('Mask dimensions do not match confidence values.');
    }

    final keep = _largestConnectedRegion(
      maskConfidences,
      maskWidth,
      maskHeight,
      threshold: 0.18,
    );
    final keptPixels = keep.where((value) => value).length;
    if (keptPixels < math.max(1, (keep.length * 0.002).round())) {
      // A blank or implausibly tiny mask is worse than no automation: return
      // the original so the user can still use the manual remove brush.
      return img.encodePng(decodedImage);
    }
    final subjectOnlyImage = img.Image.from(decodedImage);

    for (int y = 0; y < subjectOnlyImage.height; y++) {
      final my = maskHeight == 1
          ? 0.0
          : y * (maskHeight - 1) / math.max(1, subjectOnlyImage.height - 1);
      for (int x = 0; x < subjectOnlyImage.width; x++) {
        final mx = maskWidth == 1
            ? 0.0
            : x * (maskWidth - 1) / math.max(1, subjectOnlyImage.width - 1);
        final confidence = _sampleMask(
          maskConfidences,
          keep,
          maskWidth,
          maskHeight,
          mx,
          my,
        );
        final matte = _smoothStep(0.16, 0.72, confidence);
        final pixel = subjectOnlyImage.getPixel(x, y);
        final alpha = (pixel.a * matte).round().clamp(0, 255);
        subjectOnlyImage.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, alpha);
      }
    }
    return img.encodePng(subjectOnlyImage);
  }

  static List<bool> _largestConnectedRegion(
    List<double> values,
    int width,
    int height, {
    required double threshold,
  }) {
    final visited = List<bool>.filled(values.length, false);
    List<int> largest = const [];
    final queue = <int>[];

    for (var start = 0; start < values.length; start++) {
      if (visited[start] || values[start] < threshold) continue;
      queue
        ..clear()
        ..add(start);
      visited[start] = true;
      final component = <int>[];

      for (var cursor = 0; cursor < queue.length; cursor++) {
        final index = queue[cursor];
        component.add(index);
        final x = index % width;
        final y = index ~/ width;
        final neighbors = <int>[
          if (x > 0) index - 1,
          if (x + 1 < width) index + 1,
          if (y > 0) index - width,
          if (y + 1 < height) index + width,
        ];
        for (final neighbor in neighbors) {
          if (!visited[neighbor] && values[neighbor] >= threshold) {
            visited[neighbor] = true;
            queue.add(neighbor);
          }
        }
      }
      if (component.length > largest.length) largest = component;
    }

    final keep = List<bool>.filled(values.length, false);
    for (final index in largest) {
      keep[index] = true;
    }
    return keep;
  }

  static double _sampleMask(
    List<double> values,
    List<bool> keep,
    int width,
    int height,
    double x,
    double y,
  ) {
    final x0 = x.floor().clamp(0, width - 1);
    final y0 = y.floor().clamp(0, height - 1);
    final x1 = (x0 + 1).clamp(0, width - 1);
    final y1 = (y0 + 1).clamp(0, height - 1);
    final tx = x - x0;
    final ty = y - y0;

    double valueAt(int px, int py) {
      final index = py * width + px;
      return keep[index] ? values[index] : 0;
    }

    final top = valueAt(x0, y0) * (1 - tx) + valueAt(x1, y0) * tx;
    final bottom = valueAt(x0, y1) * (1 - tx) + valueAt(x1, y1) * tx;
    return top * (1 - ty) + bottom * ty;
  }

  static double _smoothStep(double edge0, double edge1, double value) {
    final t = ((value - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Downsamples with area averaging so facial and costume detail survives at
  /// 64×64 and transparent edges remain smooth.
  static Uint8List isolatePixelateOnly(
    Uint8List erasedBytes,
    int targetWidth,
    int targetHeight,
  ) {
    img.Image? decodedImage = img.decodeImage(erasedBytes);
    if (decodedImage == null) {
      throw Exception("Failed to decode erased image.");
    }
    img.Image pixelatedImage = img.copyResize(
      decodedImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );
    return img.encodePng(pixelatedImage);
  }

  /// Stitches multiple processed frames into a sprite sheet and saves it to disk
  static Future<String?> generateHeroSpriteSheet(
    String heroId,
    List<String> erasedImagePaths,
  ) async {
    try {
      if (erasedImagePaths.isEmpty) {
        throw Exception("Provided erased image list is empty.");
      }

      debugPrint("Stitching spritesheet in isolate...");

      // Perform all file reading, pixelating, and stitching in a SINGLE isolate
      // to avoid spawning 6+ isolates sequentially which can deadlock the engine.
      final spriteBytes = await Isolate.run(() async {
        List<Uint8List> processedFrames = [];

        for (int i = 0; i < erasedImagePaths.length; i++) {
          final erasedBytes = await File(erasedImagePaths[i]).readAsBytes();

          img.Image? decodedImage = img.decodeImage(erasedBytes);
          if (decodedImage == null) {
            throw Exception("Failed to decode erased image $i.");
          }

          img.Image pixelatedImage = img.copyResize(
            decodedImage,
            width: 64,
            height: 64,
            interpolation: img.Interpolation.average,
          );

          processedFrames.add(img.encodePng(pixelatedImage));
        }

        List<img.Image> loadedFrames = processedFrames
            .map((b) => img.decodeImage(b)!)
            .toList();

        int frameWidth = loadedFrames.first.width;
        int frameHeight = loadedFrames.first.height;
        int sheetWidth = frameWidth * loadedFrames.length;

        img.Image spriteSheetCanvas = img.Image(
          width: sheetWidth,
          height: frameHeight,
          numChannels: 4,
        );

        for (int i = 0; i < loadedFrames.length; i++) {
          img.compositeImage(
            spriteSheetCanvas,
            loadedFrames[i],
            dstX: i * frameWidth,
            dstY: 0,
          );
        }
        return img.encodePng(spriteSheetCanvas);
      });

      // Save final PNG
      final docsDir = await getApplicationDocumentsDirectory();
      final spriteFile = File(join(docsDir.path, 'hero_$heroId.png'));
      await spriteFile.writeAsBytes(spriteBytes);

      debugPrint("Hero Spritesheet successfully saved to ${spriteFile.path}");
      return spriteFile.path;
    } catch (e, stackTrace) {
      debugPrint("SpriteProcessor ERROR in generateHeroSpriteSheet: $e");
      debugPrint("Stacktrace: $stackTrace");
      rethrow;
    }
  }
}
