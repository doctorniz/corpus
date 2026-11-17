import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/db/database.dart';
import '../core/ids.dart';
import '../core/units.dart';
import 'context.dart';

const flowLabels = ['None', 'Spotting', 'Light', 'Medium', 'Heavy'];

const cycleSymptoms = [
  'Cramps',
  'Headache',
  'Bloating',
  'Tender breasts',
  'Backache',
  'Fatigue',
  'Acne',
  'Nausea',
  'Mood swings',
  'Low mood',
  'Anxious',
  'Cravings',
];

class CycleRepository extends Repository {
  CycleRepository(super.c);

  Stream<List<CycleDay>> watchAll() {
    final q = db.select(db.cycleDays)
      ..where((d) => d.profileId.equals(profileId) & d.deletedAt.isNull())
      ..orderBy([(d) => OrderingTerm.asc(d.day)]);
    return q.watch();
  }

  /// Sets what was logged for one day, replacing anything already there.
  Future<void> setDay(
    DateTime day, {
    required int flow,
    List<String> symptoms = const [],
    String? notes,
    String source = 'manual',
  }) async {
    final key = dayKey(day);
    final existing =
        await (db.select(db.cycleDays)
              ..where((d) => d.profileId.equals(profileId) & d.day.equals(key)))
            .getSingleOrNull();
    // An import never overwrites what the user entered by hand.
    if (source != 'manual' && existing != null && existing.deletedAt == null) {
      return;
    }
    final empty = flow == 0 && symptoms.isEmpty && (notes ?? '').isEmpty;
    final wasBleeding =
        existing != null && existing.deletedAt == null && existing.flow >= 2;

    await db.transaction(() async {
      if (existing == null) {
        if (empty) return;
        final id = newId();
        await db
            .into(db.cycleDays)
            .insert(
              CycleDaysCompanion.insert(
                id: id,
                createdAt: now,
                updatedAt: now,
                profileId: profileId,
                day: key,
                flow: Value(flow),
                symptoms: Value(jsonEncode(symptoms)),
                notes: Value(notes),
                source: Value(source),
              ),
            );
        await log('cycle_days', id, 'insert', {'day': key, 'flow': flow});
      } else {
        await (db.update(
          db.cycleDays,
        )..where((d) => d.id.equals(existing.id))).write(
          CycleDaysCompanion(
            updatedAt: Value(now),
            deletedAt: Value(empty ? now : null),
            flow: Value(flow),
            symptoms: Value(jsonEncode(symptoms)),
            notes: Value(notes),
          ),
        );
        await log('cycle_days', existing.id, empty ? 'delete' : 'update', {
          'day': key,
          'flow': flow,
        });
      }
    });

    if (source == 'manual' && flow > 0 && !wasBleeding) {
      final yesterday = dayKey(dateOnly(day).subtract(const Duration(days: 1)));
      final prev =
          await (db.select(db.cycleDays)..where(
                (d) =>
                    d.profileId.equals(profileId) &
                    d.day.equals(yesterday) &
                    d.deletedAt.isNull() &
                    d.flow.isBiggerOrEqualValue(2),
              ))
              .getSingleOrNull();
      await c.bridge.pushCycleDay(key, flow, isStart: prev == null);
    }
  }
}

List<String> decodeSymptoms(String json) =>
    (jsonDecode(json) as List).cast<String>();

/// What the logged days say about the cycle: when periods started, how long
/// cycles usually are, and when the next one is expected.
class CycleStats {
  CycleStats._({
    required this.periodStarts,
    required this.averageCycleDays,
    required this.averagePeriodDays,
    required this.nextPeriod,
    required this.cycleDay,
  });

  /// First day of each period, oldest first.
  final List<DateTime> periodStarts;
  final int? averageCycleDays;
  final int? averagePeriodDays;
  final DateTime? nextPeriod;

  /// Day number within the current cycle (1 = first day of the last period).
  final int? cycleDay;

  static const _defaultCycle = 28;
  static const _defaultPeriod = 5;

  /// Days expected to be period days after the last logged one.
  Set<String> predictedDays({int cycles = 3}) {
    final next = nextPeriod;
    if (next == null) return {};
    final length = averageCycleDays ?? _defaultCycle;
    final period = averagePeriodDays ?? _defaultPeriod;
    return {
      for (var c = 0; c < cycles; c++)
        for (var d = 0; d < period; d++)
          dayKey(next.add(Duration(days: c * length + d))),
    };
  }

  /// Estimated fertile window (ovulation ~14 days before the next period).
  Set<String> fertileDays() {
    final next = nextPeriod;
    if (next == null) return {};
    final ovulation = next.subtract(const Duration(days: 14));
    return {
      for (var d = -5; d <= 1; d++) dayKey(ovulation.add(Duration(days: d))),
    };
  }

  /// [days] may be in any order. Spotting (flow 1) does not start a period.
  factory CycleStats.from(List<CycleDay> days, {DateTime? today}) {
    final bleeding =
        days.where((d) => d.flow >= 2).map((d) => parseDayKey(d.day)).toList()
          ..sort();

    // Group consecutive bleeding days (a one-day gap is tolerated).
    final periods = <List<DateTime>>[];
    for (final d in bleeding) {
      if (periods.isNotEmpty && d.difference(periods.last.last).inDays <= 2) {
        periods.last.add(d);
      } else {
        periods.add([d]);
      }
    }
    final starts = [for (final p in periods) p.first];

    int? avgCycle;
    if (starts.length >= 2) {
      final gaps = <int>[
        for (var i = 1; i < starts.length; i++)
          starts[i].difference(starts[i - 1]).inDays,
      ].where((g) => g >= 15 && g <= 60).toList();
      final recent = gaps.length > 6 ? gaps.sublist(gaps.length - 6) : gaps;
      if (recent.isNotEmpty) {
        avgCycle = (recent.reduce((a, b) => a + b) / recent.length).round();
      }
    }

    int? avgPeriod;
    // The latest period may still be in progress, so leave it out if we can.
    final complete = periods.length > 1
        ? periods.sublist(0, periods.length - 1)
        : periods;
    if (complete.isNotEmpty) {
      final lengths = [
        for (final p in complete) p.last.difference(p.first).inDays + 1,
      ];
      avgPeriod = (lengths.reduce((a, b) => a + b) / lengths.length).round();
    }

    final now = dateOnly(today ?? DateTime.now());
    DateTime? next;
    int? cycleDay;
    if (starts.isNotEmpty) {
      final length = avgCycle ?? _defaultCycle;
      next = starts.last.add(Duration(days: length));
      cycleDay = now.difference(starts.last).inDays + 1;
      if (cycleDay < 1) cycleDay = null;
    }

    return CycleStats._(
      periodStarts: starts,
      averageCycleDays: avgCycle,
      averagePeriodDays: avgPeriod,
      nextPeriod: next,
      cycleDay: cycleDay,
    );
  }
}
