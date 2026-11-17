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

/// Generic time-series value: weight, vitals, steps, water...
/// Values are stored in canonical units (see core/units.dart).
class Measurements extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get type => text()();
  RealColumn get value => real()();
  TextColumn get unit => text()();

  /// Stored as UTC; the original offset is kept for display.
  DateTimeColumn get measuredAt => dateTime()();
  IntColumn get tzOffsetMinutes => integer()();

  /// 'manual' or 'health' (imported from Apple Health / Health Connect).
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get notes => text().nullable()();

  /// Id of the record in the phone's health store; used to avoid duplicates.
  TextColumn get externalId => text().nullable()();
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

/// Key/value app settings (device id, targets, sync state...).
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// One entry in the health booklet. `kind` selects the form and section
/// (see features/health/record_kinds.dart); kind-specific fields live in
/// `details` as JSON so new kinds need no schema change.
class HealthRecords extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  DateTimeColumn get date => dateTime().nullable()();
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get status => text().nullable()();
  TextColumn get details => text().withDefault(const Constant('{}'))();
  TextColumn get notes => text().nullable()();
}

/// A file (scan, PDF, photo) attached to a health record. The file itself
/// is copied into the app's private documents folder; `path` is relative.
class Attachments extends Table with RecordColumns {
  TextColumn get recordId => text().references(HealthRecords, #id)();
  TextColumn get fileName => text()();
  TextColumn get path => text()();
  IntColumn get sizeBytes => integer()();
}

/// A single numeric lab value, kept separately so it can be charted.
class LabResults extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get recordId => text().nullable().references(HealthRecords, #id)();
  TextColumn get test => text()();
  RealColumn get value => real()();
  TextColumn get unit => text()();
  RealColumn get refLow => real().nullable()();
  RealColumn get refHigh => real().nullable()();
  DateTimeColumn get takenAt => dateTime()();
}

class Workouts extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();

  /// See core/activities.dart.
  TextColumn get activity => text()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  RealColumn get distanceM => real().nullable()();
  RealColumn get energyKcal => real().nullable()();
  IntColumn get avgHr => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get externalId => text().nullable()();
}

class WorkoutSets extends Table with RecordColumns {
  TextColumn get workoutId => text().references(Workouts, #id)();
  TextColumn get exercise => text()();
  IntColumn get position => integer()();
  IntColumn get reps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
}

class SleepSessions extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();

  /// 1 (poor) – 5 (great), optional.
  IntColumn get quality => integer().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get externalId => text().nullable()();
}

/// Nutrients are per 100 g. `source` is 'usda' (bundled) or 'custom'.
class Foods extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get category => text().nullable()();
  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
  RealColumn get fiber => real().nullable()();
  RealColumn get sugar => real().nullable()();
  RealColumn get sodiumMg => real().nullable()();
  RealColumn get servingG => real().nullable()();
  TextColumn get servingLabel => text().nullable()();
  TextColumn get source => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One logged food. Nutrient totals are copied in at log time so history
/// stays correct even if the food is later edited.
@DataClassName('MealEntry')
class MealEntries extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  DateTimeColumn get eatenAt => dateTime()();

  /// Local calendar day, 'yyyy-MM-dd'.
  TextColumn get day => text()();

  /// 'breakfast' | 'lunch' | 'dinner' | 'snack'
  TextColumn get slot => text()();
  TextColumn get foodId => text().nullable()();
  TextColumn get name => text()();
  RealColumn get grams => real().nullable()();
  RealColumn get kcal => real()();
  RealColumn get protein => real()();
  RealColumn get carbs => real()();
  RealColumn get fat => real()();
}

/// One day of cycle tracking. `flow`: 0 none, 1 spotting, 2 light,
/// 3 medium, 4 heavy. `symptoms` is a JSON list of strings.
class CycleDays extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get day => text()();
  IntColumn get flow => integer().withDefault(const Constant(0))();
  TextColumn get symptoms => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {profileId, day},
  ];
}

class Habits extends Table with RecordColumns {
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text()();

  /// 'bool' (done / not done) or 'count' (e.g. 8 glasses).
  TextColumn get kind => text().withDefault(const Constant('bool'))();
  IntColumn get target => integer().withDefault(const Constant(1))();
  TextColumn get unit => text().nullable()();

  /// Bit 0 = Monday … bit 6 = Sunday. 127 = every day.
  IntColumn get daysMask => integer().withDefault(const Constant(127))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

class HabitLogs extends Table with RecordColumns {
  TextColumn get habitId => text().references(Habits, #id)();
  TextColumn get day => text()();
  IntColumn get value => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {habitId, day},
  ];
}
