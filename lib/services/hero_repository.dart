import '../models/hero_character.dart';

/// Abstract repository for saving and retrieving Hero characters.
abstract class HeroRepository {
  Future<void> saveHero(HeroCharacter hero);
  Future<List<HeroCharacter>> getAllHeroes();
  Future<void> deleteHero(String id);
}
