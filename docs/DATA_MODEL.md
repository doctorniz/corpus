# Data Model (draft)

A conceptual model, not tied to a specific database. Field lists are indicative.

## Conventions

- Every record has `id` (UUID/ULID), `created_at` and `updated_at`, and `deleted_at` (soft delete).
- Timestamps are stored in UTC, with the original time-zone offset kept for display.
- Quantities are stored as `value` plus `unit` in canonical SI units and converted for display.
- Every record belongs to a `profile_id` (prepares for multi-profile).
- Any record can carry `tags[]`, `notes` and `attachments[]`.
- Edits are recorded in a change log (for history, undo and future sync).

## Core entities

```
Profile
 ├─ HealthBooklet
 │   ├─ Condition        (name, code?, status, onset, resolved)
 │   ├─ Medication       (name, dose, unit, schedule, start, end)
 │   │   └─ DoseLog      (taken_at, skipped?)
 │   ├─ Allergy          (substance, reaction, severity)
 │   ├─ Vaccination      (vaccine, dose#, date, lot, provider)
 │   ├─ LabResult        (test, value, unit, ref_low, ref_high, date)
 │   ├─ Visit            (provider, date, reason, notes)
 │   └─ Document         (file ref, mime, title, linked records)
 │
 ├─ Measurement          (type, value, unit, measured_at, source)
 │     types: weight, body_fat, bp_sys/bp_dia, resting_hr, glucose,
 │            temperature, spo2, steps, sleep_duration, waist, ...
 │
 ├─ Fitness
 │   ├─ Exercise         (name, category, muscle groups, is_custom)
 │   ├─ WorkoutTemplate  (name, ordered exercises)
 │   └─ Workout          (started_at, ended_at, notes)
 │       └─ WorkoutSet   (exercise, reps, weight, duration, distance, rpe)
 │
 ├─ Nutrition
 │   ├─ Food             (name, brand, per-100g nutrients, servings)
 │   ├─ Recipe           (ingredients -> Food + quantity)
 │   ├─ MealEntry        (eaten_at, slot, food|recipe, quantity)
 │   └─ NutritionTarget  (kcal, protein, carbs, fat, effective_from)
 │
 └─ Habits
     ├─ Habit            (name, kind: bool|count|duration, schedule, target)
     ├─ HabitLog         (habit, date, value)
     └─ DailyCheckIn     (date, mood, energy, stress, journal)
```

## Key design choice: generic `Measurement`

Vitals, body metrics, steps and sleep all go into one `Measurement` table keyed by `type`. This makes trends, charts, imports and cross-domain correlation uniform. New metrics can be added without schema changes.

## Open questions

- Use medical coding (ICD-10, SNOMED, LOINC) optionally for conditions and labs, or free text only?
- Which food database to bundle offline (e.g. USDA FoodData Central, Open Food Facts subset), and how large can it be?
- Store attachments inside the database or as files alongside it?
