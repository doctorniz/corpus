# Corpus

**A local-first personal health booklet.** One place to record and understand your own body: medical records, fitness and activity, nutrition and habits. Your data lives on your device, in formats you own.

> Status: early scaffold. The app shell, local database and a weight quick-add work; the modules are placeholders.
>
> ⚠️ The local database is **not encrypted yet** (see [ADR 0004](docs/adr/0004-encryption-deferred.md)). It relies on OS-level device encryption.

## What it is

Corpus is an all-in-one tracker that combines:

| Area | What you track |
|---|---|
| **Health booklet** | Conditions, medications, allergies, vaccinations, lab results, doctor visits, documents, vitals |
| **Fitness & activity** | Workouts, exercises/sets/reps, cardio sessions, steps, sleep, body measurements |
| **Nutrition** | Meals, foods, macros/micros, water, supplements |
| **Habits** | Daily/weekly habits, streaks, check-ins, mood and energy |

All four share one timeline and one data store, so you can see across them, for example how sleep relates to training load, or whether a new medication changed your resting heart rate.

## Core promises

1. **Local-first.** Works fully offline. No account required. The device is the source of truth.
2. **You own the data.** Open, documented storage plus full export at any time (JSON/CSV).
3. **Private by default.** No telemetry, no ads, no third-party analytics. Sync, if used, is optional and end-to-end encrypted.
4. **One app, not five.** Health records, training, food and habits in a single coherent model.

## Development

Requires Flutter 3.50+ (Dart 3.14) and, for Android builds, JDK 21.

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift codegen; rerun after table changes
flutter test
flutter run -d windows        # or: android, ios, macos, linux
```

Stack: Flutter · drift (SQLite) · Riverpod · go_router. See [Architecture](docs/ARCHITECTURE.md).

## License

[AGPL-3.0](LICENSE)

## Docs

- [Vision & goals](docs/VISION.md): why this exists, goals, non-goals, principles
- [Features](docs/FEATURES.md): module-by-module scope
- [Data model](docs/DATA_MODEL.md): core entities and how they relate
- [Architecture](docs/ARCHITECTURE.md): local-first design, storage, sync, security, open decisions
- [Roadmap](docs/ROADMAP.md): phased plan from MVP onward
- [Decision records](docs/adr/): platform, stack, license, encryption
