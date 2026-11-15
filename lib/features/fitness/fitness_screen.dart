import 'package:material_ui/material_ui.dart';

import '../placeholder.dart';

class FitnessScreen extends StatelessWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholder(
    title: 'Fitness',
    icon: Icons.fitness_center,
    planned: [
      'Workout log (sets, reps, weight, RPE)',
      'Exercise library',
      'Workout templates',
      'Cardio sessions',
      'Body measurements',
      'Steps & sleep',
    ],
  );
}
