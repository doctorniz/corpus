import 'package:drift/drift.dart';

import '../core/db/database.dart';
import '../core/ids.dart';
import '../core/units.dart';
import 'context.dart';

class MeasurementsRepository extends Repository {
  MeasurementsRepository(super.c);

  /// Records a measurement and its change-log entry atomically.
  Future<String> add({
    required String type,
    required double value,
    DateTime? measuredAt,
    String? notes,
    bool push = true,
  }) async {
    final at = measuredAt ?? DateTime.now();
    final id = await _insert(type: type, value: value, at: at, notes: notes);
    if (push) await c.bridge.pushMeasurement(type, value, at);
    return id;
  }

  Future<void> addBloodPressure({
    required int systolic,
    required int diastolic,
    DateTime? measuredAt,
  }) async {
    final at = measuredAt ?? DateTime.now();
    await db.transaction(() async {
      await _insert(
        type: MeasurementType.bpSystolic,
        value: systolic.toDouble(),
        at: at,
      );
      await _insert(
        type: MeasurementType.bpDiastolic,
        value: diastolic.toDouble(),
        at: at,
      );
    });
    await c.bridge.pushBloodPressure(systolic, diastolic, at);
  }

  /// Stores a value read from the phone's health store. A record that was
  /// already imported is updated in place, so re-syncing never duplicates.
  Future<void> upsertExternal({
    required String externalId,
    required String type,
    required double value,
    required DateTime at,
  }) async {
    final existing = await (db.select(
      db.measurements,
    )..where((m) => m.externalId.equals(externalId))).getSingleOrNull();
    if (existing != null) {
      if (existing.value == value) return;
      await (db.update(
        db.measurements,
      )..where((m) => m.id.equals(existing.id))).write(
        MeasurementsCompanion(value: Value(value), updatedAt: Value(now)),
      );
      return;
    }
    await _insert(
      type: type,
      value: value,
      at: at,
      source: 'health',
      externalId: externalId,
    );
  }

  Future<String> _insert({
    required String type,
    required double value,
    required DateTime at,
    String? notes,
    String source = 'manual',
    String? externalId,
  }) {
    final id = newId();
    final unit = MeasurementType.kinds[type]?.unit ?? '';
    return db.transaction(() async {
      await db
          .into(db.measurements)
          .insert(
            MeasurementsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              type: type,
              value: value,
              unit: unit,
              measuredAt: at.toUtc(),
              tzOffsetMinutes: at.timeZoneOffset.inMinutes,
              notes: Value(notes),
              source: Value(source),
              externalId: Value(externalId),
            ),
          );
      await log('measurements', id, 'insert', {
        'type': type,
        'value': value,
        'unit': unit,
        'measuredAt': at.toUtc().toIso8601String(),
        'source': source,
      });
      return id;
    });
  }

  Future<void> delete(String id) {
    return db.transaction(() async {
      await (db.update(db.measurements)..where((m) => m.id.equals(id))).write(
        MeasurementsCompanion(deletedAt: Value(now)),
      );
      await log('measurements', id, 'delete');
    });
  }

  SimpleSelectStatement<$MeasurementsTable, Measurement> _live() {
    return db.select(db.measurements)
      ..where((m) => m.profileId.equals(profileId) & m.deletedAt.isNull());
  }

  /// Oldest first, for charts.
  Stream<List<Measurement>> watchType(String type, {DateTime? since}) {
    final q = _live()
      ..where((m) => m.type.equals(type))
      ..orderBy([(m) => OrderingTerm.asc(m.measuredAt)]);
    if (since != null) {
      q.where((m) => m.measuredAt.isBiggerOrEqualValue(since.toUtc()));
    }
    return q.watch();
  }

  /// Newest first across several types, for lists.
  Stream<List<Measurement>> watchRecent(List<String> types, {int limit = 100}) {
    final q = _live()
      ..where((m) => m.type.isIn(types))
      ..orderBy([(m) => OrderingTerm.desc(m.measuredAt)])
      ..limit(limit);
    return q.watch();
  }

  /// The most recent value of each of [types].
  Stream<Map<String, Measurement>> watchLatest(List<String> types) {
    return watchRecent(types, limit: 500).map((rows) {
      final out = <String, Measurement>{};
      for (final r in rows) {
        out.putIfAbsent(r.type, () => r);
      }
      return out;
    });
  }

  /// Sum of [type] over one local calendar day (e.g. water, steps).
  Stream<double> watchDayTotal(String type, DateTime day) {
    final start = dateOnly(day);
    final end = start.add(const Duration(days: 1));
    final q = _live()
      ..where(
        (m) =>
            m.type.equals(type) &
            m.measuredAt.isBiggerOrEqualValue(start.toUtc()) &
            m.measuredAt.isSmallerThanValue(end.toUtc()),
      );
    return q.watch().map((rows) => rows.fold(0.0, (a, r) => a + r.value));
  }
}
