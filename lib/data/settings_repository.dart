import '../core/db/database.dart';
import '../core/ids.dart';

abstract final class SettingKey {
  static const deviceId = 'device_id';
  static const themeMode = 'theme_mode';
  static const healthSync = 'health_sync_enabled';
  static const healthLastSync = 'health_last_sync';
  static const foodsVersion = 'foods_version';
  static const kcalTarget = 'target_kcal';
  static const proteinTarget = 'target_protein';
  static const carbsTarget = 'target_carbs';
  static const fatTarget = 'target_fat';
  static const waterTarget = 'target_water_ml';
  static const sleepTarget = 'target_sleep_h';
  static const showWomens = 'show_womens';
}

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) {
    return _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(key: key, value: value),
        );
  }

  Stream<Map<String, String>> watchAll() {
    return _db
        .select(_db.settings)
        .watch()
        .map((rows) => {for (final r in rows) r.key: r.value});
  }

  /// A stable id for this install, created on first launch.
  Future<String> deviceId() async {
    final existing = await get(SettingKey.deviceId);
    if (existing != null) return existing;
    final id = newId();
    await set(SettingKey.deviceId, id);
    return id;
  }
}
