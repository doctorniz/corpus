import 'dart:io';

import 'package:corpus/app/app.dart';
import 'package:corpus/app/providers.dart';
import 'package:corpus/core/db/database.dart';
import 'package:corpus/data/context.dart';
import 'package:corpus/data/profile_repository.dart';
import 'package:corpus/services/food_seed.dart';
import 'package:drift/native.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets database reads (real async work) finish and the UI catch up.
/// `pumpAndSettle` alone only advances the test's fake clock.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// Boots the real app on an empty in-memory database, phone-sized.
Future<AppDatabase> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final db = AppDatabase(NativeDatabase.memory());
  final profile = (await tester.runAsync(
    () => ProfileRepository(db).ensureDefault(),
  ))!;
  final context = DataContext(
    db: db,
    profileId: profile.id,
    deviceId: 'test-device',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dataContextProvider.overrideWithValue(context)],
      child: const CorpusApp(),
    ),
  );
  await settle(tester);
  addTearDown(() async {
    // Let drift's stream clean-up timers finish before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
  return db;
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await settle(tester);
}

void main() {
  testWidgets('every tab and menu page opens', (tester) async {
    await pumpApp(tester);
    expect(find.text('My record'.toUpperCase()), findsOneWidget);

    await tapKey(tester, 'tab-fitness');
    expect(find.text('No workouts yet'), findsOneWidget);

    await tapKey(tester, 'tab-sleep');
    expect(find.text('No sleep logged'), findsOneWidget);

    await tapKey(tester, 'tab-nutrition');
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('0 ml'), findsOneWidget);

    for (final page in ['Habits', "Women's health", 'Settings']) {
      await tapKey(tester, 'menu');
      await tester.tap(find.text(page));
      await settle(tester);
      expect(find.widgetWithText(AppBar, page), findsOneWidget);
      await tester.pageBack();
      await settle(tester);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('+ logs a weight that shows on the Health tab', (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'capture');
    expect(find.text('Log something'), findsOneWidget);

    await tapKey(tester, 'capture-weight');
    await tester.enterText(find.byKey(const ValueKey('vital-value')), '72.5');
    await tapKey(tester, 'vital-save');

    expect(find.textContaining('72.5'), findsOneWidget);
  });

  testWidgets('a medication appears in the record and the summary', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapKey(tester, 'section-medication');
    await tester.tap(find.text('Add medication'));
    await settle(tester);
    await tester.enterText(
      find.byKey(const ValueKey('record-title')),
      'Ramipril',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('record-save')));
    await tapKey(tester, 'record-save');
    expect(find.text('Ramipril'), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.text('Current medications'), findsOneWidget);
    expect(find.text('Ramipril'), findsOneWidget);
  });

  testWidgets('quick-add food counts towards the day', (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'tab-nutrition');
    await tapKey(tester, 'add-lunch');
    await tapKey(tester, 'food-quick-add');
    await tester.enterText(find.byKey(const ValueKey('quick-name')), 'Soup');
    await tester.enterText(find.byKey(const ValueKey('quick-kcal')), '320');
    await tapKey(tester, 'quick-save');

    expect(find.text('Soup'), findsOneWidget);
    expect(find.textContaining('1680 left of 2000'), findsOneWidget);

    await tapKey(tester, 'water-250');
    expect(find.textContaining('250'), findsWidgets);
  });

  testWidgets('a habit can be created and checked off', (tester) async {
    await pumpApp(tester);
    await tapKey(tester, 'menu');
    await tester.tap(find.text('Habits'));
    await settle(tester);
    await tapKey(tester, 'habit-add');
    await tester.enterText(find.byKey(const ValueKey('habit-name')), 'Stretch');
    await tapKey(tester, 'habit-save');
    expect(find.textContaining('0 of 1'), findsOneWidget);

    await tapKey(tester, 'habit-check-Stretch');
    expect(find.textContaining('1 of 1'), findsOneWidget);
    expect(find.textContaining('1-day streak'), findsOneWidget);
  });

  test('the bundled food list parses', () {
    final foods = parseBundledFoods(File('assets/foods.bin').readAsBytesSync());
    expect(foods.length, greaterThan(7000));
    final banana = foods.firstWhere((f) => f.name.value == 'Bananas, raw');
    expect(banana.kcal.value, 89);
    expect(banana.source.value, 'usda');
  });
}
