/// Canonical storage units. Everything is stored in these; conversion
/// happens only at the UI edge.
abstract final class CanonicalUnit {
  static const mass = 'kg';
  static const length = 'm';
  static const duration = 's';
  static const energy = 'kcal';
  static const count = 'count';
}

abstract final class MeasurementType {
  static const weight = 'weight';
  static const bodyFat = 'body_fat';
  static const restingHr = 'resting_hr';
  static const bpSystolic = 'bp_sys';
  static const bpDiastolic = 'bp_dia';
  static const steps = 'steps';
  static const sleepDuration = 'sleep_duration';
}

const _lbPerKg = 2.2046226218;

double kgToLb(double kg) => kg * _lbPerKg;
double lbToKg(double lb) => lb / _lbPerKg;
