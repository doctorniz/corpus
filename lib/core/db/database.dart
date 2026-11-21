import 'package:drift/drift.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Profiles,
    Measurements,
    ChangeLog,
    Settings,
    HealthRecords,
    Attachments,
    LabResults,
    Workouts,
    WorkoutSets,
    SleepSessions,
    Foods,
    MealEntries,
    CycleDays,
    Habits,
    HabitLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createIndexes();
    },
    // Migrations are forward-only and must never drop user data.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(measurements, measurements.externalId);
        // Creates every table added since v1 (existing ones are skipped).
        await m.createAll();
        await _createIndexes();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS measurements_type_time '
          'ON measurements (profile_id, type, measured_at)',
      'CREATE UNIQUE INDEX IF NOT EXISTS measurements_external '
          'ON measurements (external_id) WHERE external_id IS NOT NULL',
      'CREATE UNIQUE INDEX IF NOT EXISTS workouts_external '
          'ON workouts (external_id) WHERE external_id IS NOT NULL',
      'CREATE UNIQUE INDEX IF NOT EXISTS sleep_external '
          'ON sleep_sessions (external_id) WHERE external_id IS NOT NULL',
      'CREATE INDEX IF NOT EXISTS health_records_kind '
          'ON health_records (profile_id, kind, date)',
      'CREATE INDEX IF NOT EXISTS lab_results_test '
          'ON lab_results (profile_id, test, taken_at)',
      'CREATE INDEX IF NOT EXISTS workouts_time '
          'ON workouts (profile_id, started_at)',
      'CREATE INDEX IF NOT EXISTS sleep_time '
          'ON sleep_sessions (profile_id, ended_at)',
      'CREATE INDEX IF NOT EXISTS meal_entries_day '
          'ON meal_entries (profile_id, day)',
      'CREATE INDEX IF NOT EXISTS foods_name ON foods (name)',
    ];
    for (final s in statements) {
      await customStatement(s);
    }
  }
}
