import 'package:corpus/core/db/database.dart';
import 'package:corpus/core/units.dart';
import 'package:corpus/data/measurements_repository.dart';
import 'package:corpus/data/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('default profile is created once', () async {
    final repo = ProfileRepository(db);
    final a = await repo.ensureDefault();
    final b = await repo.ensureDefault();
    expect(a.id, b.id);
  });

  test('adding a measurement writes a change-log entry', () async {
    final profile = await ProfileRepository(db).ensureDefault();
    final repo = MeasurementsRepository(db, deviceId: 'test-device');

    final id = await repo.add(
      profileId: profile.id,
      type: MeasurementType.weight,
      value: 72.5,
      unit: CanonicalUnit.mass,
    );

    final recent = await repo.watchRecent(profile.id).first;
    expect(recent.single.id, id);
    expect(recent.single.value, 72.5);

    final log = await db.select(db.changeLog).get();
    expect(log.single.entityId, id);
    expect(log.single.op, 'insert');
    expect(log.single.deviceId, 'test-device');
  });

  test('kg/lb conversion round-trips', () {
    expect(lbToKg(kgToLb(80)), closeTo(80, 1e-9));
  });

  test('schema version is 1', () {
    expect(db.schemaVersion, 1);
    expect(db.allTables.map((t) => t.actualTableName), [
      'profiles',
      'measurements',
      'change_log',
    ]);
  });
}
