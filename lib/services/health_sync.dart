import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/db/database.dart';
import '../core/units.dart';
import '../data/context.dart';
import '../data/cycle_repository.dart';
import '../data/fitness_repository.dart';
import '../data/health_bridge.dart';
import '../data/measurements_repository.dart';
import '../data/settings_repository.dart';
import '../data/sleep_repository.dart';

/// Two-way sync with Apple Health (iOS) and Health Connect (Android).
///
/// Reading: steps, weight, height, body fat, resting heart rate, blood
/// pressure, workouts, sleep and menstrual flow are imported. Anything a
/// watch or tracker writes to the phone's health store arrives this way.
///
/// Writing: entries logged by hand in Corpus are mirrored to the health
/// store as they are saved (this class is the [HealthBridge]).
///
/// Off until the user enables it in Settings. Nothing here talks to the
/// network: both health stores are on-device.
class HealthSyncService implements HealthBridge {
  HealthSyncService({
    required this.context,
    required this.settings,
    required this.measurements,
    required this.fitness,
    required this.sleep,
    required this.cycle,
  });

  final DataContext context;
  final SettingsRepository settings;
  final MeasurementsRepository measurements;
  final FitnessRepository fitness;
  final SleepRepository sleep;
  final CycleRepository cycle;

  final _health = Health();
  bool _configured = false;
  bool _enabled = false;
  String? _appId;

  /// True while an import is running; drives the spinner in Settings.
  final syncing = ValueNotifier<bool>(false);

  /// The most recent failure, in words a person can act on.
  final lastError = ValueNotifier<String?>(null);

  static bool get supported => Platform.isAndroid || Platform.isIOS;

  static String get storeName =>
      Platform.isIOS ? 'Apple Health' : 'Health Connect';

  HealthDataType get _sleepType => Platform.isIOS
      ? HealthDataType.SLEEP_ASLEEP
      : HealthDataType.SLEEP_SESSION;

