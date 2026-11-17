import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';
import '../../ui/widgets.dart';
import 'labs_screen.dart';
import 'record_kinds.dart';
import 'records_screen.dart';
import 'vitals_screen.dart';

/// The health booklet: a summary of what matters in an emergency, then
/// every section of the record.
class HealthScreen extends ConsumerWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(recordsProvider);
    final measurements = ref.watch(measurementsProvider);
    final c = context.colors;

    Widget kindTile(RecordKind kind, Map<String, int> counts) {
      final n = counts[kind.id] ?? 0;
      return RowTile(
        key: ValueKey('section-${kind.id}'),
        icon: kind.icon,
        title: kind.plural,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (n > 0) Pill('$n'),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 18, color: c.fgMuted),
          ],
        ),
        onTap: () => pushPage(context, RecordsScreen(kind: kind)),
      );
    }

    return Scaffold(
      appBar: const Masthead('Health'),
      body: PageBody(
        children: [
          StreamHost<List<HealthRecord>>(
            create: () => records.watchKind('allergy'),
            builder: (context, allergies) => StreamHost<List<HealthRecord>>(
              create: () => records.watchKind('medication'),
              builder: (context, meds) {
                final current = meds
                    .where((m) => m.status != 'Stopped')
                    .toList();
                if (allergies.isEmpty && current.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (allergies.isNotEmpty) ...[
                          _SummaryLine(
                            icon: LucideIcons.triangleAlert,
                            color: c.danger,
                            label: 'Allergies',
                            value: allergies.map((a) => a.title).join(', '),
                          ),
                        ],
                        if (allergies.isNotEmpty && current.isNotEmpty)
                          const SizedBox(height: 12),
                        if (current.isNotEmpty)
                          _SummaryLine(
                            icon: LucideIcons.pill,
                            color: c.accent,
                            label: 'Current medications',
                            value: current.map((m) => m.title).join(', '),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SectionHeader('Vitals'),
          StreamHost<Map<String, Measurement>>(
            create: () => measurements.watchLatest(const [
              MeasurementType.weight,
              MeasurementType.bpSystolic,
              MeasurementType.bpDiastolic,
              MeasurementType.restingHr,
            ]),
            builder: (context, latest) {
              final w = latest[MeasurementType.weight];
              final s = latest[MeasurementType.bpSystolic];
              final d = latest[MeasurementType.bpDiastolic];
              final hr = latest[MeasurementType.restingHr];
              return AppCard(
                onTap: () => pushPage(context, const VitalsScreen()),
                child: Row(
                  children: [
                    Expanded(
                      child: Stat(
                        label: 'Weight',
                        value: w == null
                            ? '–'
                            : formatNumber(w.value, decimals: 1),
                        unit: w == null ? null : 'kg',
                      ),
                    ),
                    Expanded(
                      child: Stat(
                        label: 'Blood pressure',
                        value: s == null || d == null
                            ? '–'
                            : '${s.value.round()}/${d.value.round()}',
                      ),
                    ),
                    Expanded(
                      child: Stat(
                        label: 'Resting HR',
                        value: hr == null ? '–' : '${hr.value.round()}',
                        unit: hr == null ? null : 'bpm',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SectionHeader('My record'),
          StreamHost<Map<String, int>>(
            create: records.watchCounts,
            builder: (context, counts) => Column(
              children: [
                TileGroup(
                  children: [
                    for (final id in ['condition', 'medication', 'allergy'])
                      kindTile(recordKind(id), counts),
                    kindTile(recordKind('surgery'), counts),
                    kindTile(recordKind('vaccination'), counts),
                  ],
                ),
                const SizedBox(height: 12),
                TileGroup(
                  children: [
                    RowTile(
                      key: const ValueKey('section-labs'),
                      icon: LucideIcons.flaskConical,
                      title: 'Lab results',
                      onTap: () => pushPage(context, const LabsScreen()),
                    ),
                    kindTile(recordKind('scan'), counts),
                    kindTile(recordKind('letter'), counts),
                  ],
                ),
                const SizedBox(height: 12),
                TileGroup(
                  children: [
                    kindTile(recordKind('appointment'), counts),
                    kindTile(recordKind('specialist'), counts),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.fgTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
