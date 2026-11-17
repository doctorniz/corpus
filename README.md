# Corpus

**A local-first personal health booklet.** One place to record and understand your own body: medical records, fitness and activity, sleep, nutrition, cycle and habits. Your data lives on your device, in formats you own.

> Status: early but working on Android and iOS. Android was tested by hand on an emulator, including Health Connect sync. On iOS, CI runs the app on an iPhone simulator through every area on each push, up to Apple Health's permission sheet; it has not yet run on a physical iPhone (see [iOS release](docs/IOS_RELEASE.md)).
>
> ⚠️ The local database is **not encrypted yet** (see [ADR 0004](docs/adr/0004-encryption-deferred.md)). It relies on OS-level device encryption.

## What it does

The bottom bar has four tabs and a round **+** in the middle that logs anything from anywhere. Habits, Women's health and Settings are in the top-right menu.

| Area | What it holds |
|---|---|
| **Health** | Medical history, medications, allergies, surgeries, vaccinations, appointments, doctors and specialists, clinic letters, scans, lab reports (each with attached files and photos), lab results with trends against reference ranges, and vitals |
| **Fitness** | Workout log (gym sets, runs, rides…), weekly activity, steps, weight trend, per-exercise progress |
| **Sleep** | Nightly duration against a target, usual bedtime, history |
| **Nutrition** | Food diary by meal with calorie and macro targets, about 7,800 bundled foods (USDA), your own foods, quick add, water |
| **Women's health** | Period and symptom calendar, cycle and period averages, predicted next period and fertile window |
| **Habits** | Daily or selected-day habits (done / count), streaks, last-seven-days view |

**Health sync (optional, off by default):** two-way with Apple Health and Google Health Connect. Steps, workouts, sleep, weight, height, body fat, resting heart rate, blood pressure and menstrual flow are imported, so any watch or tracker that syncs to your phone feeds Corpus. What you log in Corpus is written back.

## Core promises

1. **Local-first.** Works fully offline. No account. The device is the source of truth.
2. **You own the data.** One SQLite file plus a full JSON export (Settings › Export everything).
3. **Private by default.** No telemetry, no ads, no network calls. Health sync talks only to the on-device health store.
4. **One app, not five.**

## Development

Requires Flutter 3.50+ (Dart 3.14) and, for Android builds, JDK 21.

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # drift codegen; rerun after table changes
flutter test
flutter test integration_test -d <device>   # drives the real app end to end
flutter run                   # on a connected phone or emulator
```

- Debug APKs are large (~180 MB). For a small emulator build: `flutter build apk --release --target-platform android-x64 --split-per-abi`.
- The bundled food list is `assets/foods.bin`, built by `tool/build_foods.dart`.
- iOS builds need a Mac; CI does them. See [docs/IOS_RELEASE.md](docs/IOS_RELEASE.md).

Stack: Flutter · drift (SQLite) · Riverpod · go_router · fl_chart · health. See [Architecture](docs/ARCHITECTURE.md).

## License

[AGPL-3.0](LICENSE). Food data: USDA FoodData Central (public domain).

Corpus is not a medical device and does not give medical advice.

## Docs

- [Vision & goals](docs/VISION.md)
- [Features](docs/FEATURES.md): what is built and what is not
- [Data model](docs/DATA_MODEL.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)
- [iOS release / TestFlight](docs/IOS_RELEASE.md)
- [Decision records](docs/adr/)
