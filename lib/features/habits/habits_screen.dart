import 'package:material_ui/material_ui.dart';

import '../placeholder.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholder(
    title: 'Habits',
    icon: Icons.check_circle_outline,
    planned: [
      'Habits (yes/no, count, duration)',
      'Check-ins & streaks',
      'Completion calendar',
      'Daily mood / energy / stress',
    ],
  );
}
