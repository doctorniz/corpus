# Data Model

The schema is defined in `lib/core/db/tables.dart` (drift). Current schema version: **2**.

## Conventions

- Every user-data row has `id` (UUID v7), `created_at`, `updated_at`, and `deleted_at` (soft delete: the app never physically removes a row).
- Timestamps are stored in UTC. Date-only things (diary day, cycle day, habit day) are stored as the local calendar day, `yyyy-MM-dd`.
- Quantities are stored in fixed units (kg, cm, ml, kcal, metres) and converted only for display.
- Rows belong to a `profile_id`, which prepares for more than one profile.
- Rows that came from Apple Health / Health Connect have `source = 'health'` and an `external_id`, which stops a re-sync from duplicating them.
- Every write appends to `change_log` in the same transaction.

## Tables

| Table | Holds |
|---|---|
| `profiles` | The person the data belongs to |
| `settings` | Key/value: device id, targets, theme, sync state |
| `change_log` | Append-only record of every insert, update and delete |
| `measurements` | Any single number over time: weight, blood pressure, resting HR, temperature, glucose, SpO₂, body fat, height, daily steps, water |
| `health_records` | One entry in the health booklet. `kind` is one of condition, medication, allergy, surgery, vaccination, appointment, specialist, letter, lab_report, scan; kind-specific fields are JSON in `details` |
| `attachments` | Files attached to a health record; the file is copied into the app's private storage |
| `lab_results` | One numeric lab value with unit and optional reference range |
| `workouts`, `workout_sets` | A session, and the sets of a strength session |
| `sleep_sessions` | Fell asleep, woke up, optional quality |
| `foods` | Bundled USDA foods and the user's own, nutrients per 100 g |
| `meal_entries` | One logged food; nutrient totals are copied in at log time |
| `cycle_days` | Flow (0–4), symptoms and notes for a day |
| `habits`, `habit_logs` | A habit and its value per day |

## Design choices

- **Generic `measurements`.** One table keyed by `type` keeps charts, imports and exports uniform, and a new metric needs no schema change.
- **Generic `health_records`.** The ten booklet sections share one table; each section is described by a `RecordKind` in `lib/features/health/record_kinds.dart`, which drives its list, detail page and form. Adding a section is one entry there.
- **Lab values are separate** from lab report documents so they can be charted.
- **Blood pressure** is two measurements with the same timestamp.

## Migrations

Forward-only, in `AppDatabase.migration`. They must never drop user data. v1 → v2 added `measurements.external_id` and every table beyond profiles, measurements and change_log.

## Open questions

- Optional medical coding (ICD-10, SNOMED, LOINC) for conditions and labs.
- Whether attachments should be embedded in exports.
