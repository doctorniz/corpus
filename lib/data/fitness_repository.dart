import 'package:drift/drift.dart';

import '../core/db/database.dart';
import '../core/ids.dart';
import 'context.dart';

/// One set in a strength workout, before it is saved.
class SetDraft {
  SetDraft({required this.exercise, this.reps, this.weightKg});
  String exercise;
  int? reps;
  double? weightKg;
}

class FitnessRepository extends Repository {
  FitnessRepository(super.c);

  SimpleSelectStatement<$WorkoutsTable, Workout> _live() {
    return db.select(db.workouts)
      ..where((w) => w.profileId.equals(profileId) & w.deletedAt.isNull());
  }

  /// Newest first.
  Stream<List<Workout>> watchWorkouts({DateTime? since, int? limit}) {
    final q = _live()..orderBy([(w) => OrderingTerm.desc(w.startedAt)]);
    if (since != null) {
      q.where((w) => w.startedAt.isBiggerOrEqualValue(since.toUtc()));
    }
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Stream<Workout?> watchWorkout(String id) {
    return (_live()..where((w) => w.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<WorkoutSet>> watchSets(String workoutId) {
    final q = db.select(db.workoutSets)
      ..where((s) => s.workoutId.equals(workoutId) & s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.asc(s.position)]);
    return q.watch();
  }

  /// Best (heaviest) set per day for one exercise, oldest first.
  Future<List<({DateTime day, double weightKg})>> exerciseHistory(
    String exercise,
  ) async {
    final q =
        db.select(db.workoutSets).join([
            innerJoin(
              db.workouts,
              db.workouts.id.equalsExp(db.workoutSets.workoutId),
            ),
          ])
          ..where(
            db.workoutSets.exercise.equals(exercise) &
                db.workoutSets.deletedAt.isNull() &
                db.workouts.deletedAt.isNull() &
                db.workoutSets.weightKg.isNotNull(),
          )
          ..orderBy([OrderingTerm.asc(db.workouts.startedAt)]);
    final best = <DateTime, double>{};
    for (final row in await q.get()) {
      final w = row.readTable(db.workouts).startedAt.toLocal();
      final day = DateTime(w.year, w.month, w.day);
      final kg = row.readTable(db.workoutSets).weightKg!;
      if (kg > (best[day] ?? 0)) best[day] = kg;
    }
    return [for (final e in best.entries) (day: e.key, weightKg: e.value)];
  }

  /// Names of exercises the user has logged, most recent first.
  Future<List<String>> loggedExercises() async {
    final q = db.selectOnly(db.workoutSets, distinct: true)
      ..addColumns([db.workoutSets.exercise])
      ..where(db.workoutSets.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(db.workoutSets.createdAt)]);
    final seen = <String>{};
    for (final r in await q.get()) {
      seen.add(r.read(db.workoutSets.exercise)!);
    }
    return seen.toList();
  }

  Future<String> addWorkout({
    required String activity,
    String? title,
    required DateTime startedAt,
    required DateTime endedAt,
    double? distanceM,
    double? energyKcal,
    int? avgHr,
    String? notes,
    List<SetDraft> sets = const [],
    String source = 'manual',
    String? externalId,
  }) async {
    final id = newId();
    await db.transaction(() async {
      await db
          .into(db.workouts)
          .insert(
            WorkoutsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              activity: activity,
              title: Value(title),
              startedAt: startedAt.toUtc(),
              endedAt: endedAt.toUtc(),
              distanceM: Value(distanceM),
              energyKcal: Value(energyKcal),
              avgHr: Value(avgHr),
              notes: Value(notes),
              source: Value(source),
              externalId: Value(externalId),
            ),
          );
      var position = 0;
      for (final s in sets) {
        if (s.exercise.trim().isEmpty) continue;
        await db
            .into(db.workoutSets)
            .insert(
              WorkoutSetsCompanion.insert(
                id: newId(),
                createdAt: now,
                updatedAt: now,
                workoutId: id,
                exercise: s.exercise.trim(),
                position: position++,
                reps: Value(s.reps),
                weightKg: Value(s.weightKg),
              ),
            );
      }
      await log('workouts', id, 'insert', {
        'activity': activity,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'sets': position,
        'source': source,
      });
    });
    if (source == 'manual') {
      final saved = await (db.select(
        db.workouts,
      )..where((w) => w.id.equals(id))).getSingle();
      await c.bridge.pushWorkout(saved);
    }
    return id;
  }

  /// Imports a workout from the phone's health store once.
  Future<void> importExternal({
    required String externalId,
    required String activity,
    required DateTime startedAt,
    required DateTime endedAt,
    double? distanceM,
    double? energyKcal,
  }) async {
    final exists = await (db.select(
      db.workouts,
    )..where((w) => w.externalId.equals(externalId))).getSingleOrNull();
    if (exists != null) return;
    await addWorkout(
      activity: activity,
      startedAt: startedAt,
      endedAt: endedAt,
      distanceM: distanceM,
      energyKcal: energyKcal,
      source: 'health',
      externalId: externalId,
    );
  }

  Future<void> delete(String id) {
    return db.transaction(() async {
      await (db.update(db.workouts)..where((w) => w.id.equals(id))).write(
        WorkoutsCompanion(deletedAt: Value(now)),
      );
      await log('workouts', id, 'delete');
    });
  }
}
