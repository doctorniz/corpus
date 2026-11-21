import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/units.dart';
import '../../data/settings_repository.dart';
import '../../services/health_sync.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _editTarget(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String label,
    required String unit,
    required double current,
  }) async {
    final controller = TextEditingController(
      text: formatNumber(current, decimals: 1),
    );
    await showAppSheet<void>(
      context,
      title: label,
      child: Builder(
        builder: (sheet) => FormColumn(
          children: [
            NumberField(
              controller: controller,
              label: label,
              suffix: unit,
              autofocus: true,
            ),
            FilledButton(
              onPressed: () async {
                final v = parseNumber(controller.text);
                if (v == null || v <= 0) return;
                await ref.read(settingsRepoProvider).set(key, '$v');
                if (sheet.mounted) Navigator.pop(sheet);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref.read(exportProvider).buildJson();
      final bytes = Uint8List.fromList(utf8.encode(json));
      final name = 'corpus-export-${dayKey(DateTime.now())}.json';
      if (Platform.isAndroid || Platform.isIOS) {
        final saved = await FilePicker.saveFile(
          fileName: name,
          bytes: bytes,
          mimeType: 'application/json',
        );
        if (saved != null && context.mounted) showSnack(context, 'Exported.');
      } else {
        final dir =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final file = File(p.join(dir.path, name));
        await file.writeAsBytes(bytes);
        if (context.mounted) showSnack(context, 'Exported to ${file.path}');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, 'Export failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.read(settingsRepoProvider);
    final sync = ref.watch(healthSyncProvider);
    final syncOn = ref.watch(settingProvider(SettingKey.healthSync)) == 'true';
    final lastSync = DateTime.tryParse(
      ref.watch(settingProvider(SettingKey.healthLastSync)) ?? '',
    );
    final showWomens =
        ref.watch(settingProvider(SettingKey.showWomens)) != 'false';

    Widget target(String key, String label, String unit, double fallback) {
      final value = numSetting(ref, key, fallback);
      return RowTile(
        title: label,
        trailing: Text(
          '${formatNumber(value, decimals: 1)} $unit',
          style: TextStyle(color: c.fgSecondary),
        ),
        onTap: () => _editTarget(
          context,
          ref,
          key: key,
          label: label,
          unit: unit,
          current: value,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          const SectionHeader('Health data sync'),
          if (!HealthSyncService.supported)
            AppCard(
              child: Text(
                'Sync with Apple Health and Health Connect is available on '
                'iPhone and Android.',
                style: TextStyle(color: c.fgTertiary, fontSize: 14),
              ),
            )
          else
            ValueListenableBuilder<bool>(
              valueListenable: sync.syncing,
              builder: (context, syncing, _) => TileGroup(
                children: [
                  RowTile(
                    icon: LucideIcons.refreshCw,
                    title: 'Sync with ${HealthSyncService.storeName}',
                    subtitle:
                        'Brings in steps, workouts, sleep, weight and more '
                        'from your phone and any tracker connected to it, '
                        'and saves what you log here back to it.',
                    trailing: Switch(
                      key: const ValueKey('health-sync-switch'),
                      value: syncOn,
                      onChanged: syncing
                          ? null
                          : (on) async {
                              if (!on) {
                                await sync.disable();
                                return;
                              }
                              final error = await sync.enable();
                              if (error != null && context.mounted) {
                                showSnack(context, error);
                              }
                            },
                    ),
                  ),
                  if (syncOn)
                    RowTile(
                      title: syncing ? 'Syncing…' : 'Sync now',
                      subtitle: lastSync == null
                          ? 'Not synced yet'
                          : 'Last synced ${friendlyDateTime(lastSync)}',
                      trailing: syncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: syncing ? null : sync.sync,
                    ),
                ],
              ),
            ),
          if (HealthSyncService.supported)
            ValueListenableBuilder<String?>(
              valueListenable: sync.lastError,
              builder: (context, error, _) => error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8, left: 4),
                      child: Text(
                        error,
                        style: TextStyle(color: c.warning, fontSize: 13),
                      ),
                    ),
            ),
          const SectionHeader('Daily targets'),
          TileGroup(
            children: [
              target(SettingKey.kcalTarget, 'Energy', 'kcal', 2000),
              target(SettingKey.proteinTarget, 'Protein', 'g', 100),
              target(SettingKey.carbsTarget, 'Carbs', 'g', 250),
              target(SettingKey.fatTarget, 'Fat', 'g', 70),
              target(SettingKey.waterTarget, 'Water', 'ml', 2000),
              target(SettingKey.sleepTarget, 'Sleep', 'h', 8),
            ],
          ),
          const SectionHeader('Sections'),
          TileGroup(
            children: [
              RowTile(
                icon: LucideIcons.droplet,
                title: "Women's health",
                subtitle: 'Show cycle tracking in the menu and the + sheet',
                trailing: Switch(
                  value: showWomens,
                  onChanged: (on) => settings.set(
                    SettingKey.showWomens,
                    on ? 'true' : 'false',
                  ),
                ),
              ),
            ],
          ),
          const SectionHeader('Your data'),
          TileGroup(
            children: [
              RowTile(
                key: const ValueKey('export'),
                icon: LucideIcons.download,
                title: 'Export everything',
                subtitle: 'One JSON file with all your records',
                onTap: () => _export(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Corpus keeps your data on this device. There is no account and '
            'nothing is sent anywhere. The database is not encrypted yet, so '
            'keep your phone locked with a passcode.\n\n'
            'Food data: USDA FoodData Central (public domain).\n'
            'Corpus is not a medical device and does not give medical advice.',
            style: TextStyle(fontSize: 12, color: c.fgTertiary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
