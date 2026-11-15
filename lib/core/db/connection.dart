import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Single place where the on-disk database is opened.
///
/// Encryption seam (ADR 0004): when SQLCipher is introduced, only this
/// function changes — e.g. by applying `PRAGMA key` in `setup` and
/// swapping the native library. Nothing above the repository layer
/// should know whether the store is encrypted.
QueryExecutor openCorpusDatabase() {
  return driftDatabase(
    name: 'corpus',
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );
}
