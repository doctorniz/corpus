import 'package:drift/drift.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Profiles, Measurements, ChangeLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await m.createIndex(
        Index(
          'measurements_type_time',
          'CREATE INDEX measurements_type_time '
              'ON measurements (profile_id, type, measured_at)',
        ),
      );
    },
    // Migrations are forward-only and must never drop user data.
    // Add `from1To2` etc. here as the schema grows.
    onUpgrade: (m, from, to) async {},
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
