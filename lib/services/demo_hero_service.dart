import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/hero_character.dart';
import 'sprite_processor.dart';

typedef SpriteSheetGenerator =
    Future<String?> Function(String heroId, List<String> framePaths);
typedef DirectoryProvider = Future<Directory> Function();
typedef Clock = DateTime Function();
typedef ImageCacheEvictor = Future<void> Function(String imagePath);

/// Builds the debug hero through the same sprite-sheet pipeline as a
/// camera-created hero, using bundled pose frames instead of photos.
class DemoHeroService {
  DemoHeroService({
    AssetBundle? assetBundle,
    DirectoryProvider? temporaryDirectoryProvider,
    SpriteSheetGenerator? spriteSheetGenerator,
    ImageCacheEvictor? imageCacheEvictor,
    Clock? clock,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory,
       _spriteSheetGenerator =
           spriteSheetGenerator ?? SpriteProcessor.generateHeroSpriteSheet,
       _imageCacheEvictor = imageCacheEvictor ?? _evictFileImage,
       _clock = clock ?? DateTime.now;

  static const heroId = 'demo-hero';
  static const heroName = 'Nova';
  static const frameAssetPaths = [
    'assets/demo_hero/frames/idle1.png',
    'assets/demo_hero/frames/idle2.png',
    'assets/demo_hero/frames/run1.png',
    'assets/demo_hero/frames/run2.png',
    'assets/demo_hero/frames/jump.png',
  ];

  final AssetBundle _assetBundle;
  final DirectoryProvider _temporaryDirectoryProvider;
  final SpriteSheetGenerator _spriteSheetGenerator;
  final ImageCacheEvictor _imageCacheEvictor;
  final Clock _clock;

  static Future<void> _evictFileImage(String imagePath) async {
    await FileImage(File(imagePath)).evict();
  }

  Future<HeroCharacter> createDemoHero() async {
    final createdAt = _clock();
    final temporaryRoot = await _temporaryDirectoryProvider();
    final workingDirectory = Directory(
      path.join(
        temporaryRoot.path,
        'me_hero_demo_${createdAt.microsecondsSinceEpoch}',
      ),
    );
    await workingDirectory.create(recursive: true);

    try {
      final framePaths = <String>[];
      for (final assetPath in frameAssetPaths) {
        final data = await _assetBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        final frameFile = File(
          path.join(workingDirectory.path, path.basename(assetPath)),
        );
        await frameFile.writeAsBytes(bytes, flush: true);
        framePaths.add(frameFile.path);
      }

      final spriteSheetPath = await _spriteSheetGenerator(heroId, framePaths);
      if (spriteSheetPath == null) {
        throw StateError('The demo hero sprite sheet could not be created.');
      }

      // The demo always overwrites the same sprite-sheet path. Evict its old
      // decoded image so recreating Nova immediately displays updated frames.
      await _imageCacheEvictor(spriteSheetPath);

      return HeroCharacter(
        id: heroId,
        name: heroName,
        spriteSheetPath: spriteSheetPath,
        createdAt: createdAt,
      );
    } finally {
      if (await workingDirectory.exists()) {
        await workingDirectory.delete(recursive: true);
      }
    }
  }
}
