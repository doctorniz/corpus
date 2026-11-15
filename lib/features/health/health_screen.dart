import 'package:material_ui/material_ui.dart';

import '../placeholder.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) => const ModulePlaceholder(
    title: 'Health booklet',
    icon: Icons.medical_information,
    planned: [
      'Profile & emergency info',
      'Conditions',
      'Medications & dose log',
      'Allergies',
      'Vaccinations',
      'Vitals',
    ],
  );
}
