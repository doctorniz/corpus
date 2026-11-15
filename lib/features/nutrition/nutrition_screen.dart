import 'package:material_ui/material_ui.dart';

import '../placeholder.dart';

class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholder(
    title: 'Nutrition',
    icon: Icons.restaurant,
    planned: [
      'Meal logging',
      'Offline food database',
      'Custom foods & recipes',
      'Calorie & macro targets',
      'Water intake',
    ],
  );
}
