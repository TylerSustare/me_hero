import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:me_hero/services/demo_hero_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creates Nova from five bundled frames in gameplay order', () async {
    final temporaryRoot = await Directory.systemTemp.createTemp(
      'me_hero_demo_test_',
    );
    addTearDown(() => temporaryRoot.delete(recursive: true));

    final createdAt = DateTime.utc(2026, 7, 27, 12);
    late List<String> receivedFramePaths;
    final service = DemoHeroService(
      temporaryDirectoryProvider: () async => temporaryRoot,
      clock: () => createdAt,
      spriteSheetGenerator: (heroId, framePaths) async {
        expect(heroId, DemoHeroService.heroId);
        receivedFramePaths = List.of(framePaths);
        for (final framePath in framePaths) {
          final bytes = await File(framePath).readAsBytes();
          final decoded = image.decodePng(bytes);
          expect(decoded, isNotNull);
          expect(decoded!.numChannels, 4);
        }
        return '/documents/hero_demo-hero.png';
      },
    );

    final hero = await service.createDemoHero();

    expect(receivedFramePaths.map((framePath) => framePath.split('/').last), [
      'idle1.png',
      'idle2.png',
      'run1.png',
      'run2.png',
      'jump.png',
    ]);
    expect(hero.id, DemoHeroService.heroId);
    expect(hero.name, 'Nova');
    expect(hero.spriteSheetPath, '/documents/hero_demo-hero.png');
    expect(hero.createdAt, createdAt);
    expect(
      temporaryRoot.listSync(),
      isEmpty,
      reason: 'Temporary source frames should be cleaned up.',
    );
  });
}
