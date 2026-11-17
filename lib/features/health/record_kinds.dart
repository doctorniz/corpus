import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// An extra, kind-specific field stored in a record's `details`.
class DetailField {
  const DetailField(this.key, this.label, {this.multiline = false, this.hint});
  final String key;
  final String label;
  final bool multiline;
  final String? hint;
}

/// Describes one section of the health booklet: how it is labelled, which
/// dates and statuses it has, and its extra fields. The list, detail and
/// form screens are all driven by this, so adding a section is one entry.
class RecordKind {
  const RecordKind({
    required this.id,
    required this.plural,
    required this.singular,
    required this.icon,
    required this.titleLabel,
    this.titleHint,
    this.dateLabel,
    this.dateHasTime = false,
    this.endDateLabel,
    this.statuses = const [],
    this.fields = const [],
    this.subtitleKeys = const [],
  });

  final String id;
  final String plural;
  final String singular;
  final IconData icon;
  final String titleLabel;
  final String? titleHint;
  final String? dateLabel;
  final bool dateHasTime;
  final String? endDateLabel;
  final List<String> statuses;
  final List<DetailField> fields;

  /// Detail keys shown under the title in lists.
  final List<String> subtitleKeys;
}

const recordKinds = <RecordKind>[
  RecordKind(
    id: 'condition',
    plural: 'Medical history',
    singular: 'condition',
    icon: LucideIcons.clipboardList,
    titleLabel: 'Condition or diagnosis',
    titleHint: 'e.g. Asthma',
    dateLabel: 'Diagnosed',
    statuses: ['Active', 'Managed', 'Resolved'],
    fields: [DetailField('clinician', 'Treating clinician')],
  ),
  RecordKind(
    id: 'medication',
    plural: 'Medications',
    singular: 'medication',
    icon: LucideIcons.pill,
    titleLabel: 'Medication',
    titleHint: 'e.g. Ramipril',
    dateLabel: 'Started',
    endDateLabel: 'Stopped',
    statuses: ['Current', 'As needed', 'Stopped'],
    fields: [
      DetailField('dose', 'Dose', hint: 'e.g. 5 mg'),
      DetailField('frequency', 'How often', hint: 'e.g. once daily'),
      DetailField('reason', 'What it is for'),
      DetailField('prescriber', 'Prescribed by'),
    ],
    subtitleKeys: ['dose', 'frequency'],
  ),
  RecordKind(
    id: 'allergy',
    plural: 'Allergies',
    singular: 'allergy',
    icon: LucideIcons.triangleAlert,
    titleLabel: 'Allergic to',
    titleHint: 'e.g. Penicillin',
    statuses: ['Mild', 'Moderate', 'Severe', 'Anaphylaxis'],
    fields: [DetailField('reaction', 'Reaction', hint: 'e.g. rash')],
    subtitleKeys: ['reaction'],
  ),
  RecordKind(
    id: 'surgery',
    plural: 'Surgeries & procedures',
    singular: 'procedure',
    icon: LucideIcons.scissors,
    titleLabel: 'Operation or procedure',
    titleHint: 'e.g. Appendicectomy',
    dateLabel: 'Date',
    fields: [
      DetailField('hospital', 'Hospital'),
      DetailField('surgeon', 'Surgeon'),
      DetailField('complications', 'Complications', multiline: true),
    ],
    subtitleKeys: ['hospital'],
  ),
  RecordKind(
    id: 'appointment',
    plural: 'Appointments',
    singular: 'appointment',
    icon: LucideIcons.calendarClock,
    titleLabel: 'What it is for',
    titleHint: 'e.g. Cardiology follow-up',
    dateLabel: 'When',
    dateHasTime: true,
    fields: [
      DetailField('clinician', 'With'),
      DetailField('location', 'Where'),
      DetailField('outcome', 'Outcome', multiline: true),
    ],
    subtitleKeys: ['clinician', 'location'],
  ),
  RecordKind(
    id: 'specialist',
    plural: 'Doctors & specialists',
    singular: 'clinician',
    icon: LucideIcons.stethoscope,
    titleLabel: 'Name',
    titleHint: 'e.g. Dr A. Patel',
    fields: [
      DetailField('specialty', 'Specialty', hint: 'e.g. Cardiologist'),
      DetailField('clinic', 'Clinic or hospital'),
      DetailField('phone', 'Phone'),
      DetailField('email', 'Email'),
      DetailField('address', 'Address', multiline: true),
    ],
    subtitleKeys: ['specialty', 'clinic'],
  ),
  RecordKind(
    id: 'letter',
    plural: 'Clinic letters',
    singular: 'letter',
    icon: LucideIcons.mail,
    titleLabel: 'Title',
    titleHint: 'e.g. Cardiology clinic letter',
    dateLabel: 'Date of letter',
    fields: [
      DetailField('from', 'From'),
      DetailField('summary', 'Summary', multiline: true),
    ],
    subtitleKeys: ['from'],
  ),
  RecordKind(
    id: 'lab_report',
    plural: 'Lab reports',
    singular: 'lab report',
    icon: LucideIcons.flaskConical,
    titleLabel: 'Title',
    titleHint: 'e.g. Annual bloods',
    dateLabel: 'Date taken',
    fields: [
      DetailField('lab', 'Laboratory'),
      DetailField('requestedBy', 'Requested by'),
      DetailField('summary', 'Summary', multiline: true),
    ],
    subtitleKeys: ['lab'],
  ),
  RecordKind(
    id: 'scan',
    plural: 'Scans & imaging',
    singular: 'scan',
    icon: LucideIcons.scanLine,
    titleLabel: 'Scan',
    titleHint: 'e.g. MRI left knee',
    dateLabel: 'Date',
    fields: [
      DetailField('modality', 'Type', hint: 'X-ray, CT, MRI, ultrasound…'),
      DetailField('facility', 'Where'),
      DetailField('findings', 'Findings', multiline: true),
    ],
    subtitleKeys: ['modality', 'facility'],
  ),
  RecordKind(
    id: 'vaccination',
    plural: 'Vaccinations',
    singular: 'vaccination',
    icon: LucideIcons.syringe,
    titleLabel: 'Vaccine',
    titleHint: 'e.g. Tetanus booster',
    dateLabel: 'Date given',
    fields: [
      DetailField('dose', 'Dose number'),
      DetailField('batch', 'Batch / lot'),
      DetailField('givenBy', 'Given by'),
    ],
    subtitleKeys: ['dose'],
  ),
];

RecordKind recordKind(String id) => recordKinds.firstWhere((k) => k.id == id);
