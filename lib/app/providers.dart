import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

import '../core/db/database.dart';
import '../data/context.dart';
import '../data/cycle_repository.dart';
import '../data/export_service.dart';
import '../data/fitness_repository.dart';
import '../data/habits_repository.dart';
import '../data/measurements_repository.dart';
import '../data/nutrition_repository.dart';
import '../data/records_repository.dart';
import '../data/settings_repository.dart';
import '../data/sleep_repository.dart';
import '../services/health_sync.dart';

/// Set in `main()` once the database is open and the profile exists.
final dataContextProvider = Provider<DataContext>(
  (ref) => throw UnimplementedError('dataContextProvider must be overridden'),
);

final databaseProvider = Provider<AppDatabase>(
  (ref) => ref.watch(dataContextProvider).db,
);

final settingsRepoProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
final measurementsProvider = Provider(
  (ref) => MeasurementsRepository(ref.watch(dataContextProvider)),
);
final recordsProvider = Provider(
  (ref) => RecordsRepository(
    ref.watch(dataContextProvider),
    filesDir: getApplicationDocumentsDirectory,
  ),
);
final fitnessProvider = Provider(
  (ref) => FitnessRepository(ref.watch(dataContextProvider)),
);
final sleepProvider = Provider(
  (ref) => SleepRepository(ref.watch(dataContextProvider)),
);
final nutritionProvider = Provider(
  (ref) => NutritionRepository(ref.watch(dataContextProvider)),
);
final cycleProvider = Provider(
  (ref) => CycleRepository(ref.watch(dataContextProvider)),
);
final habitsProvider = Provider(
  (ref) => HabitsRepository(ref.watch(dataContextProvider)),
);
final exportProvider = Provider(
  (ref) => ExportService(ref.watch(databaseProvider)),
);

final healthSyncProvider = Provider(
  (ref) => HealthSyncService(
    context: ref.watch(dataContextProvider),
    settings: ref.watch(settingsRepoProvider),
    measurements: ref.watch(measurementsProvider),
    fitness: ref.watch(fitnessProvider),
    sleep: ref.watch(sleepProvider),
    cycle: ref.watch(cycleProvider),
  ),
);

/// All settings as a live map; read individual values with [settingProvider].
final settingsProvider = StreamProvider<Map<String, String>>(
  (ref) => ref.watch(settingsRepoProvider).watchAll(),
);

final settingProvider = Provider.family<String?, String>(
  (ref, key) => ref.watch(settingsProvider).value?[key],
);

final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(settingProvider(SettingKey.themeMode))) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

/// A numeric setting with a default (targets).
double numSetting(WidgetRef ref, String key, double fallback) =>
    double.tryParse(ref.watch(settingProvider(key)) ?? '') ?? fallback;
