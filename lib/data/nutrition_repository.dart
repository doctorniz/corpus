import 'package:drift/drift.dart';

import '../core/db/database.dart';
import '../core/ids.dart';
import '../core/units.dart';
import 'context.dart';

const mealSlots = ['breakfast', 'lunch', 'dinner', 'snack'];

String slotLabel(String slot) => switch (slot) {
  'breakfast' => 'Breakfast',
  'lunch' => 'Lunch',
  'dinner' => 'Dinner',
  _ => 'Snacks',
};

/// The meal slot a time of day most likely belongs to.
String slotForTime(DateTime t) {
  final h = t.hour;
  if (h < 11) return 'breakfast';
  if (h < 15) return 'lunch';
  if (h >= 17 && h < 22) return 'dinner';
  return 'snack';
}

class NutritionRepository extends Repository {
  NutritionRepository(super.c);

  // ---- Foods ----

  Future<int> bundledFoodCount() async {
    final count = db.foods.id.count();
    final q = db.selectOnly(db.foods)
      ..addColumns([count])
      ..where(db.foods.source.equals('usda'));
    return (await q.getSingle()).read(count) ?? 0;
  }

  /// Replaces the bundled food list. Custom foods are left alone.
  Future<void> replaceBundledFoods(List<FoodsCompanion> foods) {
    return db.transaction(() async {
      await (db.delete(db.foods)..where((f) => f.source.equals('usda'))).go();
      await db.batch((b) => b.insertAll(db.foods, foods));
    });
  }

  /// Foods whose name contains every word of [query]. Custom foods first,
  /// then shorter (more generic) names.
  Future<List<Food>> search(String query, {int limit = 60}) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final q = db.select(db.foods)..where((f) => f.deletedAt.isNull());
    for (final w in words) {
      q.where((f) => f.name.lower().like('%$w%'));
    }
    q
      ..orderBy([
        (f) => OrderingTerm.desc(f.source.equals('custom')),
        if (words.isNotEmpty)
          (f) => OrderingTerm.desc(f.name.lower().like('${words.first}%')),
        (f) => OrderingTerm.asc(f.name.length),
      ])
      ..limit(limit);
    return q.get();
  }

  /// Foods logged most recently, without repeats.
  Future<List<Food>> recentFoods({int limit = 20}) async {
    final entries =
        await (db.select(db.mealEntries)
              ..where(
                (e) =>
                    e.profileId.equals(profileId) &
                    e.deletedAt.isNull() &
                    e.foodId.isNotNull(),
              )
              ..orderBy([(e) => OrderingTerm.desc(e.eatenAt)])
              ..limit(200))
            .get();
    final ids = <String>[];
    for (final e in entries) {
      if (!ids.contains(e.foodId)) ids.add(e.foodId!);
      if (ids.length == limit) break;
    }
    if (ids.isEmpty) return [];
    final foods = await (db.select(
      db.foods,
    )..where((f) => f.id.isIn(ids) & f.deletedAt.isNull())).get();
    final byId = {for (final f in foods) f.id: f};
    return [for (final id in ids) ?byId[id]];
  }

  Future<Food> addCustomFood({
    required String name,
    required double kcal,
    required double protein,
    required double carbs,
    required double fat,
    double? servingG,
    String? servingLabel,
  }) async {
    final food = Food(
      id: newId(),
      name: name,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
      servingG: servingG,
      servingLabel: servingLabel,
      source: 'custom',
    );
    await db.transaction(() async {
      await db.into(db.foods).insert(food);
      await log('foods', food.id, 'insert', {'name': name});
    });
    return food;
  }

  // ---- Diary ----

  Stream<List<MealEntry>> watchDay(DateTime day) {
    final q = db.select(db.mealEntries)
      ..where(
        (e) =>
            e.profileId.equals(profileId) &
            e.deletedAt.isNull() &
            e.day.equals(dayKey(day)),
      )
      ..orderBy([(e) => OrderingTerm.asc(e.eatenAt)]);
    return q.watch();
  }

  /// Total kcal per day since [since], keyed by 'yyyy-MM-dd'.
  Stream<Map<String, double>> watchDailyKcal(DateTime since) {
    final q = db.select(db.mealEntries)
      ..where(
        (e) =>
            e.profileId.equals(profileId) &
            e.deletedAt.isNull() &
            e.day.isBiggerOrEqualValue(dayKey(since)),
      );
    return q.watch().map((rows) {
      final out = <String, double>{};
      for (final r in rows) {
        out[r.day] = (out[r.day] ?? 0) + r.kcal;
      }
      return out;
    });
  }

  /// Logs [grams] of [food].
  Future<void> logFood(
    Food food,
    double grams, {
    required String slot,
    required DateTime at,
  }) {
    final f = grams / 100;
    return logEntry(
      name: food.name,
      slot: slot,
      at: at,
      foodId: food.id,
      grams: grams,
      kcal: food.kcal * f,
      protein: food.protein * f,
      carbs: food.carbs * f,
      fat: food.fat * f,
    );
  }

  /// Logs a meal with nutrients typed in directly.
  Future<void> logEntry({
    required String name,
    required String slot,
    required DateTime at,
    String? foodId,
    double? grams,
    required double kcal,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) async {
    final id = newId();
    final entry = MealEntry(
      id: id,
      createdAt: now,
      updatedAt: now,
      profileId: profileId,
      eatenAt: at.toUtc(),
      day: dayKey(at),
      slot: slot,
      foodId: foodId,
      name: name,
      grams: grams,
      kcal: kcal,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    await db.transaction(() async {
      await db.into(db.mealEntries).insert(entry);
      await log('meal_entries', id, 'insert', {
        'name': name,
        'slot': slot,
        'kcal': kcal,
        'day': entry.day,
      });
    });
    await c.bridge.pushMeal(entry);
  }

  Future<void> deleteEntry(String id) {
    return db.transaction(() async {
      await (db.update(db.mealEntries)..where((e) => e.id.equals(id))).write(
        MealEntriesCompanion(deletedAt: Value(now)),
      );
      await log('meal_entries', id, 'delete');
    });
  }
}
