/// Workout activity types. `hasDistance` controls whether the form asks
/// for a distance; `strength` shows the sets editor.
class Activity {
  const Activity(this.id, this.label, {this.hasDistance = false});
  final String id;
  final String label;
  final bool hasDistance;
}

const strengthActivity = 'strength';

const activities = <Activity>[
  Activity(strengthActivity, 'Gym / strength'),
  Activity('run', 'Run', hasDistance: true),
  Activity('walk', 'Walk', hasDistance: true),
  Activity('cycle', 'Cycle', hasDistance: true),
  Activity('swim', 'Swim', hasDistance: true),
  Activity('hike', 'Hike', hasDistance: true),
  Activity('row', 'Row', hasDistance: true),
  Activity('yoga', 'Yoga'),
  Activity('hiit', 'HIIT'),
  Activity('sport', 'Sport'),
  Activity('other', 'Other'),
];

Activity activityById(String id) =>
    activities.firstWhere((a) => a.id == id, orElse: () => activities.last);

/// Suggestions for the strength sets editor; any name can be typed.
const commonExercises = <String>[
  'Back squat',
  'Front squat',
  'Deadlift',
  'Romanian deadlift',
  'Bench press',
  'Incline bench press',
  'Overhead press',
  'Barbell row',
  'Pull-up',
  'Chin-up',
  'Lat pulldown',
  'Seated cable row',
  'Dumbbell press',
  'Dumbbell row',
  'Lateral raise',
  'Biceps curl',
  'Triceps pushdown',
  'Dip',
  'Push-up',
  'Leg press',
  'Leg extension',
  'Leg curl',
  'Lunge',
  'Bulgarian split squat',
  'Hip thrust',
  'Calf raise',
  'Face pull',
  'Plank',
  'Hanging leg raise',
  'Kettlebell swing',
];
