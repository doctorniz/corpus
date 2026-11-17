import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/units.dart';
import '../../data/nutrition_repository.dart';
import '../../data/settings_repository.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';
import '../fitness/workout_form.dart';
import '../habits/habits_screen.dart';
import '../health/labs_screen.dart';
import '../health/record_kinds.dart';
import '../health/records_screen.dart';
import '../health/vitals_screen.dart';
import '../nutrition/food_search.dart';
import '../sleep/sleep_screen.dart';
import '../womens/womens_screen.dart';

class _Action {
  const _Action(this.label, this.icon, this.run);
  final String label;
  final IconData icon;
  final void Function(BuildContext context, WidgetRef ref) run;
}

/// The + button: one place to log anything, from any tab.
Future<void> showCaptureSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Log something',
    child: Consumer(
      builder: (sheet, ref, _) {
        final showWomens =
            ref.watch(settingProvider(SettingKey.showWomens)) != 'false';

        // Each action closes this sheet, then opens its own form from the
        // page underneath (the sheet's own context is gone by then).
        void then(void Function() open) {
          Navigator.pop(sheet);
          open();
        }

        final actions = <_Action>[
          _Action(
            'Food',
            LucideIcons.utensils,
            (_, _) => then(
              () => pushPage(
                context,
                FoodSearchScreen(
                  day: DateTime.now(),
                  slot: slotForTime(DateTime.now()),
                ),
              ),
            ),
          ),
          _Action('Water', LucideIcons.glassWater, (_, ref) {
            ref
                .read(measurementsProvider)
                .add(type: MeasurementType.water, value: 250);
            Navigator.pop(sheet);
            showSnack(context, 'Added 250 ml of water');
          }),
          _Action(
            'Workout',
            LucideIcons.dumbbell,
            (_, _) => then(() => pushPage(context, const WorkoutFormScreen())),
          ),
          _Action(
            'Sleep',
            LucideIcons.moon,
            (_, _) => then(() => showSleepSheet(context)),
          ),
          _Action(
            'Weight',
            LucideIcons.scale,
            (_, _) =>
                then(() => showVitalSheet(context, MeasurementType.weight)),
          ),
          _Action(
            'Blood pressure',
            LucideIcons.activity,
            (_, _) => then(() => showBloodPressureSheet(context)),
          ),
          _Action(
            'Other vital',
            LucideIcons.gauge,
            (_, _) => then(() => showVitalPicker(context)),
          ),
          _Action(
            'Habits',
            LucideIcons.circleCheck,
            (_, _) => then(() => pushPage(context, const HabitsScreen())),
          ),
          if (showWomens)
            _Action(
              'Period',
              LucideIcons.droplet,
              (_, _) => then(
                () => showCycleDaySheet(context, dateOnly(DateTime.now())),
              ),
            ),
          _Action(
            'Lab result',
            LucideIcons.flaskConical,
            (_, _) => then(() => showLabSheet(context)),
          ),
          _Action(
            'Health record',
            LucideIcons.filePlus,
            (_, _) => then(() => _showRecordKindPicker(context)),
          ),
        ];

        return GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            for (final a in actions)
              _ActionTile(action: a, onTap: () => a.run(sheet, ref)),
          ],
        );
      },
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action, required this.onTap});

  final _Action action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      key: ValueKey('capture-${action.label.toLowerCase()}'),
      padding: const EdgeInsets.all(8),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(action.icon, size: 24, color: c.accent),
          const SizedBox(height: 8),
          Text(
            action.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Which section of the health booklet a new record belongs to.
Future<void> _showRecordKindPicker(BuildContext context) {
  return showAppSheet<void>(
    context,
    title: 'Add to my record',
    child: TileGroup(
      children: [
        for (final kind in recordKinds)
          RowTile(
            icon: kind.icon,
            title: kind.plural,
            onTap: () {
              Navigator.pop(context);
              pushPage(context, RecordFormScreen(kind: kind));
            },
          ),
      ],
    ),
  );
}
