import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:me_hero/providers.dart';
import 'package:me_hero/services/hero_repository.dart';
import 'package:me_hero/models/hero_character.dart';
import 'package:mocktail/mocktail.dart';

class MockHeroRepository extends Mock implements HeroRepository {}

void main() {
  group('HeroesProvider', () {
    late MockHeroRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockHeroRepository();
      container = ProviderContainer(
        overrides: [
          heroRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state loads heroes from repository', () async {
      final initialHeroes = [
        HeroCharacter(id: '1', name: 'Test1', spriteSheetPath: 'path1', createdAt: DateTime.now())
      ];
      when(() => mockRepo.getAllHeroes()).thenAnswer((_) async => initialHeroes);

      final futureValue = await container.read(heroesProvider.future);

      expect(futureValue, initialHeroes);
      verify(() => mockRepo.getAllHeroes()).called(1);
    });

    test('addHero saves and re-fetches heroes', () async {
      final initialHeroes = [
        HeroCharacter(id: '1', name: 'Test1', spriteSheetPath: 'path1', createdAt: DateTime.now())
      ];
      final newHero = HeroCharacter(id: '2', name: 'Test2', spriteSheetPath: 'path2', createdAt: DateTime.now());
      
      var isFirstCall = true;
      when(() => mockRepo.getAllHeroes()).thenAnswer((_) async {
        if (isFirstCall) {
          isFirstCall = false;
          return initialHeroes;
        }
        return [...initialHeroes, newHero];
      });
      when(() => mockRepo.saveHero(newHero)).thenAnswer((_) async => {});

      // Wait for initial load
      await container.read(heroesProvider.future);

      // Perform add
      await container.read(heroesProvider.notifier).addHero(newHero);
      
      // Wait for re-fetch
      final updatedList = await container.read(heroesProvider.future);
      
      expect(updatedList.length, 2);
      expect(updatedList[1].id, '2');
      verify(() => mockRepo.saveHero(newHero)).called(1);
      verify(() => mockRepo.getAllHeroes()).called(2);
    });
  });
}
