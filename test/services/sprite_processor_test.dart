import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:me_hero/services/sprite_processor.dart';

void main() {
  group('SpriteProcessor', () {
    test('segmentation keeps the main subject and removes isolated noise', () {
      final source = img.Image(width: 4, height: 4, numChannels: 4);
      img.fill(source, color: img.ColorRgba8(80, 120, 200, 255));
      final confidence = List<double>.filled(16, 0);

      for (final index in [5, 6, 9, 10]) {
        confidence[index] = 0.95;
      }
      confidence[15] = 1;

      final resultBytes = SpriteProcessor.applySegmentationMask(
        rawBytes: Uint8List.fromList(img.encodePng(source)),
        maskConfidences: confidence,
        maskWidth: 4,
        maskHeight: 4,
      );
      final result = img.decodePng(resultBytes)!;

      expect(result.getPixel(1, 1).a, 255);
      expect(result.getPixel(3, 3).a, 0);
      expect(result.width, source.width);
      expect(result.height, source.height);
    });

    test('segmentation creates a soft edge instead of a hard cutout', () {
      final source = img.Image(width: 3, height: 1, numChannels: 4);
      img.fill(source, color: img.ColorRgba8(255, 255, 255, 255));

      final resultBytes = SpriteProcessor.applySegmentationMask(
        rawBytes: Uint8List.fromList(img.encodePng(source)),
        maskConfidences: [0.95, 0.45, 0.2],
        maskWidth: 3,
        maskHeight: 1,
      );
      final result = img.decodePng(resultBytes)!;

      expect(result.getPixel(0, 0).a, 255);
      expect(result.getPixel(1, 0).a, inExclusiveRange(0, 255));
    });

    test('segmentation falls back safely when no person is detected', () {
      final source = img.Image(width: 4, height: 4, numChannels: 4);
      img.fill(source, color: img.ColorRgba8(20, 40, 60, 255));

      final resultBytes = SpriteProcessor.applySegmentationMask(
        rawBytes: Uint8List.fromList(img.encodePng(source)),
        maskConfidences: List<double>.filled(16, 0.01),
        maskWidth: 4,
        maskHeight: 4,
      );
      final result = img.decodePng(resultBytes)!;

      expect(result.getPixel(2, 2).a, 255);
    });

    test('64px conversion preserves anti-aliased silhouette edges', () {
      final source = img.Image(width: 127, height: 127, numChannels: 4);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          final alpha = x < 65 ? 255 : 0;
          source.setPixelRgba(x, y, 200, 100, 50, alpha);
        }
      }

      final resultBytes = SpriteProcessor.isolatePixelateOnly(
        Uint8List.fromList(img.encodePng(source)),
        8,
        8,
      );
      final result = img.decodePng(resultBytes)!;
      final alphas = result.map((pixel) => pixel.a.toInt());

      expect(alphas.any((alpha) => alpha > 0 && alpha < 255), isTrue);
    });
  });
}
