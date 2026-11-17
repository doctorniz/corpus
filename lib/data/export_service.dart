import 'dart:convert';

import '../core/db/database.dart';

/// Full, lossless export of the user's data as one JSON document.
/// The bundled food list is left out (it ships with the app); custom foods
/// are included. Attachment files are referenced by path, not embedded.
class ExportService {
  ExportService(this._db);

  final AppDatabase _db;

  static const formatVersion = 1;

  Future<Map<String, Object?>> build() async {
    Future<List<Map<String, Object?>>> rows(
      String table, [
      String? where,
    ]) async {
      final sql = 'SELECT * FROM $table${where == null ? '' : ' WHERE $where'}';
      final result = await _db.customSelect(sql).get();
      return [for (final r in result) r.data];
    }

    return {
      'format': 'corpus-export',
      'version': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'profiles': await rows('profiles'),
      'measurements': await rows('measurements'),
      'healthRecords': await rows('health_records'),
      'attachments': await rows('attachments'),
      'labResults': await rows('lab_results'),
      'workouts': await rows('workouts'),
      'workoutSets': await rows('workout_sets'),
      'sleepSessions': await rows('sleep_sessions'),
      'customFoods': await rows('foods', "source = 'custom'"),
      'mealEntries': await rows('meal_entries'),
      'cycleDays': await rows('cycle_days'),
      'habits': await rows('habits'),
      'habitLogs': await rows('habit_logs'),
      'settings': await rows('settings'),
    };
  }

  Future<String> buildJson() async =>
      const JsonEncoder.withIndent(' ').convert(await build());
}
