import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:me_hero/screens/heroes_list_page.dart';
import 'package:me_hero/providers.dart';
import 'package:me_hero/models/hero_character.dart';
import 'package:me_hero/services/hero_repository.dart';

class MockHeroRepository extends Mock implements HeroRepository {}

void main() {
  late MockHeroRepository mockRepo;

  setUp(() {
    mockRepo = MockHeroRepository();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        heroRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: const MaterialApp(
        home: HeroesListPage(),
      ),
    );
  }

  testWidgets('shows loading state initially', (WidgetTester tester) async {
    // Delay the repository response indefinitely for the test
    when(() => mockRepo.getAllHeroes()).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 1));
      return [];
    });

    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Clear the pending timer
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('shows empty state message when no heroes provided', (WidgetTester tester) async {
    when(() => mockRepo.getAllHeroes()).thenAnswer((_) async => []);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.textContaining('No heroes yet'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('displays list of heroes', (WidgetTester tester) async {
    final heroes = [
      HeroCharacter(id: '1', name: 'Alpha Hero', spriteSheetPath: 'path1', createdAt: DateTime.now()),
      HeroCharacter(id: '2', name: 'Beta Hero', spriteSheetPath: 'path2', createdAt: DateTime.now()),
    ];
    when(() => mockRepo.getAllHeroes()).thenAnswer((_) async => heroes);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Alpha Hero'), findsOneWidget);
    expect(find.text('Beta Hero'), findsOneWidget);
  });
}
