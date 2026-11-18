import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

/// Top bar for a tab, laid out like Mentis's masthead: the menu on the left,
/// then the title over a quiet subtitle (today's date), then any actions.
class Masthead extends StatelessWidget implements PreferredSizeWidget {
  const Masthead(this.title, {super.key, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        key: const ValueKey('menu'),
        tooltip: 'Menu',
        icon: const Icon(LucideIcons.menu, size: 22),
        onPressed: () => showMainMenu(context),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          Text(
            _mastheadDate.format(DateTime.now()),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: c.fgTertiary,
            ),
          ),
        ],
      ),
      actions: [...actions, const SizedBox(width: 4)],
    );
  }
}

final _mastheadDate = DateFormat('EEEE d MMMM');

/// Mentis's main menu: a drawer from the left with every area, the theme
/// switch and Settings.
Future<void> showMainMenu(BuildContext context) {
  final location = GoRouterState.of(context).uri.path;
  final router = GoRouter.of(context);
  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierLabel: 'Close menu',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (context, animation, _, child) => SlideTransition(
      position: Tween(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
    pageBuilder: (menu, _, _) => _MainMenu(
      location: location,
      goTab: (path) {
        Navigator.pop(menu);
        router.go(path);
      },
      push: (page) {
        Navigator.pop(menu);
        pushPage(context, page);
      },
    ),
  );
}

class _MainMenu extends ConsumerWidget {
  const _MainMenu({
    required this.location,
    required this.goTab,
    required this.push,
  });

  final String location;
  final void Function(String path) goTab;
  final void Function(Widget page) push;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final mode = ref.watch(themeModeProvider);
    final showWomens =
        ref.watch(settingProvider(SettingKey.showWomens)) != 'false';
    final width = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 320.0);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: c.bgSecondary,
        elevation: 8,
        shape: Border(right: BorderSide(color: c.border)),
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: SafeArea(
            right: false,
            child: Column(
              children: [
                // Header: the app's mark, its name and what it is.
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c.accentLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          LucideIcons.heartPulse,
                          size: 20,
                          color: c.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Corpus',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.fg,
                              ),
                            ),
                            Text(
                              'Health booklet',
                              style: TextStyle(
                                fontSize: 12,
                                color: c.fgTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close menu',
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final t in tabs)
                        _MenuItem(
                          icon: t.icon,
                          label: t.label,
                          active: location.startsWith(t.path),
                          onTap: () => goTab(t.path),
                        ),
                      _MenuItem(
                        icon: LucideIcons.circleCheck,
                        label: 'Habits',
                        onTap: () => push(const HabitsScreen()),
                      ),
                      if (showWomens)
                        _MenuItem(
                          icon: LucideIcons.droplet,
                          label: "Women's health",
                          onTap: () => push(const WomensScreen()),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: Column(
                    children: [
                      _ThemeSwitch(
                        mode: mode,
                        onChanged: (m) => ref
                            .read(settingsRepoProvider)
                            .set(SettingKey.themeMode, m.name),
                      ),
                      const SizedBox(height: 4),
                      _MenuItem(
                        icon: LucideIcons.settings,
                        label: 'Settings',
                        onTap: () => push(const SettingsScreen()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = active ? c.accent : c.fgSecondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active ? c.accent.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: fg,
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
}

/// Light / System / Dark as three icons on a grey track.
class _ThemeSwitch extends StatelessWidget {
  const _ThemeSwitch({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  static const _options = [
    (ThemeMode.light, LucideIcons.sun, 'Light'),
    (ThemeMode.system, LucideIcons.monitor, 'System'),
    (ThemeMode.dark, LucideIcons.moon, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.bgTertiary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (final (value, icon, label) in _options)
            Expanded(
              child: Semantics(
                selected: mode == value,
                button: true,
                label: label,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: mode == value ? c.bg : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: mode == value
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      icon,
                      size: 16,
                      color: mode == value ? c.fg : c.fgTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
