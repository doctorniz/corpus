import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/db/connection.dart';
import 'core/db/database.dart';
import 'data/context.dart';
import 'data/nutrition_repository.dart';
import 'data/profile_repository.dart';
import 'data/settings_repository.dart';
import 'services/food_seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase(openCorpusDatabase());
  final profile = await ProfileRepository(db).ensureDefault();
  final settings = SettingsRepository(db);
  final context = DataContext(
    db: db,
    profileId: profile.id,
    deviceId: await settings.deviceId(),
  );

  // Loads the bundled food list on first launch (and after an app update
  // that ships a newer list). Runs in the background; search simply has
  // fewer results until it finishes.
  seedBundledFoods(NutritionRepository(context), settings);

  runApp(
    ProviderScope(
      overrides: [dataContextProvider.overrideWithValue(context)],
      child: const CorpusApp(),
    ),
  );
}
