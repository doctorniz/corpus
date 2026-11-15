import '../core/db/database.dart';
import '../core/ids.dart';

class ProfileRepository {
  ProfileRepository(this._db);

  final AppDatabase _db;

  /// Returns the first active profile, creating a default one on first run.
  /// No account, no sign-up: the app is usable immediately.
  Future<Profile> ensureDefault() async {
    final existing =
        await (_db.select(_db.profiles)
              ..where((p) => p.deletedAt.isNull())
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final profile = Profile(
      id: newId(),
      createdAt: now,
      updatedAt: now,
      displayName: 'Me',
      unitSystem: 'metric',
    );
    await _db.into(_db.profiles).insert(profile);
    return profile;
  }
}
