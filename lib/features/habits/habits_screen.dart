import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';
import '../../data/habits_repository.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';

Future<void> showHabitSheet(BuildContext context, {Habit? existing}) {
  return showAppSheet<void>(
    context,
    title: existing == null ? 'New habit' : 'Edit habit',
    child: _HabitForm(existing: existing),
  );
}

class _HabitForm extends ConsumerStatefulWidget {
  const _HabitForm({this.existing});

  final Habit? existing;

  @override
  ConsumerState<_HabitForm> createState() => _HabitFormState();
}

class _HabitFormState extends ConsumerState<_HabitForm> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _target = TextEditingController(
    text: '${widget.existing?.target ?? 8}',
  );
  late final _unit = TextEditingController(text: widget.existing?.unit);
  late String _kind = widget.existing?.kind ?? 'bool';
  late int _mask = widget.existing?.daysMask ?? 127;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Give the habit a name.');
      return;
    }
    if (_mask == 0) {
      showSnack(context, 'Pick at least one day.');
      return;
    }
    final target = _kind == 'count' ? (int.tryParse(_target.text) ?? 1) : 1;
    await ref
        .read(habitsProvider)
        .save(
          id: widget.existing?.id,
          name: name,
          kind: _kind,
          target: target < 1 ? 1 : target,
          unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
          daysMask: _mask,
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FormColumn(
      children: [
        TextField(
          key: const ValueKey('habit-name'),
          controller: _name,
          autofocus: widget.existing == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Habit',
            hintText: 'e.g. Stretch for 10 minutes',
          ),
        ),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'bool', label: Text('Done / not done')),
            ButtonSegment(value: 'count', label: Text('Count')),
          ],
          selected: {_kind},
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        if (_kind == 'count')
          Row(
            children: [
              Expanded(
                child: NumberField(
                  controller: _target,
                  label: 'Daily target',
                  decimal: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    hintText: 'e.g. glasses',
                  ),
                ),
              ),
            ],
          ),
        const FieldLabel('Days'),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _mask ^= 1 << i),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _mask & (1 << i) != 0
                            ? c.accentLight
                            : c.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _mask & (1 << i) != 0 ? c.accent : c.border,
                        ),
                      ),
                      child: Text(
                        const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _mask & (1 << i) != 0
                              ? c.accent
                              : c.fgSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        FilledButton(
          key: const ValueKey('habit-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
        if (widget.existing != null)
          TextButton(
            onPressed: () async {
              if (!await confirmDelete(context, 'this habit')) return;
              await ref.read(habitsProvider).delete(widget.existing!.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text('Delete habit', style: TextStyle(color: c.danger)),
          ),
      ],
    );
  }
}

/// Today's habits with one-tap check-in, a streak, and the last week.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(habitsProvider);
    final today = dateOnly(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            key: const ValueKey('habit-add'),
            tooltip: 'New habit',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => showHabitSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamHost<List<Habit>>(
        create: repo.watchHabits,
        builder: (context, habits) {
          if (habits.isEmpty) {
            return Center(
              child: EmptyState(
                icon: LucideIcons.circleCheck,
                title: 'No habits yet',
                message: 'Add something you want to do regularly.',
                action: FilledButton.icon(
                  onPressed: () => showHabitSheet(context),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('New habit'),
                ),
              ),
            );
          }
          return StreamHost<Map<String, Map<String, int>>>(
            create: () =>
                repo.watchLogs(today.subtract(const Duration(days: 400))),
            builder: (context, logs) {
              final due = habits.where((h) => habitDueOn(h, today)).toList();
              final done = due
                  .where((h) => (logs[h.id]?[dayKey(today)] ?? 0) >= h.target)
                  .length;
              return PageBody(
                children: [
                  const SizedBox(height: 8),
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Stat(
                            label: 'Today',
                            value: '$done of ${due.length}',
                            color: due.isNotEmpty && done == due.length
                                ? context.colors.success
                                : null,
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            value: due.isEmpty ? 0 : done / due.length,
                            strokeWidth: 5,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final h in habits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HabitCard(
                        habit: h,
                        logs: logs[h.id] ?? const {},
                        today: today,
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  const _HabitCard({
    required this.habit,
    required this.logs,
    required this.today,
  });

  final Habit habit;
  final Map<String, int> logs;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final repo = ref.read(habitsProvider);
    final value = logs[dayKey(today)] ?? 0;
    final done = value >= habit.target;
    final dueToday = habitDueOn(habit, today);
    final streak = habitStreak(habit, logs, today);
    final isCount = habit.kind == 'count';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      onTap: () => showHabitSheet(context, existing: habit),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (isCount)
                          '$value / ${habit.target}'
                              '${habit.unit == null ? '' : ' ${habit.unit}'}',
                        if (!dueToday) 'Not scheduled today',
                        streak > 0 ? '$streak-day streak' : 'No streak yet',
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: c.fgTertiary),
                    ),
                  ],
                ),
              ),
              if (isCount && value > 0)
                IconButton(
                  tooltip: 'One less',
                  icon: const Icon(LucideIcons.minus, size: 20),
                  onPressed: () => repo.setLog(habit.id, today, value - 1),
                ),
              Semantics(
                button: true,
                label: done
                    ? '${habit.name}: done'
                    : isCount
                    ? '${habit.name}: add one'
                    : '${habit.name}: mark done',
                child: InkWell(
                  key: ValueKey('habit-check-${habit.name}'),
                  customBorder: const CircleBorder(),
                  onTap: () => repo.setLog(
                    habit.id,
                    today,
                    isCount ? value + 1 : (done ? 0 : 1),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? c.accent : null,
                      border: Border.all(
                        color: done ? c.accent : c.border,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      done || !isCount ? LucideIcons.check : LucideIcons.plus,
                      size: 20,
                      color: done ? c.accentFg : c.fgMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 6; i >= 0; i--)
                () {
                  final d = DateTime(today.year, today.month, today.day - i);
                  final v = logs[dayKey(d)] ?? 0;
                  final met = v >= habit.target;
                  final scheduled = habitDueOn(habit, d);
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: met
                                ? c.accent
                                : v > 0
                                ? c.accent.withValues(alpha: 0.35)
                                : scheduled
                                ? c.bgTertiary
                                : Colors.transparent,
                            border: scheduled
                                ? null
                                : Border.all(color: c.border),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][d.weekday -
                              1],
                          style: TextStyle(
                            fontSize: 10,
                            color: i == 0 ? c.fg : c.fgMuted,
                            fontWeight: i == 0
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                }(),
            ],
          ),
        ],
      ),
    );
  }
}