  /// Every type we ask for, and whether we read it, write it, or both.
  Map<HealthDataType, HealthDataAccess> get _access => {
    HealthDataType.STEPS: HealthDataAccess.READ,
    HealthDataType.WEIGHT: HealthDataAccess.READ_WRITE,
    HealthDataType.HEIGHT: HealthDataAccess.READ_WRITE,
    HealthDataType.BODY_FAT_PERCENTAGE: HealthDataAccess.READ_WRITE,
    HealthDataType.RESTING_HEART_RATE: HealthDataAccess.READ_WRITE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC: HealthDataAccess.READ_WRITE,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC: HealthDataAccess.READ_WRITE,
    HealthDataType.WORKOUT: HealthDataAccess.READ_WRITE,
    _sleepType: HealthDataAccess.READ_WRITE,
    HealthDataType.MENSTRUATION_FLOW: HealthDataAccess.READ_WRITE,
    HealthDataType.WATER: HealthDataAccess.WRITE,
    HealthDataType.NUTRITION: HealthDataAccess.WRITE,
    // On Android a workout's distance and energy are separate records.
    if (Platform.isAndroid) ...{
      HealthDataType.DISTANCE_DELTA: HealthDataAccess.READ_WRITE,
      HealthDataType.TOTAL_CALORIES_BURNED: HealthDataAccess.READ_WRITE,
    },
  };

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _appId = (await PackageInfo.fromPlatform()).packageName;
    _configured = true;
  }

  /// Called once at launch: resumes syncing if it was left switched on.
  Future<void> start() async {
    if (!supported) return;
    if (await settings.get(SettingKey.healthSync) != 'true') return;
    try {
      await _configure();
      _enabled = true;
      context.bridge = this;
      await sync();
    } catch (e) {
      debugPrint('[health] Could not start: $e');
      lastError.value = 'Health sync could not start: $e';
    }
  }

  Future<void> syncIfEnabled() async {
    if (_enabled) await sync();
  }

  /// Asks for permission and turns sync on. Returns null on success, or a
  /// message explaining what stopped it.
  Future<String?> enable() async {
    if (!supported) return 'Health sync is only available on a phone.';
    try {
      await _configure();
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          await _health.installHealthConnect();
          return 'Health Connect needs to be installed or updated first. '
              'Try again once that is done.';
        }
      }
      final access = _access;
      final granted = await _health.requestAuthorization(
        access.keys.toList(),
        permissions: access.values.toList(),
      );
      if (!granted) {
        return 'Permission was not granted. You can allow access in '
            '$storeName and try again.';
      }
      await settings.set(SettingKey.healthSync, 'true');
      _enabled = true;
      context.bridge = this;
      lastError.value = null;
      await sync();
      return lastError.value;
    } catch (e) {
      return 'Could not connect to $storeName: $e';
    }
  }

  Future<void> disable() async {
    _enabled = false;
    context.bridge = const NoHealthBridge();
    await settings.set(SettingKey.healthSync, 'false');
  }

  // ---- Import ----

  /// Pulls everything new since the last sync (30 days the first time).
  Future<void> sync() async {
    if (!_enabled || syncing.value) return;
    syncing.value = true;
    final errors = <String>[];
    try {
      final now = DateTime.now();
      final last = DateTime.tryParse(
        await settings.get(SettingKey.healthLastSync) ?? '',
      );
      final earliest = now.subtract(const Duration(days: 30));
      var from = last?.subtract(const Duration(days: 2)) ?? earliest;
      if (from.isBefore(earliest)) from = earliest;

      Future<void> step(String what, Future<void> Function() run) async {
        try {
          await run();
        } catch (e) {
          errors.add('$what: $e');
        }
      }

      await step('steps', () => _importSteps(from, now));
      await step('measurements', () => _importMeasurements(from, now));
      await step('blood pressure', () => _importBloodPressure(from, now));
      await step('workouts', () => _importWorkouts(from, now));
      await step('sleep', () => _importSleep(from, now));
      await step('cycle', () => _importCycle(from, now));

      await settings.set(SettingKey.healthLastSync, now.toIso8601String());
      lastError.value = errors.isEmpty
          ? null
          : 'Some data could not be read (${errors.join('; ')})';
    } finally {
      syncing.value = false;
    }
  }

  /// Data points that did not come from Corpus itself.
  Future<List<HealthDataPoint>> _read(
    List<HealthDataType> types,
    DateTime from,
    DateTime to,
  ) async {
    final points = await _health.getHealthDataFromTypes(
      types: types,
      startTime: from,
      endTime: to,
    );
    return _health
        .removeDuplicates(points)
        .where((p) => p.sourceId != _appId)
        .toList();
  }

  Future<void> _importSteps(DateTime from, DateTime to) async {
    var day = dateOnly(from);
    while (!day.isAfter(to)) {
      final next = DateTime(day.year, day.month, day.day + 1);
      final total = await _health.getTotalStepsInInterval(
        day,
        next.isAfter(to) ? to : next,
      );
      if (total != null && total > 0) {
        await measurements.upsertExternal(
          externalId: 'steps:${dayKey(day)}',
          type: MeasurementType.steps,
          value: total.toDouble(),
          at: day.add(const Duration(hours: 12)),
        );
      }
      day = next;
    }
  }

  Future<void> _importMeasurements(DateTime from, DateTime to) async {
    const types = {
      HealthDataType.WEIGHT: MeasurementType.weight,
      HealthDataType.HEIGHT: MeasurementType.height,
      HealthDataType.BODY_FAT_PERCENTAGE: MeasurementType.bodyFat,
      HealthDataType.RESTING_HEART_RATE: MeasurementType.restingHr,
    };
    for (final p in await _read(types.keys.toList(), from, to)) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      var value = v.numericValue.toDouble();
      // Stored as cm; the health stores use metres.
      if (p.type == HealthDataType.HEIGHT) value *= 100;
      // Apple Health reports body fat as a fraction.
      if (p.type == HealthDataType.BODY_FAT_PERCENTAGE && value <= 1) {
        value *= 100;
      }
      await measurements.upsertExternal(
        externalId: 'health:${p.type.name}:${p.uuid}',
        type: types[p.type]!,
        value: value,
        at: p.dateFrom,
      );
    }
  }

  Future<void> _importBloodPressure(DateTime from, DateTime to) async {
    const types = {
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC: MeasurementType.bpSystolic,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC: MeasurementType.bpDiastolic,
    };
    for (final p in await _read(types.keys.toList(), from, to)) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      await measurements.upsertExternal(
        externalId: 'health:${p.type.name}:${p.uuid}',
        type: types[p.type]!,
        value: v.numericValue.toDouble(),
        // Both halves of a reading share a timestamp, which is how the
        // app pairs them up.
        at: p.dateFrom,
      );
    }
  }

  Future<void> _importWorkouts(DateTime from, DateTime to) async {
    for (final p in await _read([HealthDataType.WORKOUT], from, to)) {
      final v = p.value;
      if (v is! WorkoutHealthValue) continue;
      await fitness.importExternal(
        externalId: 'health:${p.uuid}',
        activity: _activityFor(v.workoutActivityType),
        startedAt: p.dateFrom,
        endedAt: p.dateTo,
        distanceM: v.totalDistance?.toDouble(),
        energyKcal: v.totalEnergyBurned?.toDouble(),
      );
    }
  }

  Future<void> _importSleep(DateTime from, DateTime to) async {
    final points = await _read([_sleepType], from, to)
      ..sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    if (Platform.isAndroid) {
      for (final p in points) {
        await sleep.importExternal(
          externalId: 'health:${p.uuid}',
          startedAt: p.dateFrom,
          endedAt: p.dateTo,
        );
      }
      return;
    }
    // Apple Health stores a night as many short "asleep" segments; join
    // those less than an hour apart into one session.
    final nights = <({DateTime start, DateTime end})>[];
    for (final p in points) {
      if (nights.isNotEmpty &&
          p.dateFrom.difference(nights.last.end).inMinutes < 60) {
        final last = nights.removeLast();
        nights.add((
          start: last.start,
          end: p.dateTo.isAfter(last.end) ? p.dateTo : last.end,
        ));
      } else {
        nights.add((start: p.dateFrom, end: p.dateTo));
      }
    }
    for (final n in nights) {
      // A night still in progress would be stored short; wait for it.
      if (to.difference(n.end).inMinutes < 60) continue;
      await sleep.importExternal(
        externalId: 'health:sleep:${dayKey(n.end)}:${n.start.hour}',
        startedAt: n.start,
        endedAt: n.end,
      );
    }
  }

  Future<void> _importCycle(DateTime from, DateTime to) async {
    for (final p in await _read([HealthDataType.MENSTRUATION_FLOW], from, to)) {
      final v = p.value;
      if (v is! MenstruationFlowHealthValue) continue;
      final flow = switch (v.flow) {
        MenstrualFlow.light => 2,
        MenstrualFlow.medium => 3,
        MenstrualFlow.heavy => 4,
        MenstrualFlow.unspecified => 3,
        _ => 0,
      };
      if (flow == 0) continue;
      await cycle.setDay(p.dateFrom, flow: flow, source: 'health');
    }
  }

  static String _activityFor(HealthWorkoutActivityType t) => switch (t) {
    HealthWorkoutActivityType.RUNNING => 'run',
    HealthWorkoutActivityType.WALKING => 'walk',
    HealthWorkoutActivityType.BIKING => 'cycle',
    HealthWorkoutActivityType.SWIMMING => 'swim',
    HealthWorkoutActivityType.HIKING => 'hike',
    HealthWorkoutActivityType.ROWING => 'row',
    HealthWorkoutActivityType.YOGA => 'yoga',
    HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING => 'hiit',
    HealthWorkoutActivityType.STRENGTH_TRAINING ||
    HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING ||
    HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING ||
    HealthWorkoutActivityType.WEIGHTLIFTING => 'strength',
    _ => 'other',
  };

  static HealthWorkoutActivityType _typeFor(String activity) =>
      switch (activity) {
        'run' => HealthWorkoutActivityType.RUNNING,
        'walk' => HealthWorkoutActivityType.WALKING,
        'cycle' => HealthWorkoutActivityType.BIKING,
        'swim' => HealthWorkoutActivityType.SWIMMING,
        'hike' => HealthWorkoutActivityType.HIKING,
        'row' => HealthWorkoutActivityType.ROWING,
        'yoga' => HealthWorkoutActivityType.YOGA,
        'hiit' => HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
        'strength' =>
          Platform.isIOS
              ? HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING
              : HealthWorkoutActivityType.STRENGTH_TRAINING,
        _ => HealthWorkoutActivityType.OTHER,
      };

  // ---- Write-back (HealthBridge) ----

  /// Runs a write and swallows any failure: the entry is already saved in
  /// Corpus, and a health-store hiccup must not surface as a lost entry.
  Future<void> _push(String what, Future<bool> Function() write) async {
    if (!_enabled) return;
    try {
      if (!await write()) {
        debugPrint('[health] Write-back skipped ($what)');
      }
    } catch (e) {
      debugPrint('[health] Write-back failed ($what): $e');
    }
  }

  static const _manual = RecordingMethod.manual;

  @override
  Future<void> pushMeasurement(String type, double value, DateTime at) {
    final (healthType, converted) = switch (type) {
      MeasurementType.weight => (HealthDataType.WEIGHT, value),
      MeasurementType.height => (HealthDataType.HEIGHT, value / 100),
      MeasurementType.bodyFat => (HealthDataType.BODY_FAT_PERCENTAGE, value),
      MeasurementType.restingHr => (HealthDataType.RESTING_HEART_RATE, value),
      MeasurementType.water => (HealthDataType.WATER, value / 1000),
      _ => (null, value),
    };
    if (healthType == null) return Future.value();
    return _push(
      type,
      () => _health.writeHealthData(
        value: converted,
        type: healthType,
        startTime: at,
        endTime: at,
        recordingMethod: _manual,
      ),
    );
  }

  @override
  Future<void> pushBloodPressure(int systolic, int diastolic, DateTime at) {
    return _push(
      'blood pressure',
      () => _health.writeBloodPressure(
        systolic: systolic,
        diastolic: diastolic,
        startTime: at,
        recordingMethod: _manual,
      ),
    );
  }

  @override
  Future<void> pushWorkout(Workout workout) {
    return _push(
      'workout',
      () => _health.writeWorkoutData(
        activityType: _typeFor(workout.activity),
        start: workout.startedAt.toLocal(),
        end: workout.endedAt.toLocal(),
        totalDistance: workout.distanceM?.round(),
        totalEnergyBurned: workout.energyKcal?.round(),
        title: workout.title,
        recordingMethod: _manual,
      ),
    );
  }

  @override
  Future<void> pushSleep(DateTime start, DateTime end) {
    return _push(
      'sleep',
      () => _health.writeHealthData(
        value: end.difference(start).inMinutes.toDouble(),
        type: _sleepType,
        startTime: start,
        endTime: end,
        recordingMethod: _manual,
      ),
    );
  }

  @override
  Future<void> pushMeal(MealEntry entry) {
    final at = entry.eatenAt.toLocal();
    return _push(
      'meal',
      () => _health.writeMeal(
        mealType: switch (entry.slot) {
          'breakfast' => MealType.BREAKFAST,
          'lunch' => MealType.LUNCH,
          'dinner' => MealType.DINNER,
          _ => MealType.SNACK,
        },
        startTime: at,
        endTime: at.add(const Duration(minutes: 1)),
        caloriesConsumed: entry.kcal,
        carbohydrates: entry.carbs,
        protein: entry.protein,
        fatTotal: entry.fat,
        name: entry.name,
        recordingMethod: _manual,
      ),
    );
  }

  @override
  Future<void> pushCycleDay(String day, int flow, {required bool isStart}) {
    final start = parseDayKey(day).add(const Duration(hours: 12));
    return _push(
      'cycle',
      () => _health.writeMenstruationFlow(
        flow: switch (flow) {
          1 || 2 => MenstrualFlow.light,
          3 => MenstrualFlow.medium,
          _ => MenstrualFlow.heavy,
        },
        startTime: start,
        endTime: start,
        isStartOfCycle: isStart,
        recordingMethod: _manual,
      ),
    );
  }
}
