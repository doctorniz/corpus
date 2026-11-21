import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';
import '../../data/nutrition_repository.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';

/// Find a food and log it to [slot] on [day]. Shows recent foods until
/// something is typed. Also the way in to quick-add and custom foods.
class FoodSearchScreen extends ConsumerStatefulWidget {
  const FoodSearchScreen({super.key, required this.day, required this.slot});

  final DateTime day;
  final String slot;

  @override
  ConsumerState<FoodSearchScreen> createState() => _FoodSearchState();
}

class _FoodSearchState extends ConsumerState<FoodSearchScreen> {
  final _query = TextEditingController();
  late String _slot = widget.slot;
  List<Food> _results = const [];
  bool _recent = true;
  Timer? _debounce;

  /// The time to record: now if logging for today, otherwise midday.
  DateTime get _at {
    final now = DateTime.now();
    final d = widget.day;
    if (dayKey(d) == dayKey(now)) return now;
    return DateTime(d.year, d.month, d.day, 12);
  }

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final repo = ref.read(nutritionProvider);
    final trimmed = q.trim();
    final results = trimmed.isEmpty
        ? await repo.recentFoods()
        : await repo.search(trimmed);
    if (!mounted || _query.text.trim() != trimmed) return;
    setState(() {
      _results = results;
      _recent = trimmed.isEmpty;
    });
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _search(q));
  }

  Future<void> _pick(Food food) async {
    final logged = await showAppSheet<bool>(
      context,
      title: food.name,
      child: _PortionForm(food: food, slot: _slot, at: _at),
    );
    if (logged == true && mounted) Navigator.pop(context);
  }

  Future<void> _quickAdd() async {
    final logged = await showAppSheet<bool>(
      context,
      title: 'Quick add',
      child: _QuickAddForm(slot: _slot, at: _at, name: _query.text.trim()),
    );
    if (logged == true && mounted) Navigator.pop(context);
  }

  Future<void> _newFood() async {
    final food = await showAppSheet<Food>(
      context,
      title: 'New food',
      child: _CustomFoodForm(name: _query.text.trim()),
    );
    if (food != null && mounted) await _pick(food);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text('Add to ${slotLabel(_slot).toLowerCase()}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  key: const ValueKey('food-query'),
                  controller: _query,
                  autofocus: true,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search foods',
                    prefixIcon: Icon(LucideIcons.search, size: 18),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final s in mealSlots)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(slotLabel(s)),
                          selected: s == _slot,
                          onSelected: (_) => setState(() => _slot = s),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('food-quick-add'),
                        onPressed: _quickAdd,
                        icon: const Icon(LucideIcons.zap, size: 16),
                        label: const Text('Quick add'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _newFood,
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text('New food'),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          _recent
                              ? 'Search about 8,000 everyday foods, or use '
                                    'Quick add to type in calories yourself.'
                              : 'No foods match. Try fewer words, or add it '
                                    'as a new food.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: c.fgTertiary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _results.length + (_recent ? 1 : 0),
                        separatorBuilder: (_, _) => const Divider(indent: 16),
                        itemBuilder: (context, i) {
                          if (_recent && i == 0) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: SectionHeader('Recent'),
                            );
                          }
                          final f = _results[i - (_recent ? 1 : 0)];
                          return RowTile(
                            title: f.name,
                            subtitle:
                                '${f.kcal.round()} kcal · '
                                'P ${formatNumber(f.protein, decimals: 1)} · '
                                'C ${formatNumber(f.carbs, decimals: 1)} · '
                                'F ${formatNumber(f.fat, decimals: 1)} '
                                'per 100 g'
                                '${f.source == 'custom' ? ' · yours' : ''}',
                            trailing: Icon(
                              LucideIcons.plus,
                              size: 18,
                              color: c.accent,
                            ),
                            onTap: () => _pick(f),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How much of a food was eaten.
class _PortionForm extends ConsumerStatefulWidget {
  const _PortionForm({
    required this.food,
    required this.slot,
    required this.at,
  });

  final Food food;
  final String slot;
  final DateTime at;

  @override
  ConsumerState<_PortionForm> createState() => _PortionFormState();
}

class _PortionFormState extends ConsumerState<_PortionForm> {
  late final _grams = TextEditingController(
    text: formatNumber(widget.food.servingG ?? 100, decimals: 1),
  );

  @override
  void initState() {
    super.initState();
    _grams.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final grams = parseNumber(_grams.text);
    if (grams == null || grams <= 0) {
      showSnack(context, 'Enter an amount in grams.');
      return;
    }
    await ref
        .read(nutritionProvider)
        .logFood(widget.food, grams, slot: widget.slot, at: widget.at);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final factor = (parseNumber(_grams.text) ?? 0) / 100;
    final serving = f.servingG;
    return FormColumn(
      children: [
        NumberField(
          key: const ValueKey('portion-grams'),
          controller: _grams,
          label: 'Amount',
          suffix: 'g',
          autofocus: true,
        ),
        if (serving != null)
          Wrap(
            spacing: 8,
            children: [
              for (final n in [0.5, 1.0, 2.0])
                ActionChip(
                  label: Text(
                    '${formatNumber(n, decimals: 1)} × '
                    '${f.servingLabel ?? 'serving'} '
                    '(${formatNumber(serving * n, decimals: 0)} g)',
                  ),
                  onPressed: () =>
                      _grams.text = formatNumber(serving * n, decimals: 1),
                ),
            ],
          ),
        StatRow(
          stats: [
            Stat(label: 'kcal', value: '${(f.kcal * factor).round()}'),
            Stat(
              label: 'Protein',
              value: formatNumber(f.protein * factor, decimals: 1),
              unit: 'g',
            ),
            Stat(
              label: 'Carbs',
              value: formatNumber(f.carbs * factor, decimals: 1),
              unit: 'g',
            ),
            Stat(
              label: 'Fat',
              value: formatNumber(f.fat * factor, decimals: 1),
              unit: 'g',
            ),
          ],
        ),
        FilledButton(
          key: const ValueKey('portion-save'),
          onPressed: _save,
          child: Text('Add to ${slotLabel(widget.slot).toLowerCase()}'),
        ),
      ],
    );
  }
}

/// Log calories (and optionally macros) without picking a food.
class _QuickAddForm extends ConsumerStatefulWidget {
  const _QuickAddForm({
    required this.slot,
    required this.at,
    required this.name,
  });

  final String slot;
  final DateTime at;
  final String name;

  @override
  ConsumerState<_QuickAddForm> createState() => _QuickAddState();
}

class _QuickAddState extends ConsumerState<_QuickAddForm> {
  late final _name = TextEditingController(text: widget.name);
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final kcal = parseNumber(_kcal.text);
    if (kcal == null) {
      showSnack(context, 'Enter the calories.');
      return;
    }
    await ref
        .read(nutritionProvider)
        .logEntry(
          name: _name.text.trim().isEmpty ? 'Quick add' : _name.text.trim(),
          slot: widget.slot,
          at: widget.at,
          kcal: kcal,
          protein: parseNumber(_protein.text) ?? 0,
          carbs: parseNumber(_carbs.text) ?? 0,
          fat: parseNumber(_fat.text) ?? 0,
        );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return FormColumn(
      children: [
        TextField(
          key: const ValueKey('quick-name'),
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What was it?',
            hintText: 'e.g. Chicken salad',
          ),
        ),
        NumberField(
          key: const ValueKey('quick-kcal'),
          controller: _kcal,
          label: 'Energy',
          suffix: 'kcal',
          autofocus: true,
        ),
        Row(
          children: [
            Expanded(
              child: NumberField(
                controller: _protein,
                label: 'Protein',
                suffix: 'g',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberField(
                controller: _carbs,
                label: 'Carbs',
                suffix: 'g',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberField(controller: _fat, label: 'Fat', suffix: 'g'),
            ),
          ],
        ),
        FilledButton(
          key: const ValueKey('quick-save'),
          onPressed: _save,
          child: Text('Add to ${slotLabel(widget.slot).toLowerCase()}'),
        ),
      ],
    );
  }
}

/// Save a food of your own (values per 100 g) for reuse.
class _CustomFoodForm extends ConsumerStatefulWidget {
  const _CustomFoodForm({required this.name});

  final String name;

  @override
  ConsumerState<_CustomFoodForm> createState() => _CustomFoodState();
}

class _CustomFoodState extends ConsumerState<_CustomFoodForm> {
  late final _name = TextEditingController(text: widget.name);
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _serving = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat, _serving]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final kcal = parseNumber(_kcal.text);
    if (_name.text.trim().isEmpty || kcal == null) {
      showSnack(context, 'Enter a name and the calories per 100 g.');
      return;
    }
    final food = await ref
        .read(nutritionProvider)
        .addCustomFood(
          name: _name.text.trim(),
          kcal: kcal,
          protein: parseNumber(_protein.text) ?? 0,
          carbs: parseNumber(_carbs.text) ?? 0,
          fat: parseNumber(_fat.text) ?? 0,
          servingG: parseNumber(_serving.text),
        );
    if (mounted) Navigator.pop(context, food);
  }

  @override
  Widget build(BuildContext context) {
    return FormColumn(
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        const FieldLabel('Per 100 g'),
        NumberField(controller: _kcal, label: 'Energy', suffix: 'kcal'),
        Row(
          children: [
            Expanded(
              child: NumberField(
                controller: _protein,
                label: 'Protein',
                suffix: 'g',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberField(
                controller: _carbs,
                label: 'Carbs',
                suffix: 'g',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumberField(controller: _fat, label: 'Fat', suffix: 'g'),
            ),
          ],
        ),
        NumberField(
          controller: _serving,
          label: 'Typical serving (optional)',
          suffix: 'g',
        ),
        FilledButton(onPressed: _save, child: const Text('Save food')),
      ],
    );
  }
}
