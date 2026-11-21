import 'dart:convert';
import 'dart:io';

import 'package:corpus/core/db/database.dart';
import 'package:corpus/core/units.dart';
import 'package:corpus/data/context.dart';
import 'package:corpus/data/cycle_repository.dart';
import 'package:corpus/data/export_service.dart';
import 'package:corpus/data/fitness_repository.dart';
import 'package:corpus/data/habits_repository.dart';
import 'package:corpus/data/health_bridge.dart';
import 'package:corpus/data/measurements_repository.dart';
import 'package:corpus/data/nutrition_repository.dart';
import 'package:corpus/data/profile_repository.dart';
import 'package:corpus/data/records_repository.dart';
import 'package:corpus/data/settings_repository.dart';
import 'package:corpus/data/sleep_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingBridge implements HealthBridge {
  final calls = <String>[];

  @override
  Future<void> pushMeasurement(String type, double value, DateTime at) async =>
      calls.add('measurement:$type:$value');
  @override
  Future<void> pushBloodPressure(int s, int d, DateTime at) async =>
      calls.add('bp:$s/$d');
  @override
  Future<void> pushWorkout(Workout workout) async =>
      calls.add('workout:${workout.activity}');
  @override
  Future<void> pushSleep(DateTime start, DateTime end) async =>
      calls.add('sleep');
  @override
  Future<void> pushMeal(MealEntry entry) async =>
      calls.add('meal:${entry.name}');
  @override
  Future<void> pushCycleDay(
    String day,
    int flow, {
    required bool isStart,
  }) async => calls.add('cycle:$day:$flow:$isStart');
}

