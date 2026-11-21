import 'package:drift/drift.dart';

import '../core/db/database.dart';
import '../core/ids.dart';
import '../core/units.dart';
import 'context.dart';

class HabitsRepository extends Repository {
  HabitsRepository(super.c);

  Stream<List<Habit>> watchHabits() {
    final q = db.select(db.habits)
      ..where(
        (h) =>
            h.profileId.equals(profileId) &
            h.deletedAt.isNull() &
            h.archived.equals(false),
      )
      ..orderBy([(h) => OrderingTerm.asc(h.createdAt)]);
    return q.watch();
  }

  /// Every log since [since], grouped by habit id then day key.
  Stream<Map<String, Map<String, int>>> watchLogs(DateTime since) {
    final q = db.select(db.habitLogs)
      ..where(
        (l) => l.deletedAt.isNull() & l.day.isBiggerOrEqualValue(dayKey(since)),
      );
    return q.watch().map((rows) {
      final out = <String, Map<String, int>>{};
      for (final r in rows) {
        (out[r.habitId] ??= {})[r.day] = r.value;
      }
      return out;
    });
  }

  Future<String> save({
    String? id,
    required String name,
    required String kind,
    required int target,
    String? unit,
    int daysMask = 127,
  }) {
    final habitId = id ?? newId();
    return db.transaction(() async {
      if (id == null) {
        await db
            .into(db.habits)
            .insert(
              HabitsCompanion.insert(
                id: habitId,
                createdAt: now,
                updatedAt: now,
                profileId: profileId,
                name: name,
                kind: Value(kind),
                target: Value(target),
                unit: Value(unit),
                daysMask: Value(daysMask),
              ),
            );
      } else {
        await (db.update(db.habits)..where((h) => h.id.equals(habitId))).write(
          HabitsCompanion(
            updatedAt: Value(now),
            name: Value(name),
            kind: Value(kind),
            target: Value(target),
            unit: Value(unit),
            daysMask: Value(daysMask),
          ),
        );
      }
      await log('habits', habitId, id == null ? 'insert' : 'update', {
        'name': name,
      });
      return habitId;
    });
  }

  Future<void> delete(String id) {
    return db.transaction(() async {
      await (db.update(db.habits)..where((h) => h.id.equals(id))).write(
        HabitsCompanion(deletedAt: Value(now)),
      );
      await log('habits', id, 'delete');
    });
  }

  /// Sets the value for one day (0 clears it).
  Future<void> setLog(String habitId, DateTime day, int value) {
    final key = dayKey(day);
    return db.transaction(() async {
      final existing =
          await (db.select(db.habitLogs)
                ..where((l) => l.habitId.equals(habitId) & l.day.equals(key)))
              .getSingleOrNull();
      if (existing == null) {
        if (value <= 0) return;
        final id = newId();
        await db
            .into(db.habitLogs)
            .insert(
              HabitLogsCompanion.insert(
                id: id,
                createdAt: now,
                updatedAt: now,
                habitId: habitId,
                day: key,
                value: value,
              ),
            );
        await log('habit_logs', id, 'insert', {'day': key, 'value': value});
      } else {
        await (db.update(
          db.habitLogs,
        )..where((l) => l.id.equals(existing.id))).write(
          HabitLogsCompanion(
            updatedAt: Value(now),
            value: Value(value),
            deletedAt: Value(value <= 0 ? now : null),
          ),
        );
        await log('habit_logs', existing.id, 'update', {
          'day': key,
          'value': value,
        });
      }
    });
  }
}

/// Whether [habit] is scheduled on [day].
bool habitDueOn(Habit habit, DateTime day) =>
    habit.daysMask & (1 << (day.weekday - 1)) != 0;

/// Consecutive scheduled days up to [today] on which the target was met.
/// Today not being done yet does not break the streak.
int habitStreak(Habit habit, Map<String, int> logs, DateTime today) {
  var streak = 0;
  var day = dateOnly(today);
  for (var i = 0; i < 400; i++) {
    if (habitDueOn(habit, day)) {
      final done = (logs[dayKey(day)] ?? 0) >= habit.target;
      if (done) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
