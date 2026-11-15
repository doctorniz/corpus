import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../features/fitness/fitness_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/health/health_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/today/today_screen.dart';
import 'shell.dart';

class Destination {
  const Destination(this.path, this.label, this.icon, this.builder);
  final String path;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

final destinations = <Destination>[
  Destination('/today', 'Today', Icons.today, (_) => const TodayScreen()),
  Destination(
    '/health',
    'Health',
    Icons.medical_information,
    (_) => const HealthScreen(),
  ),
  Destination(
    '/fitness',
    'Fitness',
    Icons.fitness_center,
    (_) => const FitnessScreen(),
  ),
  Destination(
    '/nutrition',
    'Nutrition',
    Icons.restaurant,
    (_) => const NutritionScreen(),
  ),
  Destination(
    '/habits',
    'Habits',
    Icons.check_circle_outline,
    (_) => const HabitsScreen(),
  ),
];

final router = GoRouter(
  initialLocation: '/today',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        for (final d in destinations)
          StatefulShellBranch(
            routes: [GoRoute(path: d.path, builder: (c, s) => d.builder(c))],
          ),
      ],
    ),
  ],
);
