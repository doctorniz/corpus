import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/db/database.dart';
import '../data/nutrition_repository.dart';
import '../data/settings_repository.dart';

/// Bump when `assets/foods.bin` is regenerated (tool/build_foods.dart)
/// so existing installs reload it.
const bundledFoodsVersion = '1';

const _asset = 'assets/foods.bin';

/// Parses the bundled list. Each row is
/// `[id, name, category, kcal, protein, carbs, fat, fiber, sugar, sodiumMg,
///   servingG, servingLabel]`, nutrients per 100 g.
List<FoodsCompanion> parseBundledFoods(List<int> gzipped) {
  final json = utf8.decode(const GZipDecoder().decodeBytes(gzipped));
  final rows = (jsonDecode(json) as Map<String, dynamic>)['foods'] as List;
  double? num_(Object? v) => (v as num?)?.toDouble();
  return [
    for (final r in rows.cast<List<dynamic>>())
      FoodsCompanion.insert(
        id: 'usda:${r[0]}',
        name: r[1] as String,
        category: Value(r[2] as String?),
        kcal: num_(r[3]) ?? 0,
        protein: num_(r[4]) ?? 0,
        carbs: num_(r[5]) ?? 0,
        fat: num_(r[6]) ?? 0,
        fiber: Value(num_(r[7])),
        sugar: Value(num_(r[8])),
        sodiumMg: Value(num_(r[9])),
        servingG: Value(num_(r[10])),
        servingLabel: Value(r[11] as String?),
        source: 'usda',
      ),
  ];
}

/// Loads the bundled food database into the local store if it is missing
/// or out of date. Safe to call on every launch; never throws.
Future<void> seedBundledFoods(
  NutritionRepository nutrition,
  SettingsRepository settings,
) async {
  try {
    final current = await settings.get(SettingKey.foodsVersion);
    if (current == bundledFoodsVersion &&
        await nutrition.bundledFoodCount() > 0) {
      return;
    }
    final data = await rootBundle.load(_asset);
    final foods = await compute(
      parseBundledFoods,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    await nutrition.replaceBundledFoods(foods);
    await settings.set(SettingKey.foodsVersion, bundledFoodsVersion);
  } catch (e) {
    debugPrint('[foods] Could not load the bundled food list: $e');
  }
}
