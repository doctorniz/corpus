import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/db/database.dart';
import '../../core/units.dart';

final _recentProvider = StreamProvider<List<Measurement>>((ref) async* {
  final profile = await ref.watch(currentProfileProvider.future);
  yield* ref.watch(measurementsRepositoryProvider).watchRecent(profile.id);
});

/// Today view. For now: a quick-add for weight and a list of recent
/// measurements, which proves the full UI → repository → SQLite path.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(_recentProvider);
    final fmt = DateFormat.yMMMd().add_Hm();

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _logWeight(context, ref),
        icon: const Icon(Icons.monitor_weight_outlined),
        label: const Text('Log weight'),
      ),
      body: recent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load data: $e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('Nothing logged yet.'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final m = items[i];
                  return ListTile(
                    leading: const Icon(Icons.monitor_weight_outlined),
                    title: Text('${m.value.toStringAsFixed(1)} ${m.unit}'),
                    subtitle: Text(fmt.format(m.measuredAt.toLocal())),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _logWeight(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              double.tryParse(controller.text.replaceAll(',', '.')),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value <= 0) return;

    final profile = await ref.read(currentProfileProvider.future);
    await ref
        .read(measurementsRepositoryProvider)
        .add(
          profileId: profile.id,
          type: MeasurementType.weight,
          value: value,
          unit: CanonicalUnit.mass,
        );
  }
}
