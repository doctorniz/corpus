import 'package:drift/drift.dart';

import '../core/db/database.dart';
import '../core/ids.dart';
import 'context.dart';

class SleepRepository extends Repository {
  SleepRepository(super.c);

  /// Newest first.
  Stream<List<SleepSession>> watch({DateTime? since}) {
    final q = db.select(db.sleepSessions)
      ..where((s) => s.profileId.equals(profileId) & s.deletedAt.isNull())
      ..orderBy([(s) => OrderingTerm.desc(s.endedAt)]);
    if (since != null) {
      q.where((s) => s.endedAt.isBiggerOrEqualValue(since.toUtc()));
    }
    return q.watch();
  }

  Future<String> add({
    required DateTime startedAt,
    required DateTime endedAt,
    int? quality,
    String? notes,
    String source = 'manual',
    String? externalId,
  }) async {
    final id = newId();
    await db.transaction(() async {
      await db
          .into(db.sleepSessions)
          .insert(
            SleepSessionsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              startedAt: startedAt.toUtc(),
              endedAt: endedAt.toUtc(),
              quality: Value(quality),
              notes: Value(notes),
              source: Value(source),
              externalId: Value(externalId),
            ),
          );
      await log('sleep_sessions', id, 'insert', {
        'startedAt': startedAt.toUtc().toIso8601String(),
        'endedAt': endedAt.toUtc().toIso8601String(),
        'source': source,
      });
    });
    if (source == 'manual') await c.bridge.pushSleep(startedAt, endedAt);
    return id;
  }

  Future<void> importExternal({
    required String externalId,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final exists = await (db.select(
      db.sleepSessions,
    )..where((s) => s.externalId.equals(externalId))).getSingleOrNull();
    if (exists != null) return;
    await add(
      startedAt: startedAt,
      endedAt: endedAt,
      source: 'health',
      externalId: externalId,
    );
  }

  Future<void> delete(String id) {
    return db.transaction(() async {
      await (db.update(db.sleepSessions)..where((s) => s.id.equals(id))).write(
        SleepSessionsCompanion(deletedAt: Value(now)),
      );
      await log('sleep_sessions', id, 'delete');
    });
  }
}
