import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/activities.dart';
import '../../data/fitness_repository.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';

/// Log a workout. Strength sessions get a sets editor; distance sports get
/// a distance field.
class WorkoutFormScreen extends ConsumerStatefulWidget {
  const WorkoutFormScreen({super.key, this.initialActivity});

  final String? initialActivity;

  @override
  ConsumerState<WorkoutFormScreen> createState() => _WorkoutFormState();
}

class _SetRow {
  _SetRow(String exercise, {String reps = '', String weight = ''})
    : exercise = TextEditingController(text: exercise),
      reps = TextEditingController(text: reps),
      weight = TextEditingController(text: weight);

  final TextEditingController exercise;
  final TextEditingController reps;
  final TextEditingController weight;

  void dispose() {
    exercise.dispose();
    reps.dispose();
    weight.dispose();
  }
}

class _WorkoutFormState extends ConsumerState<WorkoutFormScreen> {
  late String _activity = widget.initialActivity ?? strengthActivity;
  DateTime _start = DateTime.now().subtract(const Duration(hours: 1));
  final _minutes = TextEditingController(text: '60');
  final _distance = TextEditingController();
  final _kcal = TextEditingController();
  final _hr = TextEditingController();
  final _notes = TextEditingController();
  final _sets = <_SetRow>[];
  List<String> _suggestions = commonExercises;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    ref.read(fitnessProvider).loggedExercises().then((mine) {
      if (!mounted) return;
      setState(() => _suggestions = {...mine, ...commonExercises}.toList());
    });
  }

  @override
  void dispose() {
    for (final c in [_minutes, _distance, _kcal, _hr, _notes]) {
      c.dispose();
    }
    for (final s in _sets) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSet() {
    // A new set repeats the previous one: the common case in the gym.
    final last = _sets.lastOrNull;
    setState(
      () => _sets.add(
        _SetRow(
          last?.exercise.text ?? '',
          reps: last?.reps.text ?? '',
          weight: last?.weight.text ?? '',
        ),
      ),
    );
  }

  Future<void> _save() async {
    final minutes = parseNumber(_minutes.text);
    if (minutes == null || minutes <= 0) {
      showSnack(context, 'Enter how long it lasted.');
      return;
    }
    final km = parseNumber(_distance.text);
    setState(() => _saving = true);
    await ref
        .read(fitnessProvider)
        .addWorkout(
          activity: _activity,
          startedAt: _start,
          endedAt: _start.add(Duration(seconds: (minutes * 60).round())),
          distanceM: km == null ? null : km * 1000,
          energyKcal: parseNumber(_kcal.text),
          avgHr: int.tryParse(_hr.text),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          sets: [
            for (final s in _sets)
              SetDraft(
                exercise: s.exercise.text,
                reps: int.tryParse(s.reps.text),
                weightKg: parseNumber(s.weight.text),
              ),
          ],
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final activity = activityById(_activity);
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Log workout')),
      body: PageBody(
        children: [
          const SizedBox(height: 8),
          FormColumn(
            children: [
              ChoiceChips<Activity>(
                options: activities,
                selected: activity,
                label: (a) => a.label,
                onSelected: (a) => setState(() => _activity = a.id),
              ),
              DateTimeField(
                label: 'Started',
                value: _start,
                onChanged: (d) => setState(() => _start = d),
              ),
              Row(
                children: [
                  Expanded(
                    child: NumberField(
                      key: const ValueKey('workout-minutes'),
                      controller: _minutes,
                      label: 'Duration',
                      suffix: 'min',
                    ),
                  ),
                  if (activity.hasDistance) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: NumberField(
                        key: const ValueKey('workout-distance'),
                        controller: _distance,
                        label: 'Distance',
                        suffix: 'km',
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: NumberField(
                      controller: _kcal,
                      label: 'Energy',
                      suffix: 'kcal',
                      decimal: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NumberField(
                      controller: _hr,
                      label: 'Avg heart rate',
                      suffix: 'bpm',
                      decimal: false,
                    ),
                  ),
                ],
              ),
              if (_activity == strengthActivity) ...[
                const FieldLabel('Sets'),
                for (var i = 0; i < _sets.length; i++)
                  _SetEditor(
                    key: ObjectKey(_sets[i]),
                    index: i,
                    row: _sets[i],
                    suggestions: _suggestions,
                    onRemove: () => setState(() => _sets.removeAt(i).dispose()),
                  ),
                OutlinedButton.icon(
                  key: const ValueKey('workout-add-set'),
                  onPressed: _addSet,
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: Text(_sets.isEmpty ? 'Add a set' : 'Add another set'),
                ),
              ],
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              FilledButton(
                key: const ValueKey('workout-save'),
                onPressed: _saving ? null : _save,
                child: const Text('Save workout'),
              ),
              if (_activity == strengthActivity && _sets.isEmpty)
                Text(
                  'Sets are optional. Add them to track your lifts over time.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: c.fgTertiary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SetEditor extends StatelessWidget {
  const _SetEditor({
    super.key,
    required this.index,
    required this.row,
    required this.suggestions,
    required this.onRemove,
  });

  final int index;
  final _SetRow row;
  final List<String> suggestions;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Autocomplete<String>(
            initialValue: TextEditingValue(text: row.exercise.text),
            optionsBuilder: (v) {
              final q = v.text.toLowerCase().trim();
              if (q.isEmpty) return suggestions.take(8);
              return suggestions.where((e) => e.toLowerCase().contains(q));
            },
            onSelected: (e) => row.exercise.text = e,
            fieldViewBuilder: (context, controller, focus, _) => TextField(
              controller: controller,
              focusNode: focus,
              onChanged: (v) => row.exercise.text = v,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Exercise ${index + 1}'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: NumberField(
            controller: row.reps,
            label: 'Reps',
            decimal: false,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: NumberField(controller: row.weight, label: 'kg'),
        ),
        IconButton(
          tooltip: 'Remove set',
          visualDensity: VisualDensity.compact,
          icon: const Icon(LucideIcons.x, size: 18),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
