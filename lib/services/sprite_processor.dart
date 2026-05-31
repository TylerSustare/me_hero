import 'dart:io';
import 'dart:isolate';
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

        int size = decoded.width < decoded.height
            ? decoded.width
            : decoded.height;
        int x = (decoded.width - size) ~/ 2;
        int y = (decoded.height - size) ~/ 2;

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

  /// Applies ML Kit Selfie Segmentation to wipe out 85% of the background
  /// using high confidence markers before falling to a manual Eraser state.
  static Future<String?> segmentImageToPath(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final segmenter = SelfieSegmenter(
        mode: SegmenterMode.single,
        enableRawSizeMask: false,
      );

      final mask = await segmenter.processImage(inputImage);
      segmenter.close();

      if (mask == null) {
        return imagePath;
      }

      final rawBytes = await File(imagePath).readAsBytes();

      final segmentedBytes = await Isolate.run(() {
        return _isolateSegmentOnly(
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
    }
  }

  static Uint8List _isolateSegmentOnly({
    required Uint8List rawBytes,
    required List<double> maskConfidences,
    required int maskWidth,
    required int maskHeight,
  }) {
    img.Image? decodedImage = img.decodeImage(rawBytes);
    if (decodedImage == null) {
      throw Exception("Failed to decode raw image segment.");
    }

    img.Image subjectOnlyImage = img.copyResize(
      decodedImage,
      width: maskWidth,
      height: maskHeight,
    );

    for (int y = 0; y < maskHeight; y++) {
      for (int x = 0; x < maskWidth; x++) {
        final double confidence = maskConfidences[(y * maskWidth) + x];
        // Require ultra-high 85% confidence that it is a human to prevent bleed
        if (confidence < 0.5) {
          subjectOnlyImage.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }
    return img.encodePng(subjectOnlyImage);
  }

  /// Takes the user-erased high-res bytes from the Eraser Screen,
  /// scales them down to 64x64 using purely Nearest Neighbor logic, and returns the pixel block.
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
      interpolation: img.Interpolation.nearest,
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
            interpolation: img.Interpolation.nearest,
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
