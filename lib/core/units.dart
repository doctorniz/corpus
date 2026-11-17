/// Canonical storage units. Everything is stored in these; conversion
/// happens only at the UI edge.
abstract final class CanonicalUnit {
  static const mass = 'kg';
  static const length = 'm';
  static const duration = 's';
  static const energy = 'kcal';
  static const count = 'count';
}

/// A kind of measurement the app knows how to label, store and chart.
class MeasurementKind {
  const MeasurementKind(this.type, this.label, this.unit, {this.decimals = 0});
  final String type;
  final String label;
  final String unit;
  final int decimals;
}

abstract final class MeasurementType {
  static const weight = 'weight';
  static const height = 'height';
  static const bodyFat = 'body_fat';
  static const restingHr = 'resting_hr';
  static const bpSystolic = 'bp_sys';
  static const bpDiastolic = 'bp_dia';
  static const temperature = 'temperature';
  static const glucose = 'glucose';
  static const spo2 = 'spo2';
  static const steps = 'steps';
  static const water = 'water';

  static const kinds = <String, MeasurementKind>{
    weight: MeasurementKind(weight, 'Weight', 'kg', decimals: 1),
    height: MeasurementKind(height, 'Height', 'cm'),
    bodyFat: MeasurementKind(bodyFat, 'Body fat', '%', decimals: 1),
    restingHr: MeasurementKind(restingHr, 'Resting heart rate', 'bpm'),
    bpSystolic: MeasurementKind(bpSystolic, 'Systolic', 'mmHg'),
    bpDiastolic: MeasurementKind(bpDiastolic, 'Diastolic', 'mmHg'),
    temperature: MeasurementKind(temperature, 'Temperature', '°C', decimals: 1),
    glucose: MeasurementKind(glucose, 'Blood glucose', 'mmol/L', decimals: 1),
    spo2: MeasurementKind(spo2, 'Oxygen saturation', '%'),
    steps: MeasurementKind(steps, 'Steps', 'steps'),
    water: MeasurementKind(water, 'Water', 'ml'),
  };

  /// Vitals offered in the Health tab and the + sheet (blood pressure is
  /// entered as a pair and handled separately).
  static const vitals = [
    weight,
    restingHr,
    temperature,
    glucose,
    spo2,
    bodyFat,
    height,
  ];
}

const _lbPerKg = 2.2046226218;

double kgToLb(double kg) => kg * _lbPerKg;
double lbToKg(double lb) => lb / _lbPerKg;

/// 'yyyy-MM-dd' for the local calendar day of [t].
String dayKey(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)}';
}

DateTime parseDayKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String formatNumber(double v, {int decimals = 0}) {
  final s = v.toStringAsFixed(decimals);
  if (decimals == 0) return s;
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}
