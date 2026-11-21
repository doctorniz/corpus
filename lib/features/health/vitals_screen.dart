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

/// Log one value of [type] (weight, temperature, ...).
Future<void> showVitalSheet(BuildContext context, String type) {
  final kind = MeasurementType.kinds[type]!;
  return showAppSheet<void>(
    context,
    title: kind.label,
    child: _VitalForm(kind: kind),
  );
}

class _VitalForm extends ConsumerStatefulWidget {
  const _VitalForm({required this.kind});

  final MeasurementKind kind;

  @override
  ConsumerState<_VitalForm> createState() => _VitalFormState();
}

class _VitalFormState extends ConsumerState<_VitalForm> {
  final _value = TextEditingController();
  DateTime _at = DateTime.now();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = parseNumber(_value.text);
    if (v == null || v <= 0) {
      showSnack(context, 'Enter a number.');
      return;
    }
    await ref
        .read(measurementsProvider)
        .add(type: widget.kind.type, value: v, measuredAt: _at);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FormColumn(
      children: [
        NumberField(
          key: const ValueKey('vital-value'),
          controller: _value,
          label: widget.kind.label,
          suffix: widget.kind.unit,
          decimal: widget.kind.decimals > 0,
          autofocus: true,
        ),
        DateTimeField(
          label: 'When',
          value: _at,
          onChanged: (d) => setState(() => _at = d),
        ),
        FilledButton(
          key: const ValueKey('vital-save'),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

Future<void> showBloodPressureSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Blood pressure',
    child: const _BloodPressureForm(),
  );
}

class _BloodPressureForm extends ConsumerStatefulWidget {
  const _BloodPressureForm();

  @override
  ConsumerState<_BloodPressureForm> createState() => _BloodPressureState();
}

class _BloodPressureState extends ConsumerState<_BloodPressureForm> {
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  DateTime _at = DateTime.now();

  @override
  void dispose() {
    _sys.dispose();
    _dia.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = int.tryParse(_sys.text);
    final d = int.tryParse(_dia.text);
    if (s == null || d == null || s <= d) {
      showSnack(context, 'Enter both numbers, the higher one first.');
      return;
    }
    await ref
        .read(measurementsProvider)
        .addBloodPressure(systolic: s, diastolic: d, measuredAt: _at);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return FormColumn(
      children: [
        Row(
          children: [
            Expanded(
              child: NumberField(
                controller: _sys,
                label: 'Systolic',
                suffix: 'mmHg',
                decimal: false,
                autofocus: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberField(
                controller: _dia,
                label: 'Diastolic',
                suffix: 'mmHg',
                decimal: false,
              ),
            ),
          ],
        ),
        DateTimeField(
          label: 'When',
          value: _at,
          onChanged: (d) => setState(() => _at = d),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// Pick which vital to log.
Future<void> showVitalPicker(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Log a vital',
    child: TileGroup(
      children: [
        RowTile(
          icon: LucideIcons.activity,
          title: 'Blood pressure',
          onTap: () {
            Navigator.pop(context);
            showBloodPressureSheet(context);
          },
        ),
        for (final type in MeasurementType.vitals)
          RowTile(
            icon: LucideIcons.gauge,
            title: MeasurementType.kinds[type]!.label,
            onTap: () {
              Navigator.pop(context);
              showVitalSheet(context, type);
            },
          ),
      ],
    ),
  );
}

String formatMeasurement(Measurement m) {
  final kind = MeasurementType.kinds[m.type];
  return '${formatNumber(m.value, decimals: kind?.decimals ?? 1)} ${m.unit}';
}

/// Latest value of every vital; tap one for its history and trend.
class VitalsScreen extends ConsumerWidget {
  const VitalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(measurementsProvider);
    const types = [
      ...MeasurementType.vitals,
      MeasurementType.bpSystolic,
      MeasurementType.bpDiastolic,
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitals'),
        actions: [
          IconButton(
            tooltip: 'Log a vital',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => showVitalPicker(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamHost<Map<String, Measurement>>(
        create: () => repo.watchLatest(types),
        builder: (context, latest) {
          final sys = latest[MeasurementType.bpSystolic];
          final dia = latest[MeasurementType.bpDiastolic];
          return PageBody(
            children: [
              const SizedBox(height: 8),
              TileGroup(
                children: [
                  RowTile(
                    icon: LucideIcons.activity,
                    title: 'Blood pressure',
                    subtitle: sys == null
                        ? 'Not recorded'
                        : friendlyDateTime(sys.measuredAt),
                    trailing: sys == null || dia == null
                        ? null
                        : Text(
                            '${sys.value.round()}/${dia.value.round()} mmHg',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                    onTap: () => pushPage(
                      context,
                      const VitalHistoryScreen(
                        type: MeasurementType.bpSystolic,
                      ),
                    ),
                  ),
                  for (final type in MeasurementType.vitals)
                    RowTile(
                      icon: LucideIcons.gauge,
                      title: MeasurementType.kinds[type]!.label,
                      subtitle: latest[type] == null
                          ? 'Not recorded'
                          : friendlyDateTime(latest[type]!.measuredAt),
                      trailing: latest[type] == null
                          ? null
                          : Text(
                              formatMeasurement(latest[type]!),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      onTap: () =>
                          pushPage(context, VitalHistoryScreen(type: type)),
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

/// Trend chart and full list for one vital. Blood pressure shows both
/// numbers together.
class VitalHistoryScreen extends ConsumerWidget {
  const VitalHistoryScreen({super.key, required this.type});

  final String type;

  bool get _isBp => type == MeasurementType.bpSystolic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(measurementsProvider);
    final kind = MeasurementType.kinds[type]!;
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isBp ? 'Blood pressure' : kind.label),
        actions: [
          IconButton(
            tooltip: 'Add',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _isBp
                ? showBloodPressureSheet(context)
                : showVitalSheet(context, type),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamHost<List<Measurement>>(
        create: () => repo.watchRecent(
          _isBp ? [type, MeasurementType.bpDiastolic] : [type],
          limit: 1000,
        ),
        builder: (context, all) {
          final main = all.where((m) => m.type == type).toList();
          if (main.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: LucideIcons.gauge,
                title: 'No readings yet',
                message: 'Tap + to add one.',
              ),
            );
          }
          final diastolic = {
            for (final m in all)
              if (m.type == MeasurementType.bpDiastolic) m.measuredAt: m,
          };
          return PageBody(
            children: [
              const SizedBox(height: 8),
              AppCard(
                child: TrendChart(
                  points: [
                    for (final m in main.reversed)
                      (at: m.measuredAt.toLocal(), value: m.value),
                  ],
                  decimals: kind.decimals,
                ),
              ),
              const SectionHeader('History'),
              TileGroup(
                children: [
                  for (final m in main)
                    RowTile(
                      title: _isBp && diastolic[m.measuredAt] != null
                          ? '${m.value.round()}/'
                                '${diastolic[m.measuredAt]!.value.round()} mmHg'
                          : formatMeasurement(m),
                      subtitle:
                          friendlyDateTime(m.measuredAt) +
                          (m.source == 'health' ? ' · from health data' : ''),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: Icon(
                          LucideIcons.trash2,
                          size: 18,
                          color: c.fgTertiary,
                        ),
                        onPressed: () async {
                          if (!await confirmDelete(context, 'this reading')) {
                            return;
                          }
                          await repo.delete(m.id);
                          final pair = diastolic[m.measuredAt];
                          if (_isBp && pair != null) await repo.delete(pair.id);
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
