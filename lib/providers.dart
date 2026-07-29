import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/hero_repository.dart';
import 'services/sqlite_hero_repository.dart';
import 'services/demo_hero_service.dart';
import 'models/hero_character.dart';

// Provider for the repository
final heroRepositoryProvider = Provider<HeroRepository>((ref) {
  return SqliteHeroRepository(); // Later can be swapped with Firebase
});

final demoHeroServiceProvider = Provider<DemoHeroService>((ref) {
  return DemoHeroService();
});

// AsyncNotifier provider for the list of heroes
final heroesProvider =
    AsyncNotifierProvider<HeroesNotifier, List<HeroCharacter>>(() {
      return HeroesNotifier();
    });

class HeroesNotifier extends AsyncNotifier<List<HeroCharacter>> {
  @override
  Future<List<HeroCharacter>> build() async {
    return _fetchHeroes();
  }

  Future<List<HeroCharacter>> _fetchHeroes() async {
    final repo = ref.read(heroRepositoryProvider);
    return repo.getAllHeroes();
  }

  Future<void> addHero(HeroCharacter hero) async {
    final repo = ref.read(heroRepositoryProvider);
    await repo.saveHero(hero);
    // Invalidate to refresh the list
    ref.invalidateSelf();
  }

  Future<void> deleteHero(String id) async {
    final repo = ref.read(heroRepositoryProvider);
    await repo.deleteHero(id);
    ref.invalidateSelf();
  }
}
