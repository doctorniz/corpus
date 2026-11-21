import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';
import '../../ui/charts.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';
import 'record_kinds.dart';
import 'records_screen.dart';

/// Common blood tests with their usual unit, offered as suggestions.
const commonLabTests = <String, String>{
  'Haemoglobin': 'g/L',
  'White cell count': '×10⁹/L',
  'Platelets': '×10⁹/L',
  'Ferritin': 'µg/L',
  'Vitamin B12': 'ng/L',
  'Folate': 'µg/L',
  'Vitamin D': 'nmol/L',
  'HbA1c': 'mmol/mol',
  'Fasting glucose': 'mmol/L',
  'Total cholesterol': 'mmol/L',
  'HDL cholesterol': 'mmol/L',
  'LDL cholesterol': 'mmol/L',
  'Triglycerides': 'mmol/L',
  'Creatinine': 'µmol/L',
  'eGFR': 'mL/min',
  'Sodium': 'mmol/L',
  'Potassium': 'mmol/L',
  'Urea': 'mmol/L',
  'ALT': 'U/L',
  'ALP': 'U/L',
  'Bilirubin': 'µmol/L',
  'Albumin': 'g/L',
  'TSH': 'mU/L',
  'Free T4': 'pmol/L',
  'CRP': 'mg/L',
  'PSA': 'µg/L',
  'Testosterone': 'nmol/L',
  'Calcium': 'mmol/L',
  'Magnesium': 'mmol/L',
  'Urate': 'µmol/L',
};

/// Whether a value is below, within or above its reference range.
int rangePosition(LabResult l) {
  if (l.refLow != null && l.value < l.refLow!) return -1;
  if (l.refHigh != null && l.value > l.refHigh!) return 1;
  return 0;
}

String formatRange(LabResult l) {
  final lo = l.refLow, hi = l.refHigh;
  if (lo != null && hi != null) {
    return '${formatNumber(lo, decimals: 2)}–${formatNumber(hi, decimals: 2)}';
  }
  if (lo != null) return '> ${formatNumber(lo, decimals: 2)}';
  if (hi != null) return '< ${formatNumber(hi, decimals: 2)}';
  return '';
}

Future<void> showLabSheet(BuildContext context, {LabResult? like}) {
  return showAppSheet<void>(
    context,
    title: 'Lab result',
    child: _LabForm(like: like),
  );
}

class _LabForm extends ConsumerStatefulWidget {
  const _LabForm({this.like});

  /// A previous result of the same test, used to prefill name, unit, range.
  final LabResult? like;

  @override
  ConsumerState<_LabForm> createState() => _LabFormState();
}

class _LabFormState extends ConsumerState<_LabForm> {
  late final _test = TextEditingController(text: widget.like?.test);
  late final _unit = TextEditingController(text: widget.like?.unit);
  final _value = TextEditingController();
  late final _low = TextEditingController(
    text: widget.like?.refLow == null
        ? ''
        : formatNumber(widget.like!.refLow!, decimals: 2),
  );
  late final _high = TextEditingController(
    text: widget.like?.refHigh == null
        ? ''
        : formatNumber(widget.like!.refHigh!, decimals: 2),
  );
  DateTime? _date = DateTime.now();

