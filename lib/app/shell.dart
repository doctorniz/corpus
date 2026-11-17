import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../data/settings_repository.dart';
import '../features/capture/capture_sheet.dart';
import '../features/habits/habits_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/womens/womens_screen.dart';
import '../ui/widgets.dart';
import 'providers.dart';
import 'theme.dart';

class TabSpec {
  const TabSpec(this.path, this.label, this.icon);
  final String path;
  final String label;
  final IconData icon;
}

/// The four tabs either side of the + button.
const tabs = <TabSpec>[
  TabSpec('/health', 'Health', LucideIcons.heartPulse),
  TabSpec('/fitness', 'Fitness', LucideIcons.dumbbell),
  TabSpec('/sleep', 'Sleep', LucideIcons.moon),
  TabSpec('/nutrition', 'Nutrition', LucideIcons.utensils),
];

/// Bottom bar: two tabs, the round + (log something), two tabs.
/// Everything else is in the masthead's menu.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget tab(int i) {
      final active = shell.currentIndex == i;
      final color = active ? c.accent : c.fgSecondary;
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          label: tabs[i].label,
          child: InkWell(
            key: ValueKey('tab-${tabs[i].label.toLowerCase()}'),
            onTap: () => _go(i),
            child: SizedBox(
              height: 56,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tabs[i].icon, size: 20, color: color),
                  const SizedBox(height: 2),
                  ExcludeSemantics(
                    child: Text(
                      tabs[i].label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: c.bg,
          border: Border(top: BorderSide(color: c.border)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              // A fixed height: without it the centred + button lets the
              // bar grow to fill the screen.
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 56),
              child: Row(
                children: [
                  tab(0),
                  tab(1),
                  Expanded(
                    child: Center(
                      child: Semantics(
                        button: true,
                        label: 'Log something',
                        child: InkWell(
                          key: const ValueKey('capture'),
                          customBorder: const CircleBorder(),
                          onTap: () => showCaptureSheet(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Icon(
                              LucideIcons.plus,
                              size: 24,
                              color: c.accentFg,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  tab(2),
                  tab(3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Top bar for a tab: its title, any actions, and the menu.
class Masthead extends StatelessWidget implements PreferredSizeWidget {
  const Masthead(this.title, {super.key, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        ...actions,
        IconButton(
          key: const ValueKey('menu'),
          tooltip: 'Menu',
          icon: const Icon(LucideIcons.menu, size: 22),
          onPressed: () => showMenuSheet(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// Everything that is not one of the four tabs.
Future<void> showMenuSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final mode = ref.watch(themeModeProvider);
        final showWomens =
            ref.watch(settingProvider(SettingKey.showWomens)) != 'false';

        void open(Widget page) {
          Navigator.pop(sheet);
          pushPage(context, page);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TileGroup(
                children: [
                  RowTile(
                    icon: LucideIcons.circleCheck,
                    title: 'Habits',
                    onTap: () => open(const HabitsScreen()),
                  ),
                  if (showWomens)
                    RowTile(
                      icon: LucideIcons.droplet,
                      title: "Women's health",
                      onTap: () => open(const WomensScreen()),
                    ),
                  RowTile(
                    icon: LucideIcons.settings,
                    title: 'Settings',
                    onTap: () => open(const SettingsScreen()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(LucideIcons.sun, size: 16),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(LucideIcons.monitor, size: 16),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(LucideIcons.moon, size: 16),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => ref
                      .read(settingsRepoProvider)
                      .set(SettingKey.themeMode, s.first.name),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
