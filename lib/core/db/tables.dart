import 'package:drift/drift.dart';

/// Columns shared by every user-data table (see docs/DATA_MODEL.md).
mixin RecordColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Soft delete: rows are never physically removed by the app.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Profiles extends Table with RecordColumns {
  TextColumn get displayName => text()();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get sex => text().nullable()();

  /// 'metric' or 'imperial' — display preference only; storage is always SI.
  TextColumn get unitSystem => text().withDefault(const Constant('metric'))();
}

/// Generic time-series value: weight, vitals, steps, sleep, measurements...
/// Values are stored in canonical SI units (see core/units.dart).
class Measurements extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get type => text()();
  RealColumn get value => real()();
  TextColumn get unit => text()();

  /// Stored as UTC; the original offset is kept for display.
  DateTimeColumn get measuredAt => dateTime()();
  IntColumn get tzOffsetMinutes => integer()();

  /// 'manual', 'import:<source>', ...
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get notes => text().nullable()();
}

/// Append-only log of every mutation. Powers history, undo, and later sync.
class ChangeLog extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();

  /// 'insert' | 'update' | 'delete'
  TextColumn get op => text()();

  /// JSON of the changed fields.
  TextColumn get payload => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get deviceId => text()();
}
