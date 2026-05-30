```dart
import 'package:image/image.dart' as img;
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'dart:typed_data';
import 'dart:io';

/// A utility class to process high-resolution camera images into
/// pixelated sprite sheets using ML Kit Selfie Segmentation.
class SpriteProcessor {
  
  /// Applies ML Kit Selfie Segmentation to isolate the subject, 
  /// makes the background transparent, and pixelates the remaining subject
  /// through nearest neighbor downscaling.
  static Future<img.Image?> processAndPixelateFrame({
    required String imagePath,
    int targetWidth = 64,  // Default pixel art dimensions
    int targetHeight = 64,
  }) async {
    // 1. Run ML Kit Selfie Segmentation
    final inputImage = InputImage.fromFilePath(imagePath);
    final segmenter = SelfieSegmenter(
      mode: SegmenterMode.single,
      enableRawSizeMask: false, 
    );
    
    final mask = await segmenter.processImage(inputImage);
    segmenter.close();
    
    if (mask == null) return null;

    // 2. Load the original image via the `image` package
    final rawBytes = await File(imagePath).readAsBytes();
    img.Image? decodedImage = img.decodeImage(rawBytes);
    if (decodedImage == null) return null;

    // 3. Apply the segmentation mask to the image 
    // The mask contains confidence values (0.0 to 1.0) for each pixel being the subject.
    // If confidence < 0.5, we clear the pixel (Alpha = 0).
    final int width = mask.width;
    final int height = mask.height;
    
    // ML Kit mask might not perfectly match decodedImage dimensions depending on orientation,
    // ensure we resize decodedImage or mask to match if necessary. 
    // Assuming identical dimensions for simplicity in this utility.
    img.Image subjectOnlyImage = img.copyResize(decodedImage, width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final double confidence = mask.confidences[(y * width) + x];
        if (confidence < 0.5) {
          // Set pixel to completely transparent
          subjectOnlyImage.setPixelRgba(x, y, 0, 0, 0, 0);
        }
      }
    }

    // 4. Downscale the image to achieve the "retro" look.
    // Nearest neighbor interpolation gives the hard, blocky edges required for pixel art.
    img.Image pixelatedImage = img.copyResize(
      subjectOnlyImage,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.nearest,
    );

    return pixelatedImage;
  }

  /// Stitches a list of processed frames horizontally into a single sprite sheet.
  static Uint8List? buildSpriteSheet(List<img.Image> frames) {
    if (frames.isEmpty) return null;

    int frameWidth = frames.first.width;
    int frameHeight = frames.first.height;
    int sheetWidth = frameWidth * frames.length;

    // Create the blank canvas strictly requiring numChannels: 4 for transparency
    img.Image spriteSheetCanvas = img.Image(
      width: sheetWidth,
      height: frameHeight,
      numChannels: 4,
    );

    for (int i = 0; i < frames.length; i++) {
      int destX = i * frameWidth;
      img.compositeImage(
        spriteSheetCanvas,
        frames[i],
        dstX: destX,
        dstY: 0,
      );
    }

    // Encode final assembled sprite sheet to PNG byte array
    return img.encodePng(spriteSheetCanvas);
  }
}
```
