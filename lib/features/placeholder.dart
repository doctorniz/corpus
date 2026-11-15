import 'package:material_ui/material_ui.dart';

/// Temporary body for modules not yet built. Lists the planned MVP scope
/// from docs/FEATURES.md so the shell is navigable end to end.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.planned,
  });

  final String title;
  final IconData icon;
  final List<String> planned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Coming in the MVP', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in planned)
            ListTile(
              dense: true,
              leading: const Icon(Icons.radio_button_unchecked, size: 18),
              title: Text(item),
            ),
        ],
      ),
    );
  }
}