  @override
  void dispose() {
    for (final c in [_test, _unit, _value, _low, _high]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final value = parseNumber(_value.text);
    if (_test.text.trim().isEmpty || value == null) {
      showSnack(context, 'Enter the test name and its result.');
      return;
    }
    await ref
        .read(recordsProvider)
        .addLab(
          test: _test.text.trim(),
          value: value,
          unit: _unit.text.trim(),
          refLow: parseNumber(_low.text),
          refHigh: parseNumber(_high.text),
          takenAt: _date ?? DateTime.now(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FormColumn(
      children: [
        Autocomplete<String>(
          initialValue: TextEditingValue(text: _test.text),
          optionsBuilder: (v) {
            final q = v.text.toLowerCase();
            if (q.isEmpty) return const Iterable<String>.empty();
            return commonLabTests.keys.where(
              (t) => t.toLowerCase().contains(q),
            );
          },
          onSelected: (t) {
            _test.text = t;
            if (_unit.text.isEmpty) _unit.text = commonLabTests[t]!;
          },
          fieldViewBuilder: (context, controller, focus, _) {
            return TextField(
              key: const ValueKey('lab-test'),
              controller: controller,
              focusNode: focus,
              onChanged: (v) => _test.text = v,
              autofocus: widget.like == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Test',
                hintText: 'e.g. HbA1c',
              ),
            );
          },
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: NumberField(
                key: const ValueKey('lab-value'),
                controller: _value,
                label: 'Result',
                autofocus: widget.like != null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
            ),
          ],
        ),
        const FieldLabel('Reference range (optional)'),
        Row(
          children: [
            Expanded(
              child: NumberField(controller: _low, label: 'Low'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberField(controller: _high, label: 'High'),
            ),
          ],
        ),
        DateField(
          label: 'Date taken',
          value: _date,
          onChanged: (d) => setState(() => _date = d),
        ),
        FilledButton(
          key: const ValueKey('lab-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Bloodwork: the latest value of each test (tap for its trend), plus the
/// lab report documents.
class LabsScreen extends ConsumerWidget {
  const LabsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(recordsProvider);
    final c = context.colors;
    final reports = recordKind('lab_report');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lab results'),
        actions: [
          IconButton(
            tooltip: 'Add result',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => showLabSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: PageBody(
        children: [
          const SizedBox(height: 8),
          StreamHost<List<LabResult>>(
            create: repo.watchLabs,
            builder: (context, labs) {
              if (labs.isEmpty) {
                return EmptyState(
                  icon: LucideIcons.flaskConical,
                  title: 'No results yet',
                  message:
                      'Add values from your blood tests to see how each '
                      'one changes over time.',
                  action: FilledButton.icon(
                    onPressed: () => showLabSheet(context),
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Add result'),
                  ),
                );
              }
              // Newest first, so the first one seen per test is the latest.
              final latest = <String, LabResult>{};
              final counts = <String, int>{};
              for (final l in labs) {
                latest.putIfAbsent(l.test, () => l);
                counts[l.test] = (counts[l.test] ?? 0) + 1;
              }
              final tests = latest.keys.toList()..sort();
              return TileGroup(
                children: [
                  for (final t in tests)
                    RowTile(
                      title: t,
                      subtitle:
                          '${friendlyDate(latest[t]!.takenAt)}'
                          '${counts[t]! > 1 ? ' · ${counts[t]} results' : ''}',
                      trailing: Text(
                        '${formatNumber(latest[t]!.value, decimals: 2)} '
                        '${latest[t]!.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: rangePosition(latest[t]!) == 0
                              ? c.fg
                              : c.warning,
                        ),
                      ),
                      onTap: () => pushPage(context, LabTestScreen(test: t)),
                    ),
                ],
              );
            },
          ),
          const SectionHeader('Reports'),
          TileGroup(
            children: [
              RowTile(
                icon: reports.icon,
                title: reports.plural,
                subtitle: 'PDFs and photos of full reports',
                onTap: () => pushPage(context, RecordsScreen(kind: reports)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One test over time.
class LabTestScreen extends ConsumerWidget {
  const LabTestScreen({super.key, required this.test});

  final String test;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(recordsProvider);
    final c = context.colors;
    return StreamHost<List<LabResult>>(
      create: () => repo.watchLabTest(test),
      builder: (context, series) {
        final last = series.lastOrNull;
        return Scaffold(
          appBar: AppBar(
            title: Text(test),
            actions: [
              IconButton(
                tooltip: 'Add result',
                icon: const Icon(LucideIcons.plus),
                onPressed: () => showLabSheet(context, like: last),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: last == null
              ? const SizedBox.shrink()
              : PageBody(
                  children: [
                    const SizedBox(height: 8),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stat(
                            label: 'Latest · ${friendlyDate(last.takenAt)}',
                            value: formatNumber(last.value, decimals: 2),
                            unit: last.unit,
                            color: rangePosition(last) == 0 ? null : c.warning,
                          ),
                          if (formatRange(last).isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Reference range ${formatRange(last)} '
                                '${last.unit}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: c.fgTertiary,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TrendChart(
                            points: [
                              for (final l in series)
                                (at: l.takenAt.toLocal(), value: l.value),
                            ],
                            decimals: 2,
                            bandLow: last.refLow,
                            bandHigh: last.refHigh,
                          ),
                        ],
                      ),
                    ),
                    const SectionHeader('History'),
                    TileGroup(
                      children: [
                        for (final l in series.reversed)
                          RowTile(
                            title:
                                '${formatNumber(l.value, decimals: 2)} '
                                '${l.unit}',
                            subtitle: [
                              friendlyDate(l.takenAt),
                              if (rangePosition(l) < 0) 'below range',
                              if (rangePosition(l) > 0) 'above range',
                            ].join(' · '),
                            trailing: IconButton(
                              tooltip: 'Delete',
                              icon: Icon(
                                LucideIcons.trash2,
                                size: 18,
                                color: c.fgTertiary,
                              ),
                              onPressed: () async {
                                if (await confirmDelete(
                                  context,
                                  'this result',
                                )) {
                                  await repo.deleteLab(l.id);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}
