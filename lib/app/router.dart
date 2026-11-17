import 'package:go_router/go_router.dart';

import '../features/fitness/fitness_screen.dart';
import '../features/health/health_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/sleep/sleep_screen.dart';
import 'shell.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: '/health',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/health', builder: (_, _) => const HealthScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/fitness', builder: (_, _) => const FitnessScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/sleep', builder: (_, _) => const SleepScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/nutrition',
              builder: (_, _) => const NutritionScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
