import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:me_hero/models/hero_character.dart';
import 'package:me_hero/screens/hero_details_screen.dart';

void main() {
  testWidgets('scrolls without overflowing on a short landscape screen', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(874, 410);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final spritePath = File('assets/demo_hero/frames/idle1.png').absolute.path;
    final hero = HeroCharacter(
      id: 'demo',
      name: 'Nova',
      spriteSheetPath: spritePath,
      createdAt: DateTime.utc(2026, 7, 29),
    );

    await tester.pumpWidget(MaterialApp(home: HeroDetailsScreen(hero: hero)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('IDLE ANIMATION'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -300),
    );
    await tester.pump();

    expect(find.text('Raw Spritesheet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
