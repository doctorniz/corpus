# Architecture

## Local-first requirements

| Requirement | How it is met |
|---|---|
| Works offline, always | Every read and write hits the local SQLite database. The app makes no network calls. |
| Instant UX | Embedded database; screens watch live queries and update on write |
| User owns data | One SQLite file, documented schema, full JSON export |
| Multi-device (later) | UUID v7 ids, soft deletes and an append-only change log keep sync possible |
| Longevity | Versioned, forward-only migrations |

## Layers

```
┌───────────────────────────────────────────────────────┐
│ features/   screens and forms, one folder per area     │
│ ui/         shared widgets, forms, charts              │
├───────────────────────────────────────────────────────┤
│ data/       repositories: all reads and writes;        │
│             each write also appends to change_log      │
├──────────────────────────────┬────────────────────────┤
│ core/db/    drift + SQLite   │ services/health_sync    │
│                              │ Apple Health /          │
│                              │ Health Connect          │
└──────────────────────────────┴────────────────────────┘
```

- **State:** Riverpod provides the repositories; screens subscribe to drift's live query streams.
- **Health sync:** `HealthSyncService` imports from the phone's health store into the repositories. It also implements `HealthBridge`, which repositories call after a manual entry is saved, to write it back. Imports are marked `source = 'health'` and are never written back; entries Corpus wrote are skipped on import by their source id. Write-back failures are logged and never block saving.
- **Food data:** `assets/foods.bin` (gzipped JSON, built by `tool/build_foods.dart` from USDA SR Legacy) is loaded into the `foods` table on first launch and whenever `bundledFoodsVersion` changes.
- **Attachments:** copied into the app's private documents folder; the database stores a relative path.
- **Security:** plain SQLite for now, opened in exactly one place (`core/db/connection.dart`) so encryption can be added there.

## Decisions

| # | Decision | ADR |
|---|---|---|
| 1 | Mobile + desktop from one codebase; phones are the focus | [0001](adr/0001-platform-mobile-and-desktop.md) |
| 2 | Flutter + Dart; drift (SQLite), Riverpod, go_router | [0002](adr/0002-stack-flutter.md) |
| 3 | AGPL-3.0 | [0003](adr/0003-license-agpl.md) |
| 4 | Plain SQLite for MVP; encryption later behind `connection.dart` | [0004](adr/0004-encryption-deferred.md) |
| 5 | Two-way sync with Apple Health / Health Connect; trackers reach Corpus through them | [0005](adr/0005-health-sync.md) |
| 6 | Bundle USDA SR Legacy as the offline food database | [0006](adr/0006-bundled-food-data.md) |
| 7 | iOS built and shipped to TestFlight by GitHub Actions | [0007](adr/0007-ios-via-ci.md) |

## Code layout

```
lib/
  main.dart             opens the database, then starts the app
  app/                  app widget, theme (Mentis palette), router, bottom bar + menu, providers
  core/                 database tables, ids, units, activity list
  data/                 repositories, export, the HealthBridge interface
  services/             health sync, bundled-food loader
  ui/                   shared widgets, form fields, charts
  features/
    capture/            the + sheet
    health/             booklet sections, labs, vitals
    fitness/ sleep/ nutrition/ womens/ habits/ settings/
test/                   repository tests and whole-app widget tests (in-memory SQLite)
integration_test/       drives the real app end to end; CI runs it on an iPhone simulator
tool/build_foods.dart   builds assets/foods.bin
```

## Platform notes

- **Android:** minSdk 26 (Health Connect). `MainActivity` extends `FlutterFragmentActivity`, which the health plugin needs. The Health Connect permissions in `AndroidManifest.xml` must match the types requested in `health_sync.dart`.
- **Android assets:** do not give a bundled asset a `.gz` extension; Android's packaging drops it.
- **iOS:** deployment target 15.0; HealthKit entitlement in `ios/Runner/Runner.entitlements`; usage strings in `Info.plist`.
- **Desktop:** builds and runs; health sync and camera capture are hidden there.

## Still open

- Sync between devices (the change log and ids keep options open).
- Encryption at rest and app lock.
