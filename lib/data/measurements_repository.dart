import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/db/database.dart';
import '../core/ids.dart';

class MeasurementsRepository {
  MeasurementsRepository(this._db, {required this.deviceId});

  final AppDatabase _db;
  final String deviceId;

  /// Records a measurement and its change-log entry atomically.
  Future<String> add({
    required String profileId,
    required String type,
    required double value,
    required String unit,
    DateTime? measuredAt,
    String? notes,
  }) {
    final id = newId();
    final now = DateTime.now();
    final at = measuredAt ?? now;

    return _db.transaction(() async {
      await _db
          .into(_db.measurements)
          .insert(
            MeasurementsCompanion.insert(
              id: id,
              createdAt: now.toUtc(),
              updatedAt: now.toUtc(),
              profileId: profileId,
              type: type,
              value: value,
              unit: unit,
              measuredAt: at.toUtc(),
              tzOffsetMinutes: at.timeZoneOffset.inMinutes,
              notes: Value(notes),
            ),
          );
      await _db
          .into(_db.changeLog)
          .insert(
            ChangeLogCompanion.insert(
              entity: 'measurements',
              entityId: id,
              op: 'insert',
              payload: jsonEncode({
                'type': type,
                'value': value,
                'unit': unit,
                'measuredAt': at.toUtc().toIso8601String(),
              }),
              at: now.toUtc(),
              deviceId: deviceId,
            ),
          );
      return id;
    });
  }

  Stream<List<Measurement>> watchRecent(String profileId, {int limit = 50}) {
    final q = _db.select(_db.measurements)
      ..where((m) => m.profileId.equals(profileId) & m.deletedAt.isNull())
      ..orderBy([(m) => OrderingTerm.desc(m.measuredAt)])
      ..limit(limit);
    return q.watch();
  }
}