void main() {
  late AppDatabase db;
  late DataContext c;
  late RecordingBridge bridge;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final profile = await ProfileRepository(db).ensureDefault();
    bridge = RecordingBridge();
    c = DataContext(db: db, profileId: profile.id, deviceId: 'test-device')
      ..bridge = bridge;
  });
  tearDown(() => db.close());

  test('default profile is created once', () async {
    final repo = ProfileRepository(db);
    expect((await repo.ensureDefault()).id, c.profileId);
  });

  test('device id is stable', () async {
    final settings = SettingsRepository(db);
    expect(await settings.deviceId(), await settings.deviceId());
  });

  group('measurements', () {
    test('add writes a change-log entry and mirrors to health', () async {
      final repo = MeasurementsRepository(c);
      final id = await repo.add(type: MeasurementType.weight, value: 72.5);

      final rows = await repo.watchType(MeasurementType.weight).first;
      expect(rows.single.id, id);
      expect(rows.single.unit, 'kg');

      final log = await db.select(db.changeLog).get();
      expect(log.single.entityId, id);
      expect(log.single.deviceId, 'test-device');
      expect(bridge.calls, ['measurement:weight:72.5']);
    });

    test('blood pressure is stored as a pair', () async {
      final repo = MeasurementsRepository(c);
      await repo.addBloodPressure(systolic: 120, diastolic: 80);
      final latest = await repo.watchLatest([
        MeasurementType.bpSystolic,
        MeasurementType.bpDiastolic,
      ]).first;
      expect(latest[MeasurementType.bpSystolic]!.value, 120);
      expect(latest[MeasurementType.bpDiastolic]!.value, 80);
      expect(bridge.calls, ['bp:120/80']);
    });

    test('imported values are not duplicated or pushed back', () async {
      final repo = MeasurementsRepository(c);
      final at = DateTime(2026, 11, 1, 12);
      for (final steps in [4000.0, 9000.0]) {
        await repo.upsertExternal(
          externalId: 'steps:2026-11-01',
          type: MeasurementType.steps,
          value: steps,
          at: at,
        );
      }
      final rows = await repo.watchType(MeasurementType.steps).first;
      expect(rows.single.value, 9000);
      expect(rows.single.source, 'health');
      expect(bridge.calls, isEmpty);
    });

    test('day total and delete', () async {
      final repo = MeasurementsRepository(c);
      final today = DateTime.now();
      final a = await repo.add(type: MeasurementType.water, value: 250);
      await repo.add(type: MeasurementType.water, value: 500);
      expect(await repo.watchDayTotal(MeasurementType.water, today).first, 750);
      await repo.delete(a);
      expect(await repo.watchDayTotal(MeasurementType.water, today).first, 500);
    });
  });

  group('health booklet', () {
    late Directory tmp;
    late RecordsRepository repo;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('corpus_test');
      repo = RecordsRepository(c, filesDir: () async => tmp);
    });
    tearDown(() => tmp.delete(recursive: true));

    test('save, edit, count and delete records', () async {
      final id = await repo.save(
        kind: 'medication',
        title: 'Ramipril',
        details: {'dose': '5 mg', 'frequency': '', 'prescriber': 'Dr A'},
      );
      await repo.save(kind: 'allergy', title: 'Penicillin');
      expect(await repo.watchCounts().first, {'medication': 1, 'allergy': 1});

      final saved = (await repo.watch(id).first)!;
      expect(decodeDetails(saved.details), {
        'dose': '5 mg',
        'prescriber': 'Dr A',
      });

      await repo.save(id: id, kind: 'medication', title: 'Ramipril 10');
      expect(
        (await repo.watchKind('medication').first).single.title,
        'Ramipril 10',
      );

      await repo.delete(id);
      expect(await repo.watchKind('medication').first, isEmpty);
    });

    test('attachments are copied into app storage', () async {
      final id = await repo.save(kind: 'letter', title: 'Cardiology letter');
      final source = File('${tmp.path}/in.pdf')..writeAsStringSync('hello');
      await repo.attachFile(id, source, 'clinic letter?.pdf');

      final a = (await repo.watchAttachments(id).first).single;
      expect(a.fileName, 'clinic letter?.pdf');
      expect(a.sizeBytes, 5);
      final stored = await repo.attachmentFile(a);
      expect(stored.readAsStringSync(), 'hello');

      await repo.deleteAttachment(a);
      expect(await repo.watchAttachments(id).first, isEmpty);
      expect(stored.existsSync(), isFalse);
    });

    test('lab results chart oldest first', () async {
      await repo.addLab(
        test: 'HbA1c',
        value: 44,
        unit: 'mmol/mol',
        refHigh: 42,
        takenAt: DateTime(2026, 6, 1),
      );
      await repo.addLab(
        test: 'HbA1c',
        value: 40,
        unit: 'mmol/mol',
        takenAt: DateTime(2026, 1, 1),
      );
      final series = await repo.watchLabTest('HbA1c').first;
      expect(series.map((l) => l.value), [40, 44]);
    });
  });

  group('fitness', () {
    test('strength workout keeps its sets in order', () async {
      final repo = FitnessRepository(c);
      final start = DateTime(2026, 11, 10, 18);
      final id = await repo.addWorkout(
        activity: 'strength',
        startedAt: start,
        endedAt: start.add(const Duration(hours: 1)),
        sets: [
          SetDraft(exercise: 'Back squat', reps: 5, weightKg: 100),
          SetDraft(exercise: '  '),
          SetDraft(exercise: 'Back squat', reps: 5, weightKg: 105),
        ],
      );
      final sets = await repo.watchSets(id).first;
      expect(sets.map((s) => s.weightKg), [100, 105]);
      expect(bridge.calls, ['workout:strength']);

      final history = await repo.exerciseHistory('Back squat');
      expect(history.single.weightKg, 105);
      expect(await repo.loggedExercises(), ['Back squat']);
    });

    test('imported workouts are stored once and not pushed back', () async {
      final repo = FitnessRepository(c);
      final start = DateTime(2026, 11, 10, 7);
      for (var i = 0; i < 2; i++) {
        await repo.importExternal(
          externalId: 'abc',
          activity: 'run',
          startedAt: start,
          endedAt: start.add(const Duration(minutes: 30)),
          distanceM: 5000,
        );
      }
      expect((await repo.watchWorkouts().first).single.distanceM, 5000);
      expect(bridge.calls, isEmpty);
    });
  });

  test('sleep sessions: add, import once, delete', () async {
    final repo = SleepRepository(c);
    final end = DateTime(2026, 11, 10, 7);
    final id = await repo.add(
      startedAt: end.subtract(const Duration(hours: 8)),
      endedAt: end,
      quality: 4,
    );
    for (var i = 0; i < 2; i++) {
      await repo.importExternal(
        externalId: 'night-2',
        startedAt: end.add(const Duration(hours: 16)),
        endedAt: end.add(const Duration(hours: 24)),
      );
    }
    expect(await repo.watch().first, hasLength(2));
    expect(bridge.calls, ['sleep']);
    await repo.delete(id);
    expect((await repo.watch().first).single.source, 'health');
  });

  group('nutrition', () {
    test('search ranks custom foods and prefix matches first', () async {
      final repo = NutritionRepository(c);
      await repo.replaceBundledFoods([
        for (final n in [
          'Bread, banana, prepared from recipe',
          'Bananas, raw',
          'Apples, raw',
        ])
          FoodsCompanion.insert(
            id: 'usda:$n',
            name: n,
            kcal: 89,
            protein: 1,
            carbs: 23,
            fat: 0.3,
            source: 'usda',
          ),
      ]);
      await repo.addCustomFood(
        name: 'My banana shake',
        kcal: 120,
        protein: 8,
        carbs: 15,
        fat: 3,
      );
      expect(await repo.bundledFoodCount(), 3);

      final hits = await repo.search('banana');
      expect(hits.map((f) => f.name), [
        'My banana shake',
        'Bananas, raw',
        'Bread, banana, prepared from recipe',
      ]);
      expect(await repo.search('raw banana'), hasLength(1));
    });

    test('logging scales nutrients by weight', () async {
      final repo = NutritionRepository(c);
      final food = await repo.addCustomFood(
        name: 'Oats',
        kcal: 380,
        protein: 13,
        carbs: 60,
        fat: 7,
      );
      final at = DateTime(2026, 11, 10, 8);
      await repo.logFood(food, 50, slot: 'breakfast', at: at);
      await repo.logEntry(name: 'Coffee', slot: 'breakfast', at: at, kcal: 10);

      final day = await repo.watchDay(at).first;
      expect(day.first.kcal, 190);
      expect(day.first.protein, 6.5);
      expect(await repo.watchDailyKcal(at).first, {'2026-11-10': 200});
      expect((await repo.recentFoods()).single.name, 'Oats');
      expect(bridge.calls, ['meal:Oats', 'meal:Coffee']);

      await repo.deleteEntry(day.first.id);
      expect(await repo.watchDay(at).first, hasLength(1));
    });

    test('slot follows the time of day', () {
      expect(slotForTime(DateTime(2026, 1, 1, 8)), 'breakfast');
      expect(slotForTime(DateTime(2026, 1, 1, 13)), 'lunch');
      expect(slotForTime(DateTime(2026, 1, 1, 19)), 'dinner');
      expect(slotForTime(DateTime(2026, 1, 1, 23)), 'snack');
    });
  });

  group('cycle', () {
    test('set, clear and re-log a day', () async {
      final repo = CycleRepository(c);
      final day = DateTime(2026, 11, 3);
      await repo.setDay(day, flow: 3, symptoms: ['Cramps']);
      expect(decodeSymptoms((await repo.watchAll().first).single.symptoms), [
        'Cramps',
      ]);
      await repo.setDay(day, flow: 0);
      expect(await repo.watchAll().first, isEmpty);
      await repo.setDay(day, flow: 2);
      expect((await repo.watchAll().first).single.flow, 2);
      expect(bridge.calls, [
        'cycle:2026-11-03:3:true',
        'cycle:2026-11-03:2:true',
      ]);
    });

    test('stats: cycle length, period length, prediction', () async {
      final repo = CycleRepository(c);
      for (final start in [
        DateTime(2026, 8, 1),
        DateTime(2026, 8, 31),
        DateTime(2026, 9, 30),
      ]) {
        for (var d = 0; d < 4; d++) {
          await repo.setDay(start.add(Duration(days: d)), flow: 3);
        }
      }
      // Spotting mid-cycle is not a period.
      await repo.setDay(DateTime(2026, 9, 15), flow: 1);

      final stats = CycleStats.from(
        await repo.watchAll().first,
        today: DateTime(2026, 10, 9),
      );
      expect(stats.periodStarts, hasLength(3));
      expect(stats.averageCycleDays, 30);
      expect(stats.averagePeriodDays, 4);
      expect(stats.nextPeriod, DateTime(2026, 10, 30));
      expect(stats.cycleDay, 10);
      expect(stats.predictedDays(cycles: 1), {
        '2026-10-30',
        '2026-10-31',
        '2026-11-01',
        '2026-11-02',
      });
      expect(stats.fertileDays(), contains('2026-10-16'));
    });

    test('a first period still in progress has no average yet', () async {
      final repo = CycleRepository(c);
      await repo.setDay(DateTime(2026, 11, 17), flow: 3);
      final days = await repo.watchAll().first;
      expect(
        CycleStats.from(days, today: DateTime(2026, 11, 17)).averagePeriodDays,
        isNull,
      );
      expect(
        CycleStats.from(days, today: DateTime(2026, 11, 25)).averagePeriodDays,
        1,
      );
    });

    test('no data gives no prediction', () {
      final stats = CycleStats.from(const []);
      expect(stats.nextPeriod, isNull);
      expect(stats.predictedDays(), isEmpty);
    });
  });

  group('habits', () {
    test('logs, streaks and schedule', () async {
      final repo = HabitsRepository(c);
      final id = await repo.save(name: 'Stretch', kind: 'bool', target: 1);
      final habit = (await repo.watchHabits().first).single;
      final today = DateTime(2026, 11, 12); // Thursday

      for (var back = 1; back <= 3; back++) {
        await repo.setLog(id, today.subtract(Duration(days: back)), 1);
      }
      var logs = (await repo.watchLogs(DateTime(2026, 11, 1)).first)[id]!;
      expect(habitStreak(habit, logs, today), 3);

      await repo.setLog(id, today, 1);
      logs = (await repo.watchLogs(DateTime(2026, 11, 1)).first)[id]!;
      expect(habitStreak(habit, logs, today), 4);

      await repo.setLog(id, today.subtract(const Duration(days: 2)), 0);
      logs = (await repo.watchLogs(DateTime(2026, 11, 1)).first)[id]!;
      expect(habitStreak(habit, logs, today), 2);
    });

    test('unscheduled days do not break a streak', () async {
      final repo = HabitsRepository(c);
      // Monday, Wednesday, Friday.
      final id = await repo.save(
        name: 'Gym',
        kind: 'bool',
        target: 1,
        daysMask: 1 | 4 | 16,
      );
      final habit = (await repo.watchHabits().first).single;
      final friday = DateTime(2026, 11, 13);
      expect(habitDueOn(habit, friday), isTrue);
      expect(habitDueOn(habit, DateTime(2026, 11, 12)), isFalse);

      await repo.setLog(id, DateTime(2026, 11, 9), 1);
      await repo.setLog(id, DateTime(2026, 11, 11), 1);
      await repo.setLog(id, friday, 1);
      final logs = (await repo.watchLogs(DateTime(2026, 11, 1)).first)[id]!;
      expect(habitStreak(habit, logs, friday), 3);
    });
  });

  test('export contains user data but not the bundled foods', () async {
    await MeasurementsRepository(c)
        .add(type: MeasurementType.weight, value: 70);
    final nutrition = NutritionRepository(c);
    await nutrition.replaceBundledFoods([
      FoodsCompanion.insert(
        id: 'usda:1',
        name: 'Apples, raw',
        kcal: 52,
        protein: 0.3,
        carbs: 14,
        fat: 0.2,
        source: 'usda',
      ),
    ]);
    await nutrition.addCustomFood(
      name: 'Mine',
      kcal: 1,
      protein: 0,
      carbs: 0,
      fat: 0,
    );

    final json = jsonDecode(await ExportService(db).buildJson()) as Map;
    expect(json['format'], 'corpus-export');
    expect(json['measurements'], hasLength(1));
    expect((json['customFoods'] as List).single['name'], 'Mine');
  });

  test('units', () {
    expect(lbToKg(kgToLb(80)), closeTo(80, 1e-9));
    expect(dayKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
    expect(parseDayKey('2026-03-05'), DateTime(2026, 3, 5));
    expect(formatDuration(const Duration(minutes: 485)), '8h 05m');
    expect(formatNumber(72.50, decimals: 1), '72.5');
    expect(formatNumber(72.0, decimals: 1), '72');
  });
}
