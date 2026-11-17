import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';
import '../../data/nutrition_repository.dart';
import '../../data/settings_repository.dart';
import '../../ui/charts.dart';
import '../../ui/widgets.dart';
import 'food_search.dart';

/// A day's food diary: totals against targets, meals by slot, and water.
class NutritionScreen extends ConsumerStatefulWidget {
  const NutritionScreen({super.key});

  @override
  ConsumerState<NutritionScreen> createState() => _NutritionState();
}

class _NutritionState extends ConsumerState<NutritionScreen> {
  DateTime _day = dateOnly(DateTime.now());

  bool get _isToday => dayKey(_day) == dayKey(DateTime.now());

  void _shift(int days) =>
      setState(() => _day = DateTime(_day.year, _day.month, _day.day + days));

  void _add(String slot) =>
      pushPage(context, FoodSearchScreen(day: _day, slot: slot));

  @override
  Widget build(BuildContext context) {
    final nutrition = ref.watch(nutritionProvider);
    final measurements = ref.watch(measurementsProvider);
    final c = context.colors;
    final kcalTarget = numSetting(ref, SettingKey.kcalTarget, 2000);
    final proteinTarget = numSetting(ref, SettingKey.proteinTarget, 100);
    final carbsTarget = numSetting(ref, SettingKey.carbsTarget, 250);
    final fatTarget = numSetting(ref, SettingKey.fatTarget, 70);
    final waterTarget = numSetting(ref, SettingKey.waterTarget, 2000);

    return Scaffold(
      appBar: Masthead(
        'Nutrition',
        actions: [
          IconButton(
            key: const ValueKey('nutrition-add'),
            tooltip: 'Add food',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _add(slotForTime(DateTime.now())),
          ),
        ],
      ),
      body: PageBody(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Previous day',
                icon: const Icon(LucideIcons.chevronLeft),
                onPressed: () => _shift(-1),
              ),
              SizedBox(
                width: 140,
                child: Text(
                  friendlyDay(_day),
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                icon: const Icon(LucideIcons.chevronRight),
                onPressed: _isToday ? null : () => _shift(1),
              ),
            ],
          ),
          StreamHost<List<MealEntry>>(
            key: ValueKey(dayKey(_day)),
            create: () => nutrition.watchDay(_day),
            builder: (context, entries) {
              double sum(double Function(MealEntry) f) =>
                  entries.fold(0.0, (a, e) => a + f(e));
              final kcal = sum((e) => e.kcal);
              final left = kcalTarget - kcal;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Stat(
                                label: 'Eaten',
                                value: '${kcal.round()}',
                                unit: 'kcal',
                              ),
                            ),
                            Text(
                              left >= 0
                                  ? '${left.round()} left of '
                                        '${kcalTarget.round()}'
                                  : '${(-left).round()} over '
                                        '${kcalTarget.round()}',
                              style: TextStyle(
                                fontSize: 13,
                                color: left >= 0 ? c.fgTertiary : c.warning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Bar(
                          value: kcal / kcalTarget,
                          color: left >= 0 ? c.accent : c.warning,
                          height: 8,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _Macro(
                              'Protein',
                              sum((e) => e.protein),
                              proteinTarget,
                              c.blue,
                            ),
                            const SizedBox(width: 12),
                            _Macro(
                              'Carbs',
                              sum((e) => e.carbs),
                              carbsTarget,
                              c.success,
                            ),
                            const SizedBox(width: 12),
                            _Macro(
                              'Fat',
                              sum((e) => e.fat),
                              fatTarget,
                              c.warning,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  for (final slot in mealSlots)
                    _SlotSection(
                      slot: slot,
                      entries: entries.where((e) => e.slot == slot).toList(),
                      onAdd: () => _add(slot),
                      onDelete: (e) => nutrition.deleteEntry(e.id),
                    ),
                ],
              );
            },
          ),
          const SectionHeader('Water'),
          StreamHost<double>(
            key: ValueKey('water-${dayKey(_day)}'),
            create: () =>
                measurements.watchDayTotal(MeasurementType.water, _day),
            builder: (context, ml) => AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Stat(
                          label: 'of ${waterTarget.round()} ml',
                          value: '${ml.round()}',
                          unit: 'ml',
                        ),
                      ),
                      for (final amount in [250, 500])
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: OutlinedButton(
                            key: ValueKey('water-$amount'),
                            onPressed: () => measurements.add(
                              type: MeasurementType.water,
                              value: amount.toDouble(),
                              measuredAt: _isToday
                                  ? DateTime.now()
                                  : _day.add(const Duration(hours: 12)),
                            ),
                            child: Text('+$amount'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Bar(value: ml / waterTarget, color: c.blue, height: 8),
                ],
              ),
            ),
          ),
          const SectionHeader('Energy · last 14 days'),
          StreamHost<Map<String, double>>(
            create: () => nutrition.watchDailyKcal(
              dateOnly(DateTime.now()).subtract(const Duration(days: 14)),
            ),
            builder: (context, byDay) => AppCard(
              child: DayBarChart(
                days: lastDays(14, (d) => byDay[dayKey(d)] ?? 0),
                target: kcalTarget,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color, this.height = 6});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.isFinite ? value.clamp(0.0, 1.0) : 0,
        minHeight: height,
        color: color,
        backgroundColor: context.colors.bgTertiary,
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro(this.label, this.grams, this.target, this.color);

  final String label;
  final double grams;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.fgTertiary)),
          const SizedBox(height: 2),
          Text(
            '${grams.round()} / ${target.round()} g',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          _Bar(value: grams / target, color: color),
        ],
      ),
    );
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.slot,
    required this.entries,
    required this.onAdd,
    required this.onDelete,
  });

  final String slot;
  final List<MealEntry> entries;
  final VoidCallback onAdd;
  final ValueChanged<MealEntry> onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final kcal = entries.fold(0.0, (a, e) => a + e.kcal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          entries.isEmpty
              ? slotLabel(slot)
              : '${slotLabel(slot)} · ${kcal.round()} kcal',
        ),
        TileGroup(
          children: [
            for (final e in entries)
              RowTile(
                title: e.name,
                subtitle: [
                  if (e.grams != null) '${formatNumber(e.grams!)} g',
                  'P ${e.protein.round()} · C ${e.carbs.round()} · '
                      'F ${e.fat.round()}',
                ].join(' · '),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${e.kcal.round()}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(LucideIcons.x, size: 16, color: c.fgTertiary),
                      onPressed: () => onDelete(e),
                    ),
                  ],
                ),
              ),
            RowTile(
              key: ValueKey('add-$slot'),
              icon: LucideIcons.plus,
              iconColor: c.accent,
              title: 'Add food',
              trailing: const SizedBox.shrink(),
              onTap: onAdd,
            ),
          ],
        ),
      ],
    );
  }
}
