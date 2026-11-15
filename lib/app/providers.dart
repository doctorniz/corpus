import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/connection.dart';
import '../core/db/database.dart';
import '../core/ids.dart';
import '../data/measurements_repository.dart';
import '../data/profile_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openCorpusDatabase());
  ref.onDispose(db.close);
  return db;
});

/// Identifies this install in the change log. TODO: persist across launches
/// (needed before sync; see docs/ROADMAP.md Phase 3).
final deviceIdProvider = Provider<String>((ref) => newId());

final profileRepositoryProvider = Provider(
  (ref) => ProfileRepository(ref.watch(databaseProvider)),
);

final measurementsRepositoryProvider = Provider(
  (ref) => MeasurementsRepository(
    ref.watch(databaseProvider),
    deviceId: ref.watch(deviceIdProvider),
  ),
);

final currentProfileProvider = FutureProvider(
  (ref) => ref.watch(profileRepositoryProvider).ensureDefault(),
);
