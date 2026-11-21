// Timing budgets from budgets.json, measured against an in-memory database
// holding the full bundled food list. Reported, not enforced: CI machines
// vary too much for a hard limit (see CLAUDE.md, Performance budgets).
import 'dart:convert';
import 'dart:io';

import 'package:corpus/core/db/database.dart';
import 'package:corpus/data/context.dart';
import 'package:corpus/data/nutrition_repository.dart';
import 'package:corpus/data/profile_repository.dart';
import 'package:corpus/services/food_seed.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _timing(String key) {
  final budgets = jsonDecode(File('budgets.json').readAsStringSync()) as Map;
  return (budgets['timing'] as Map)[key] as Map<String, dynamic>;
}

void _report(String key, Duration took) {
  final budget = _timing(key);
  final ms = took.inMicroseconds / 1000;
  final max = budget['max'] as num;
  // ignore: avoid_print
  print(
    '[budgets] ${budget['label']}: ${ms.toStringAsFixed(1)} ms '
    '(budget $max ms)${ms > max ? ' — OVER' : ''}',
  );
  if (budget['enforce'] == true) expect(ms, lessThanOrEqualTo(max));
}

void main() {
  test('food search and logging against the full food list', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final profile = await ProfileRepository(db).ensureDefault();
    final c = DataContext(db: db, profileId: profile.id, deviceId: 'test');
    final nutrition = NutritionRepository(c);
    await nutrition.replaceBundledFoods(
      parseBundledFoods(File('assets/foods.bin').readAsBytesSync()),
    );

    final search = Stopwatch()..start();
    final found = await nutrition.search('banana');
    search.stop();
    expect(found, isNotEmpty);
    _report('firstFoodSearchMs', search.elapsed);

    final log = Stopwatch()..start();
    await nutrition.logFood(
      found.first,
      120,
      slot: 'breakfast',
      at: DateTime.now(),
    );
    log.stop();
    _report('logEntryMs', log.elapsed);
  });
}
