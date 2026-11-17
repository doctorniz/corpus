import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../core/activities.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';
import '../../ui/charts.dart';
import '../../ui/widgets.dart';
import '../health/vitals_screen.dart';
import 'workout_form.dart';

IconData activityIcon(String id) => switch (id) {
  strengthActivity => LucideIcons.dumbbell,
  'run' => LucideIcons.footprints,
  'walk' || 'hike' => LucideIcons.mountain,
  'cycle' => LucideIcons.bike,
  'swim' => LucideIcons.waves,
  'yoga' => LucideIcons.flower2,
  _ => LucideIcons.activity,
};

String workoutSummary(Workout w) {
  final d = w.endedAt.difference(w.startedAt);
  return [
    formatDuration(d),
    if (w.distanceM != null)
      '${formatNumber(w.distanceM! / 1000, decimals: 2)} km',
    if (w.energyKcal != null) '${w.energyKcal!.round()} kcal',
  ].join(' · ');
}

/// min/km for a run or walk, if it has a distance.
String? pace(Workout w) {
  final km = (w.distanceM ?? 0) / 1000;
  if (km <= 0) return null;
  final secs = w.endedAt.difference(w.startedAt).inSeconds / km;
  final m = secs ~/ 60;
  final s = (secs % 60).round().toString().padLeft(2, '0');
  return '$m:$s /km';
}

