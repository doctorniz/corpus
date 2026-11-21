import '../core/db/database.dart';

/// Mirrors entries the user logs in Corpus into Apple Health / Health
/// Connect. Implemented by `HealthSyncService`; a no-op when sync is off
/// or the platform has no health store.
///
/// Implementations must never throw: a failed write-back must not stop the
/// entry being saved locally.
abstract class HealthBridge {
  Future<void> pushMeasurement(String type, double value, DateTime at);
  Future<void> pushBloodPressure(int systolic, int diastolic, DateTime at);
  Future<void> pushWorkout(Workout workout);
  Future<void> pushSleep(DateTime start, DateTime end);
  Future<void> pushMeal(MealEntry entry);
  Future<void> pushCycleDay(String day, int flow, {required bool isStart});
}

class NoHealthBridge implements HealthBridge {
  const NoHealthBridge();

  @override
  Future<void> pushMeasurement(String type, double value, DateTime at) async {}
  @override
  Future<void> pushBloodPressure(int s, int d, DateTime at) async {}
  @override
  Future<void> pushWorkout(Workout workout) async {}
  @override
  Future<void> pushSleep(DateTime start, DateTime end) async {}
  @override
  Future<void> pushMeal(MealEntry entry) async {}
  @override
  Future<void> pushCycleDay(
    String day,
    int flow, {
    required bool isStart,
  }) async {}
}
