import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';
import '../../data/settings_repository.dart';
import '../../ui/charts.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';

const _qualityLabels = ['Poor', 'Fair', 'OK', 'Good', 'Great'];

Future<void> showSleepSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Log sleep',
    child: const _SleepForm(),
  );
}

class _SleepForm extends ConsumerStatefulWidget {
  const _SleepForm();

  @override
  ConsumerState<_SleepForm> createState() => _SleepFormState();
}

class _SleepFormState extends ConsumerState<_SleepForm> {
  late DateTime _bed;
  late DateTime _wake;
  int? _quality;
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Default to last night: 23:00 to 07:00.
    final today = dateOnly(DateTime.now());
    _wake = today.add(const Duration(hours: 7));
    _bed = today.subtract(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final length = _wake.difference(_bed);
    if (length.inMinutes <= 0 || length.inHours > 24) {
      showSnack(context, 'Wake time must be after bedtime.');
      return;
    }
    await ref
        .read(sleepProvider)
        .add(
          startedAt: _bed,
          endedAt: _wake,
          quality: _quality,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final length = _wake.difference(_bed);
    return FormColumn(
      children: [
        DateTimeField(
          label: 'Fell asleep',
          value: _bed,
          onChanged: (d) => setState(() => _bed = d),
        ),
        DateTimeField(
          label: 'Woke up',
          value: _wake,
          onChanged: (d) => setState(() => _wake = d),
        ),
        if (length.inMinutes > 0)
          Text(
            formatDuration(length),
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
        const FieldLabel('How did you sleep?'),
        ChoiceChips<int>(
          options: const [1, 2, 3, 4, 5],
          selected: _quality,
          label: (q) => _qualityLabels[q - 1],
          onSelected: (q) => setState(() => _quality = q),
        ),
        TextField(
          controller: _notes,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        FilledButton(
          key: const ValueKey('sleep-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Total sleep per night. A session counts towards the day it ended, so
/// naps add to that day.
Map<String, Duration> sleepByNight(List<SleepSession> sessions) {
  final out = <String, Duration>{};
  for (final s in sessions) {
    final k = dayKey(s.endedAt);
    out[k] = (out[k] ?? Duration.zero) + s.endedAt.difference(s.startedAt);
  }
  return out;
}

class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sleepProvider);
    final c = context.colors;
    final target = numSetting(ref, SettingKey.sleepTarget, 8);
    final since = dateOnly(DateTime.now()).subtract(const Duration(days: 60));

    return Scaffold(
      appBar: Masthead(
        'Sleep',
        actions: [
          IconButton(
            key: const ValueKey('sleep-add'),
            tooltip: 'Log sleep',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => showSleepSheet(context),
          ),
        ],
      ),
      body: StreamHost<List<SleepSession>>(
        create: () => repo.watch(since: since),
        builder: (context, sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: EmptyState(
                icon: LucideIcons.moon,
                title: 'No sleep logged',
                message:
                    'Log last night, or turn on health sync in Settings to '
                    'bring in sleep from your watch or phone.',
                action: FilledButton.icon(
                  onPressed: () => showSleepSheet(context),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: const Text('Log sleep'),
                ),
              ),
            );
          }
          final nights = sleepByNight(sessions);
          final days = lastDays(
            14,
            (d) => (nights[dayKey(d)]?.inMinutes ?? 0) / 60,
          );
          final logged = days.where((d) => d.value > 0).toList();
          final avg = logged.isEmpty
              ? 0.0
              : logged.fold(0.0, (a, d) => a + d.value) / logged.length;
          final last = sessions.first;
          final lastLength = last.endedAt.difference(last.startedAt);

          // Average bedtime, as minutes after noon so times around
          // midnight average sensibly.
          final bedMinutes = sessions
              .take(14)
              .where((s) => s.endedAt.difference(s.startedAt).inHours >= 3)
              .map((s) {
                final t = s.startedAt.toLocal();
                return ((t.hour * 60 + t.minute) - 720 + 1440) % 1440;
              })
              .toList();
          String? bedtime;
          if (bedMinutes.isNotEmpty) {
            final m = (bedMinutes.reduce((a, b) => a + b) / bedMinutes.length)
                .round();
            final clock = (m + 720) % 1440;
            bedtime =
                '${(clock ~/ 60).toString().padLeft(2, '0')}:'
                '${(clock % 60).toString().padLeft(2, '0')}';
          }

          return PageBody(
            children: [
              const SectionHeader('Last sleep'),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Stat(
                        label:
                            '${friendlyTime(last.startedAt)} – '
                            '${friendlyTime(last.endedAt)} · '
                            '${friendlyDay(last.endedAt)}',
                        value: formatDuration(lastLength),
                        color: lastLength.inMinutes >= target * 60 - 30
                            ? c.success
                            : null,
                      ),
                    ),
                    if (last.quality != null)
                      Pill(_qualityLabels[last.quality! - 1]),
                  ],
                ),
              ),
              const SectionHeader('Last 14 nights'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Stat(
                            label: 'Average',
                            value: formatDuration(
                              Duration(minutes: (avg * 60).round()),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Stat(
                            label: 'Target',
                            value: formatNumber(target, decimals: 1),
                            unit: 'h',
                          ),
                        ),
                        if (bedtime != null)
                          Expanded(
                            child: Stat(label: 'Usual bedtime', value: bedtime),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DayBarChart(days: days, target: target, decimals: 1),
                  ],
                ),
              ),
              const SectionHeader('History'),
              TileGroup(
                children: [
                  for (final s in sessions)
                    RowTile(
                      icon: LucideIcons.moon,
                      title: formatDuration(s.endedAt.difference(s.startedAt)),
                      subtitle: [
                        friendlyDay(s.endedAt),
                        '${friendlyTime(s.startedAt)} – '
                            '${friendlyTime(s.endedAt)}',
                        if (s.quality != null) _qualityLabels[s.quality! - 1],
                        if (s.source == 'health') 'from health data',
                      ].join(' · '),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          LucideIcons.trash2,
                          size: 18,
                          color: c.fgTertiary,
                        ),
                        onPressed: () async {
                          if (await confirmDelete(context, 'this sleep')) {
                            await repo.delete(s.id);
                          }
                        },
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
