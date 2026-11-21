import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../app/theme.dart';

/// A bordered, softly-filled panel: the basic container on every screen.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
    return Material(
      color: c.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: context.colors.fgTertiary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A big number with a small label, e.g. "7h 42m / Last night".
class Stat extends StatelessWidget {
  const Stat({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });

  final String label;
  final String value;
  final String? unit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: c.fgTertiary)),
        const SizedBox(height: 2),
        Text.rich(
          TextSpan(
            text: value,
            children: [
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.fgTertiary,
                  ),
                ),
            ],
          ),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: color ?? c.fg,
          ),
        ),
      ],
    );
  }
}

/// A row of [Stat]s inside one card.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.stats});

  final List<Stat> stats;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(children: [for (final s in stats) Expanded(child: s)]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: c.fgMuted),
          const SizedBox(height: 12),
          Text(title, style: context.text.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.fgTertiary, fontSize: 14),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// A list row inside an [AppCard] group.
class RowTile extends StatelessWidget {
  const RowTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor ?? c.fgSecondary),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(fontSize: 13, color: c.fgTertiary),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            if (trailing == null && onTap != null)
              Icon(LucideIcons.chevronRight, size: 18, color: c.fgMuted),
          ],
        ),
      ),
    );
  }
}

/// Rows separated by hairlines, inside one card.
class TileGroup extends StatelessWidget {
  const TileGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 14),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Small pill used for counts and statuses.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = color ?? c.fgSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color == null ? c.bgTertiary : fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Standard page body: a padded, scrollable column, kept to a readable
/// width on tablets and desktop.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: children,
        ),
      ),
    );
  }
}

/// Shows a stream's value, or a quiet loading / error state.
class Loaded<T> extends StatelessWidget {
  const Loaded({super.key, required this.stream, required this.builder});

  final Stream<T> stream;
  final Widget Function(BuildContext, T) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Something went wrong: ${snap.error}',
              style: TextStyle(color: context.colors.danger),
            ),
          );
        }
        if (!snap.hasData) return const SizedBox(height: 80);
        return builder(context, snap.data as T);
      },
    );
  }
}

/// Keeps one stream subscription alive across rebuilds.
class StreamHost<T> extends StatefulWidget {
  const StreamHost({super.key, required this.create, required this.builder});

  final Stream<T> Function() create;
  final Widget Function(BuildContext, T) builder;

  @override
  State<StreamHost<T>> createState() => _StreamHostState<T>();
}

class _StreamHostState<T> extends State<StreamHost<T>> {
  late final Stream<T> _stream = widget.create();

  @override
  Widget build(BuildContext context) =>
      Loaded<T>(stream: _stream, builder: widget.builder);
}

final _dayFormat = DateFormat('EEE d MMM');
final _dayYearFormat = DateFormat('d MMM y');
final _timeFormat = DateFormat.Hm();

/// "Today", "Yesterday", or a short date.
String friendlyDay(DateTime t) {
  final l = t.toLocal();
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(l.year, l.month, l.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (l.year == now.year) return _dayFormat.format(l);
  return _dayYearFormat.format(l);
}

String friendlyDate(DateTime t) => _dayYearFormat.format(t.toLocal());
String friendlyTime(DateTime t) => _timeFormat.format(t.toLocal());
String friendlyDateTime(DateTime t) => '${friendlyDay(t)}, ${friendlyTime(t)}';

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $what?'),
      content: const Text('This cannot be undone from the app.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Delete', style: TextStyle(color: context.colors.danger)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(
    context,
    rootNavigator: true,
  ).push<T>(MaterialPageRoute(builder: (_) => page));
}
