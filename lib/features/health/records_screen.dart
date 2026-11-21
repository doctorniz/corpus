import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:open_filex/open_filex.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../core/db/database.dart';
import '../../data/records_repository.dart';
import '../../ui/forms.dart';
import '../../ui/widgets.dart';
import 'record_kinds.dart';

String _recordSubtitle(RecordKind kind, HealthRecord r) {
  final details = decodeDetails(r.details);
  final parts = <String>[
    for (final k in kind.subtitleKeys)
      if ((details[k] ?? '').isNotEmpty) details[k]!,
    if (r.date != null)
      kind.dateHasTime ? friendlyDateTime(r.date!) : friendlyDate(r.date!),
  ];
  return parts.join(' · ');
}

Color? _statusColor(BuildContext context, String? status) {
  final c = context.colors;
  return switch (status) {
    'Active' || 'Current' => c.accent,
    'Severe' || 'Anaphylaxis' => c.danger,
    'Moderate' => c.warning,
    _ => null,
  };
}

/// All records of one kind, e.g. every medication.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key, required this.kind});

  final RecordKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(recordsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(kind.plural),
        actions: [
          IconButton(
            tooltip: 'Add ${kind.singular}',
            icon: const Icon(LucideIcons.plus),
            onPressed: () => pushPage(context, RecordFormScreen(kind: kind)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamHost<List<HealthRecord>>(
        create: () => repo.watchKind(kind.id),
        builder: (context, records) {
          if (records.isEmpty) {
            return Center(
              child: EmptyState(
                icon: kind.icon,
                title: 'Nothing here yet',
                message: 'Add your first ${kind.singular}.',
                action: FilledButton.icon(
                  onPressed: () =>
                      pushPage(context, RecordFormScreen(kind: kind)),
                  icon: const Icon(LucideIcons.plus, size: 18),
                  label: Text('Add ${kind.singular}'),
                ),
              ),
            );
          }
          return PageBody(
            children: [
              const SizedBox(height: 8),
              TileGroup(
                children: [
                  for (final r in records)
                    RowTile(
                      title: r.title,
                      subtitle: _recordSubtitle(kind, r),
                      trailing: r.status == null
                          ? null
                          : Pill(
                              r.status!,
                              color: _statusColor(context, r.status),
                            ),
                      onTap: () => pushPage(
                        context,
                        RecordDetailScreen(kind: kind, recordId: r.id),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One record with all its fields and attached files.
class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({
    super.key,
    required this.kind,
    required this.recordId,
  });

  final RecordKind kind;
  final String recordId;

  Future<void> _attach(
    BuildContext context,
    WidgetRef ref,
    Future<({String path, String name})?> Function() pick,
  ) async {
    try {
      final picked = await pick();
      if (picked == null) return;
      await ref
          .read(recordsProvider)
          .attachFile(recordId, File(picked.path), picked.name);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Could not attach the file: $e');
    }
  }

  void _showAttachOptions(BuildContext context, WidgetRef ref) {
    final mobile = Platform.isAndroid || Platform.isIOS;
    showAppSheet<void>(
      context,
      title: 'Attach',
      child: TileGroup(
        children: [
          RowTile(
            icon: LucideIcons.file,
            title: 'Choose a file',
            subtitle: 'PDF, image or any document',
            onTap: () {
              Navigator.pop(context);
              _attach(context, ref, () async {
                final files = await FilePicker.pickFiles();
                final f = files.firstOrNull;
                if (f?.path == null) return null;
                return (path: f!.path!, name: f.name);
              });
            },
          ),
          if (mobile) ...[
            RowTile(
              icon: LucideIcons.camera,
              title: 'Take a photo',
              onTap: () {
                Navigator.pop(context);
                _attach(context, ref, () async {
                  final x = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                  );
                  return x == null ? null : (path: x.path, name: x.name);
                });
              },
            ),
            RowTile(
              icon: LucideIcons.image,
              title: 'Photo library',
              onTap: () {
                Navigator.pop(context);
                _attach(context, ref, () async {
                  final x = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  return x == null ? null : (path: x.path, name: x.name);
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(recordsProvider);
    final c = context.colors;
    return StreamHost<HealthRecord?>(
      create: () => repo.watch(recordId),
      builder: (context, r) {
        if (r == null) {
          return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
        }
        final details = decodeDetails(r.details);
        final rows = <(String, String)>[
          if (r.status != null) ('Status', r.status!),
          if (r.date != null)
            (
              kind.dateLabel ?? 'Date',
              kind.dateHasTime
                  ? friendlyDateTime(r.date!)
                  : friendlyDate(r.date!),
            ),
          if (r.endDate != null)
            (kind.endDateLabel ?? 'Ended', friendlyDate(r.endDate!)),
          for (final f in kind.fields)
            if ((details[f.key] ?? '').isNotEmpty) (f.label, details[f.key]!),
          if ((r.notes ?? '').isNotEmpty) ('Notes', r.notes!),
        ];

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(LucideIcons.pencil, size: 20),
                onPressed: () => pushPage(
                  context,
                  RecordFormScreen(kind: kind, existing: r),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(LucideIcons.trash2, size: 20),
                onPressed: () async {
                  if (!await confirmDelete(context, 'this ${kind.singular}')) {
                    return;
                  }
                  await repo.delete(r.id);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: PageBody(
            children: [
              Row(
                children: [
                  Icon(kind.icon, size: 18, color: c.fgTertiary),
                  const SizedBox(width: 6),
                  Text(
                    kind.plural,
                    style: TextStyle(color: c.fgTertiary, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(r.title, style: context.text.headlineSmall),
              const SizedBox(height: 16),
              if (rows.isNotEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        Text(
                          rows[i].$1,
                          style: TextStyle(fontSize: 12, color: c.fgTertiary),
                        ),
                        const SizedBox(height: 2),
                        SelectableText(
                          rows[i].$2,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ],
                  ),
                ),
              SectionHeader(
                'Files',
                trailing: TextButton.icon(
                  onPressed: () => _showAttachOptions(context, ref),
                  icon: const Icon(LucideIcons.paperclip, size: 16),
                  label: const Text('Attach'),
                ),
              ),
              StreamHost<List<Attachment>>(
                create: () => repo.watchAttachments(r.id),
                builder: (context, files) {
                  if (files.isEmpty) {
                    return Text(
                      'No files attached. Add a scan, a PDF or a photo of '
                      'the paper copy.',
                      style: TextStyle(color: c.fgTertiary, fontSize: 14),
                    );
                  }
                  return TileGroup(
                    children: [
                      for (final a in files)
                        RowTile(
                          icon: LucideIcons.fileText,
                          title: a.fileName,
                          subtitle:
                              '${(a.sizeBytes / 1024).ceil()} KB · '
                              '${friendlyDate(a.createdAt)}',
                          trailing: IconButton(
                            tooltip: 'Remove file',
                            icon: const Icon(LucideIcons.trash2, size: 18),
                            onPressed: () async {
                              if (await confirmDelete(context, a.fileName)) {
                                await repo.deleteAttachment(a);
                              }
                            },
                          ),
                          onTap: () async {
                            final file = await repo.attachmentFile(a);
                            final result = await OpenFilex.open(file.path);
                            if (result.type != ResultType.done &&
                                context.mounted) {
                              showSnack(
                                context,
                                'No app found to open this file.',
                              );
                            }
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Add or edit a record. The fields come from the [RecordKind].
class RecordFormScreen extends ConsumerStatefulWidget {
  const RecordFormScreen({super.key, required this.kind, this.existing});

  final RecordKind kind;
  final HealthRecord? existing;

  @override
  ConsumerState<RecordFormScreen> createState() => _RecordFormState();
}

class _RecordFormState extends ConsumerState<RecordFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late final Map<String, TextEditingController> _fields;
  DateTime? _date;
  DateTime? _endDate;
  String? _status;
  bool _saving = false;

  RecordKind get kind => widget.kind;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final details = e == null ? <String, String>{} : decodeDetails(e.details);
    _fields = {
      for (final f in kind.fields)
        f.key: TextEditingController(text: details[f.key]),
    };
    // A date-and-time field always shows a value, so it must hold one.
    _date =
        e?.date?.toLocal() ??
        (kind.dateHasTime && e == null ? DateTime.now() : null);
    _endDate = e?.endDate?.toLocal();
    _status = e?.status ?? kind.statuses.firstOrNull;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      showSnack(context, 'Enter ${kind.titleLabel.toLowerCase()}.');
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(recordsProvider)
        .save(
          id: widget.existing?.id,
          kind: kind.id,
          title: title,
          date: _date,
          endDate: _endDate,
          status: _status,
          details: {
            for (final e in _fields.entries) e.key: e.value.text.trim(),
          },
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit ${kind.singular}' : 'New ${kind.singular}'),
      ),
      body: PageBody(
        children: [
          const SizedBox(height: 8),
          FormColumn(
            children: [
              TextField(
                key: const ValueKey('record-title'),
                controller: _title,
                autofocus: !editing,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: kind.titleLabel,
                  hintText: kind.titleHint,
                ),
              ),
              if (kind.statuses.isNotEmpty)
                ChoiceChips<String>(
                  options: kind.statuses,
                  selected: _status,
                  label: (s) => s,
                  onSelected: (s) => setState(() => _status = s),
                ),
              if (kind.dateLabel != null)
                kind.dateHasTime
                    ? DateTimeField(
                        label: kind.dateLabel!,
                        value: _date ?? DateTime.now(),
                        onChanged: (d) => setState(() => _date = d),
                      )
                    : DateField(
                        label: kind.dateLabel!,
                        value: _date,
                        clearable: true,
                        onChanged: (d) => setState(() => _date = d),
                      ),
              if (kind.endDateLabel != null)
                DateField(
                  label: kind.endDateLabel!,
                  value: _endDate,
                  clearable: true,
                  onChanged: (d) => setState(() => _endDate = d),
                ),
              for (final f in kind.fields)
                TextField(
                  controller: _fields[f.key],
                  minLines: f.multiline ? 2 : 1,
                  maxLines: f.multiline ? 6 : 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: f.label,
                    hintText: f.hint,
                  ),
                ),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 4),
              FilledButton(
                key: const ValueKey('record-save'),
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
              if (!editing)
                Text(
                  'You can attach files after saving.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.fgTertiary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
