import 'dart:convert';

import '../core/db/database.dart';
import 'health_bridge.dart';

/// What every repository needs: the database, whose data it is, which
/// device is writing, and where to mirror new entries (the phone's health
/// store, when the user has switched that on).
class DataContext {
  DataContext({
    required this.db,
    required this.profileId,
    required this.deviceId,
  });

  final AppDatabase db;
  final String profileId;
  final String deviceId;

  /// Replaced by the health sync service when sync is enabled.
  HealthBridge bridge = const NoHealthBridge();
}

abstract class Repository {
  Repository(this.c);

  final DataContext c;

  AppDatabase get db => c.db;
  String get profileId => c.profileId;

  DateTime get now => DateTime.now().toUtc();

  /// Appends to the change log. Call inside the same transaction as the
  /// write it describes.
  Future<void> log(
    String entity,
    String entityId,
    String op, [
    Map<String, Object?> payload = const {},
  ]) {
    return db
        .into(db.changeLog)
        .insert(
          ChangeLogCompanion.insert(
            entity: entity,
            entityId: entityId,
            op: op,
            payload: jsonEncode(payload),
            at: now,
            deviceId: c.deviceId,
          ),
        );
  }
}
