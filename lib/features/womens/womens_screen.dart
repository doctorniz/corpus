import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';
import '../../data/cycle_repository.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';

/// Log flow, symptoms and notes for one day.
Future<void> showCycleDaySheet(
  BuildContext context,
  DateTime day, {
  CycleDay? existing,
}) {
  return showAppSheet<void>(
    context,
    title: friendlyDay(day),
    child: _CycleDayForm(day: day, existing: existing),
  );
}

class _CycleDayForm extends ConsumerStatefulWidget {
  const _CycleDayForm({required this.day, this.existing});

  final DateTime day;
  final CycleDay? existing;

  @override
  ConsumerState<_CycleDayForm> createState() => _CycleDayState();
}

class _CycleDayState extends ConsumerState<_CycleDayForm> {
  late int _flow = widget.existing?.flow ?? 0;
  late final Set<String> _symptoms = {
    if (widget.existing != null) ...decodeSymptoms(widget.existing!.symptoms),
  };
  late final _notes = TextEditingController(text: widget.existing?.notes);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(cycleProvider)
        .setDay(
          widget.day,
          flow: _flow,
          symptoms: _symptoms.toList(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FormColumn(
      children: [
        const FieldLabel('Flow'),
        ChoiceChips<int>(
          options: const [0, 1, 2, 3, 4],
          selected: _flow,
          label: (f) => flowLabels[f],
          onSelected: (f) => setState(() => _flow = f),
        ),
        const FieldLabel('Symptoms'),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in cycleSymptoms)
              FilterChip(
                label: Text(s),
                selected: _symptoms.contains(s),
                labelStyle: TextStyle(
                  fontSize: 13,
                  color: _symptoms.contains(s) ? c.accent : c.fg,
                ),
                onSelected: (on) =>
                    setState(() => on ? _symptoms.add(s) : _symptoms.remove(s)),
              ),
          ],
        ),
        TextField(
          controller: _notes,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Notes'),
        ),
        FilledButton(
          key: const ValueKey('cycle-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Cycle tracking: where you are in the cycle, a month calendar with logged
/// and predicted days, and the averages behind the prediction.
class WomensScreen extends ConsumerStatefulWidget {
  const WomensScreen({super.key});

  @override
  ConsumerState<WomensScreen> createState() => _WomensState();
}

class _WomensState extends ConsumerState<WomensScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(cycleProvider);
    final c = context.colors;
    final today = dateOnly(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Women's health"),
        actions: [
          IconButton(
            key: const ValueKey('cycle-log-today'),
            tooltip: 'Log today',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => showCycleDaySheet(context, today),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamHost<List<CycleDay>>(
        create: repo.watchAll,
        builder: (context, days) {
          final byDay = {for (final d in days) d.day: d};
          final stats = CycleStats.from(days);
          final predicted = stats.predictedDays();
          final fertile = stats.fertileDays();
          final next = stats.nextPeriod;
          final untilNext = next?.difference(today).inDays;

          String headline;
          String? sub;
          if (next == null) {
            headline = 'Log your period to begin';
            sub =
                'Tap a day on the calendar. Predictions appear after '
                'your first logged period and improve with each cycle.';
          } else if ((byDay[dayKey(today)]?.flow ?? 0) >= 2) {
            headline = 'Period · day ${stats.cycleDay}';
            sub = 'Next period expected ${friendlyDate(next)}';
          } else if (untilNext! > 0) {
            headline =
                'Period in $untilNext '
                '${untilNext == 1 ? 'day' : 'days'}';
            sub =
                'Cycle day ${stats.cycleDay} · expected ${friendlyDate(next)}';
          } else if (untilNext == 0) {
            headline = 'Period expected today';
            sub = 'Cycle day ${stats.cycleDay}';
          } else {
            headline =
                'Period ${-untilNext} '
                '${untilNext == -1 ? 'day' : 'days'} late';
            sub = 'Expected ${friendlyDate(next)}';
          }

          return PageBody(
            children: [
              const SizedBox(height: 8),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: context.text.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      style: TextStyle(color: c.fgTertiary, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous month',
                          icon: const Icon(LucideIcons.chevronLeft),
                          onPressed: () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month - 1,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            DateFormat.yMMMM().format(_month),
                            textAlign: TextAlign.center,
                            style: context.text.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next month',
                          icon: const Icon(LucideIcons.chevronRight),
                          onPressed: () => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    _MonthGrid(
                      month: _month,
                      byDay: byDay,
                      predicted: predicted,
                      fertile: fertile,
                      onTap: (d) => showCycleDaySheet(
                        context,
                        d,
                        existing: byDay[dayKey(d)],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      alignment: WrapAlignment.center,
                      children: [
                        _Legend(color: c.pink, label: 'Period'),
                        _Legend(
                          color: c.pink,
                          label: 'Predicted',
                          outlined: true,
                        ),
                        _Legend(
                          color: c.blue,
                          label: 'Fertile window (estimate)',
                          outlined: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionHeader('Your cycle'),
              StatRow(
                stats: [
                  Stat(
                    label: 'Average cycle',
                    value: stats.averageCycleDays?.toString() ?? '–',
                    unit: stats.averageCycleDays == null ? null : 'days',
                  ),
                  Stat(
                    label: 'Average period',
                    value: stats.averagePeriodDays?.toString() ?? '–',
                    unit: stats.averagePeriodDays == null ? null : 'days',
                  ),
                  Stat(
                    label: 'Periods logged',
                    value: '${stats.periodStarts.length}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Predictions are estimates from your own history. They are '
                'not a method of contraception or a medical assessment.',
                style: TextStyle(fontSize: 12, color: c.fgTertiary),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  final Color color;
  final String label;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: outlined ? null : color,
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.fgTertiary),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.predicted,
    required this.fertile,
    required this.onTap,
  });

  final DateTime month;
  final Map<String, CycleDay> byDay;
  final Set<String> predicted;
  final Set<String> fertile;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    final today = dateOnly(DateTime.now());
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    Widget cell(int index) {
      final dayNum = index - lead + 1;
      if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
      final date = DateTime(month.year, month.month, dayNum);
      final key = dayKey(date);
      final logged = byDay[key];
      final flow = logged?.flow ?? 0;
      final isFuture = date.isAfter(today);
      final isPredicted = flow < 2 && predicted.contains(key);
      final isFertile = flow < 2 && !isPredicted && fertile.contains(key);
      final hasNote =
          logged != null &&
          flow == 0 &&
          (logged.symptoms != '[]' || (logged.notes ?? '').isNotEmpty);

      Color? fill;
      Color? ring;
      var fg = isFuture ? c.fgMuted : c.fg;
      if (flow >= 2) {
        fill = c.pink.withValues(alpha: 0.45 + 0.18 * (flow - 1));
        fg = Colors.white;
      } else if (flow == 1) {
        fill = c.pinkLight;
      } else if (isPredicted) {
        ring = c.pink;
      } else if (isFertile) {
        ring = c.blue;
      }

      return Semantics(
        button: true,
        label:
            '${DateFormat.MMMMd().format(date)}'
            '${flow > 0 ? ', ${flowLabels[flow]} flow' : ''}'
            '${isPredicted ? ', period predicted' : ''}',
        child: InkWell(
          key: ValueKey('cycle-$key'),
          customBorder: const CircleBorder(),
          onTap: isFuture ? null : () => onTap(date),
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fill,
                border: ring != null
                    ? Border.all(color: ring, width: 1.5)
                    : date == today
                    ? Border.all(color: c.fg, width: 1.5)
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        fontSize: 14,
                        color: fg,
                        fontWeight: date == today
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (hasNote)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(fontSize: 12, color: c.fgTertiary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          SizedBox(
            height: 44,
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: cell(r * 7 + col)),
              ],
            ),
          ),
      ],
    );
  }
}
