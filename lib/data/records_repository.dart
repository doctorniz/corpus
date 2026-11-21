import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../core/db/database.dart';
import '../core/ids.dart';
import 'context.dart';

/// The health booklet: conditions, medications, letters, lab results...
class RecordsRepository extends Repository {
  RecordsRepository(super.c, {required this.filesDir});

  /// Where attachment files are kept (the app's private documents folder).
  final Future<Directory> Function() filesDir;

  SimpleSelectStatement<$HealthRecordsTable, HealthRecord> _live() {
    return db.select(db.healthRecords)
      ..where((r) => r.profileId.equals(profileId) & r.deletedAt.isNull());
  }

  Stream<List<HealthRecord>> watchKind(String kind) {
    final q = _live()
      ..where((r) => r.kind.equals(kind))
      ..orderBy([
        (r) => OrderingTerm(
          expression: r.date,
          mode: OrderingMode.desc,
          nulls: NullsOrder.last,
        ),
        (r) => OrderingTerm.desc(r.createdAt),
      ]);
    return q.watch();
  }

  /// Number of records per kind, for the Health tab's section list.
  Stream<Map<String, int>> watchCounts() {
    return _live().watch().map((rows) {
      final out = <String, int>{};
      for (final r in rows) {
        out[r.kind] = (out[r.kind] ?? 0) + 1;
      }
      return out;
    });
  }

  Stream<HealthRecord?> watch(String id) {
    return (_live()..where((r) => r.id.equals(id))).watchSingleOrNull();
  }

  /// Creates the record when [id] is null, otherwise updates it.
  Future<String> save({
    String? id,
    required String kind,
    required String title,
    DateTime? date,
    DateTime? endDate,
    String? status,
    Map<String, String> details = const {},
    String? notes,
  }) {
    final recordId = id ?? newId();
    final clean = Map.of(details)..removeWhere((_, v) => v.trim().isEmpty);
    return db.transaction(() async {
      if (id == null) {
        await db
            .into(db.healthRecords)
            .insert(
              HealthRecordsCompanion.insert(
                id: recordId,
                createdAt: now,
                updatedAt: now,
                profileId: profileId,
                kind: kind,
                title: title,
                date: Value(date?.toUtc()),
                endDate: Value(endDate?.toUtc()),
                status: Value(status),
                details: Value(jsonEncode(clean)),
                notes: Value(notes),
              ),
            );
      } else {
        await (db.update(
          db.healthRecords,
        )..where((r) => r.id.equals(recordId))).write(
          HealthRecordsCompanion(
            updatedAt: Value(now),
            title: Value(title),
            date: Value(date?.toUtc()),
            endDate: Value(endDate?.toUtc()),
            status: Value(status),
            details: Value(jsonEncode(clean)),
            notes: Value(notes),
          ),
        );
      }
      await log('health_records', recordId, id == null ? 'insert' : 'update', {
        'kind': kind,
        'title': title,
      });
      return recordId;
    });
  }

  Future<void> delete(String id) {
    return db.transaction(() async {
      await (db.update(db.healthRecords)..where((r) => r.id.equals(id))).write(
        HealthRecordsCompanion(deletedAt: Value(now)),
      );
      await log('health_records', id, 'delete');
    });
  }

  // ---- Attachments ----

  Stream<List<Attachment>> watchAttachments(String recordId) {
    final q = db.select(db.attachments)
      ..where((a) => a.recordId.equals(recordId) & a.deletedAt.isNull())
      ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]);
    return q.watch();
  }

  /// Copies [source] into the app's own storage and links it to the record.
  Future<void> attachFile(String recordId, File source, String fileName) async {
    final id = newId();
    final dir = Directory(p.join((await filesDir()).path, 'attachments'));
    await dir.create(recursive: true);
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\- ]'), '_');
    final relative = p.join('attachments', '${id}_$safeName');
    final target = File(p.join((await filesDir()).path, relative));
    await source.copy(target.path);
    final size = await target.length();
    await db.transaction(() async {
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              recordId: recordId,
              fileName: fileName,
              path: relative,
              sizeBytes: size,
            ),
          );
      await log('attachments', id, 'insert', {'fileName': fileName});
    });
  }

  Future<File> attachmentFile(Attachment a) async {
    return File(p.join((await filesDir()).path, a.path));
  }

  Future<void> deleteAttachment(Attachment a) async {
    await db.transaction(() async {
      await (db.update(db.attachments)..where((x) => x.id.equals(a.id))).write(
        AttachmentsCompanion(deletedAt: Value(now)),
      );
      await log('attachments', a.id, 'delete');
    });
    final file = await attachmentFile(a);
    if (await file.exists()) await file.delete();
  }

  // ---- Lab results ----

  SimpleSelectStatement<$LabResultsTable, LabResult> _labs() {
    return db.select(db.labResults)
      ..where((l) => l.profileId.equals(profileId) & l.deletedAt.isNull());
  }

  /// Every lab value, newest first.
  Stream<List<LabResult>> watchLabs() {
    return (_labs()..orderBy([(l) => OrderingTerm.desc(l.takenAt)])).watch();
  }

  /// One test over time, oldest first, for the trend chart.
  Stream<List<LabResult>> watchLabTest(String test) {
    final q = _labs()
      ..where((l) => l.test.equals(test))
      ..orderBy([(l) => OrderingTerm.asc(l.takenAt)]);
    return q.watch();
  }

  Future<String> addLab({
    required String test,
    required double value,
    required String unit,
    double? refLow,
    double? refHigh,
    required DateTime takenAt,
  }) {
    final id = newId();
    return db.transaction(() async {
      await db
          .into(db.labResults)
          .insert(
            LabResultsCompanion.insert(
              id: id,
              createdAt: now,
              updatedAt: now,
              profileId: profileId,
              test: test,
              value: value,
              unit: unit,
              refLow: Value(refLow),
              refHigh: Value(refHigh),
              takenAt: takenAt.toUtc(),
            ),
          );
      await log('lab_results', id, 'insert', {'test': test, 'value': value});
      return id;
    });
  }

  Future<void> deleteLab(String id) {
    return db.transaction(() async {
      await (db.update(db.labResults)..where((l) => l.id.equals(id))).write(
        LabResultsCompanion(deletedAt: Value(now)),
      );
      await log('lab_results', id, 'delete');
    });
  }
}

Map<String, String> decodeDetails(String json) {
  final raw = jsonDecode(json) as Map<String, dynamic>;
  return raw.map((k, v) => MapEntry(k, '$v'));
}