/// Activity at a glance: this week, steps, weight, and the workout log.
class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitness = ref.watch(fitnessProvider);
    final measurements = ref.watch(measurementsProvider);
    final c = context.colors;
    final today = dateOnly(DateTime.now());
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final since = today.subtract(const Duration(days: 83));

    return Scaffold(
      appBar: Masthead(
        'Fitness',
        actions: [
          IconButton(
            key: const ValueKey('fitness-add'),
            tooltip: 'Log workout',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => pushPage(context, const WorkoutFormScreen()),
          ),
        ],
      ),
      body: StreamHost<List<Workout>>(
        create: () => fitness.watchWorkouts(since: since),
        builder: (context, workouts) {
          final week = workouts
              .where((w) => !w.startedAt.toLocal().isBefore(weekStart))
              .toList();
          final weekMinutes = week.fold(
            0,
            (m, w) => m + w.endedAt.difference(w.startedAt).inMinutes,
          );
          final weekKm =
              week.fold(0.0, (m, w) => m + (w.distanceM ?? 0)) / 1000;

          // Active minutes per week for the last 12 weeks.
          final weeks = [
            for (var i = 11; i >= 0; i--)
              () {
                final start = weekStart.subtract(Duration(days: 7 * i));
                final end = start.add(const Duration(days: 7));
                final mins = workouts
                    .where((w) {
                      final t = w.startedAt.toLocal();
                      return !t.isBefore(start) && t.isBefore(end);
                    })
                    .fold(
                      0,
                      (m, w) => m + w.endedAt.difference(w.startedAt).inMinutes,
                    );
                return (day: start, value: mins.toDouble());
              }(),
          ];

          return PageBody(
            children: [
              const SectionHeader('This week'),
              StatRow(
                stats: [
                  Stat(label: 'Workouts', value: '${week.length}'),
                  Stat(
                    label: 'Active time',
                    value: formatDuration(Duration(minutes: weekMinutes)),
                  ),
                  Stat(
                    label: 'Distance',
                    value: formatNumber(weekKm, decimals: 1),
                    unit: 'km',
                  ),
                ],
              ),
              const SectionHeader('Active minutes · last 12 weeks'),
              AppCard(child: _WeekBars(weeks: weeks)),
              const SectionHeader('Steps · last 14 days'),
              StreamHost<List<Measurement>>(
                create: () => measurements.watchType(
                  MeasurementType.steps,
                  since: today.subtract(const Duration(days: 14)),
                ),
                builder: (context, steps) {
                  final byDay = <String, double>{};
                  for (final s in steps) {
                    final k = dayKey(s.measuredAt);
                    byDay[k] = (byDay[k] ?? 0) + s.value;
                  }
                  if (byDay.isEmpty) {
                    return AppCard(
                      child: Text(
                        'No step data yet. Steps come from your phone or '
                        'watch once health sync is on in Settings.',
                        style: TextStyle(color: c.fgTertiary, fontSize: 14),
                      ),
                    );
                  }
                  final days = lastDays(14, (d) => byDay[dayKey(d)] ?? 0);
                  final avg =
                      days.fold(0.0, (a, d) => a + d.value) / days.length;
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Stat(
                                label: 'Today',
                                value: '${days.last.value.round()}',
                              ),
                            ),
                            Expanded(
                              child: Stat(
                                label: 'Daily average',
                                value: '${avg.round()}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DayBarChart(days: days, target: 10000),
                      ],
                    ),
                  );
                },
              ),
              SectionHeader(
                'Weight',
                trailing: TextButton(
                  onPressed: () =>
                      showVitalSheet(context, MeasurementType.weight),
                  child: const Text('Log'),
                ),
              ),
              StreamHost<List<Measurement>>(
                create: () => measurements.watchType(
                  MeasurementType.weight,
                  since: today.subtract(const Duration(days: 180)),
                ),
                builder: (context, weights) => AppCard(
                  onTap: () => pushPage(
                    context,
                    const VitalHistoryScreen(type: MeasurementType.weight),
                  ),
                  child: TrendChart(
                    height: 130,
                    points: [
                      for (final m in weights)
                        (at: m.measuredAt.toLocal(), value: m.value),
                    ],
                  ),
                ),
              ),
              const SectionHeader('Workouts'),
              if (workouts.isEmpty)
                EmptyState(
                  icon: LucideIcons.dumbbell,
                  title: 'No workouts yet',
                  message: 'Log a gym session, a run or any activity.',
                  action: FilledButton.icon(
                    onPressed: () =>
                        pushPage(context, const WorkoutFormScreen()),
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Log workout'),
                  ),
                )
              else
                TileGroup(
                  children: [
                    for (final w in workouts)
                      RowTile(
                        icon: activityIcon(w.activity),
                        title: w.title ?? activityById(w.activity).label,
                        subtitle:
                            '${friendlyDay(w.startedAt)} · '
                            '${workoutSummary(w)}',
                        onTap: () => pushPage(
                          context,
                          WorkoutDetailScreen(workoutId: w.id),
                        ),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.weeks});

  final List<DayValue> weeks;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = weeks.fold(0.0, (m, w) => w.value > m ? w.value : m);
    if (max == 0) {
      return Text(
        'Your weekly activity will build up here.',
        style: TextStyle(color: c.fgTertiary, fontSize: 14),
      );
    }
    return SizedBox(
      height: 96,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < weeks.length; i++)
            Expanded(
              child: Tooltip(
                message:
                    'Week of ${friendlyDate(weeks[i].day)}: '
                    '${weeks[i].value.round()} min',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FractionallySizedBox(
                    heightFactor: weeks[i].value == 0
                        ? 0.03
                        : (weeks[i].value / max).clamp(0.06, 1.0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: weeks[i].value == 0
                            ? c.bgTertiary
                            : i == weeks.length - 1
                            ? c.accent
                            : c.accent.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WorkoutDetailScreen extends ConsumerWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(fitnessProvider);
    final c = context.colors;
    return StreamHost<Workout?>(
      create: () => repo.watchWorkout(workoutId),
      builder: (context, w) {
        if (w == null) {
          return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
        }
        final p = pace(w);
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(LucideIcons.trash2, size: 20),
                onPressed: () async {
                  if (!await confirmDelete(context, 'this workout')) return;
                  await repo.delete(w.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: PageBody(
            children: [
              Text(
                friendlyDateTime(w.startedAt) +
                    (w.source == 'health' ? ' · from health data' : ''),
                style: TextStyle(color: c.fgTertiary, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                w.title ?? activityById(w.activity).label,
                style: context.text.headlineSmall,
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Wrap(
                  spacing: 28,
                  runSpacing: 16,
                  children: [
                    Stat(
                      label: 'Duration',
                      value: formatDuration(w.endedAt.difference(w.startedAt)),
                    ),
                    if (w.distanceM != null)
                      Stat(
                        label: 'Distance',
                        value: formatNumber(w.distanceM! / 1000, decimals: 2),
                        unit: 'km',
                      ),
                    if (p != null) Stat(label: 'Pace', value: p),
                    if (w.energyKcal != null)
                      Stat(
                        label: 'Energy',
                        value: '${w.energyKcal!.round()}',
                        unit: 'kcal',
                      ),
                    if (w.avgHr != null)
                      Stat(
                        label: 'Avg heart rate',
                        value: '${w.avgHr}',
                        unit: 'bpm',
                      ),
                  ],
                ),
              ),
              if ((w.notes ?? '').isNotEmpty) ...[
                const SectionHeader('Notes'),
                AppCard(child: Text(w.notes!)),
              ],
              StreamHost<List<WorkoutSet>>(
                create: () => repo.watchSets(w.id),
                builder: (context, sets) {
                  if (sets.isEmpty) return const SizedBox.shrink();
                  // Keep each exercise's sets together, in logged order.
                  final grouped = <String, List<WorkoutSet>>{};
                  for (final s in sets) {
                    (grouped[s.exercise] ??= []).add(s);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionHeader('Sets'),
                      TileGroup(
                        children: [
                          for (final e in grouped.entries)
                            RowTile(
                              title: e.key,
                              subtitle: e.value
                                  .map(
                                    (s) => [
                                      if (s.reps != null) '${s.reps}',
                                      if (s.weightKg != null)
                                        '${formatNumber(s.weightKg!, decimals: 1)} kg',
                                    ].join(' × '),
                                  )
                                  .join('   '),
                              onTap: () => pushPage(
                                context,
                                ExerciseHistoryScreen(exercise: e.key),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Heaviest set per session for one exercise, over time.
class ExerciseHistoryScreen extends ConsumerWidget {
  const ExerciseHistoryScreen({super.key, required this.exercise});

  final String exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(exercise)),
      body: FutureBuilder(
        future: ref.watch(fitnessProvider).exerciseHistory(exercise),
        builder: (context, snap) {
          final history = snap.data ?? const [];
          if (history.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: LucideIcons.dumbbell,
                title: 'No weights logged',
                message: 'Add a weight to your sets to see progress.',
              ),
            );
          }
          final best = history
              .map((h) => h.weightKg)
              .reduce((a, b) => a > b ? a : b);
          return PageBody(
            children: [
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Stat(
                            label: 'Best',
                            value: formatNumber(best, decimals: 1),
                            unit: 'kg',
                          ),
                        ),
                        Expanded(
                          child: Stat(
                            label: 'Latest',
                            value: formatNumber(
                              history.last.weightKg,
                              decimals: 1,
                            ),
                            unit: 'kg',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TrendChart(
                      points: [
                        for (final h in history) (at: h.day, value: h.weightKg),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
