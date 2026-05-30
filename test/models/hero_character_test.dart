import 'package:flutter_test/flutter_test.dart';
import 'package:me_hero/models/hero_character.dart';

void main() {
  group('HeroCharacter', () {
    test('toMap and fromMap should correctly serialize and deserialize', () {
      final hero = HeroCharacter(
        id: '123',
        name: 'Super Dude',
        spriteSheetPath: '/some/path/hero_123.png',
        createdAt: DateTime(2025, 1, 1, 10, 0),
      );

      final map = hero.toMap();
      expect(map['id'], '123');
      expect(map['name'], 'Super Dude');
      expect(map['spriteSheetPath'], '/some/path/hero_123.png');

      final newHero = HeroCharacter.fromMap(map);
      expect(newHero.id, hero.id);
      expect(newHero.name, hero.name);
      expect(newHero.spriteSheetPath, hero.spriteSheetPath);
      expect(newHero.createdAt, hero.createdAt);
    });
  });
}
