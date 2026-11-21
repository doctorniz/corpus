# Corpus — project context

Local-first personal health booklet: medical records, fitness and activity,
sleep, nutrition, cycle and habits, in one app. Every item of user data lives
on the device in one SQLite database (plus attached files) the user can
export in full. No account, no server, no network calls.

One Flutter codebase (Dart 3.14): Android and iOS are the focus; Windows,
macOS and Linux build and run. Health data flows both ways with Apple Health
and Health Connect when the user switches it on. See `docs/ARCHITECTURE.md`,
`docs/DATA_MODEL.md` and `docs/IOS_RELEASE.md`.

These rules are adapted from Mentis (doctorniz/mentis), the sister app
whose style and working agreement Corpus follows.

## Non-negotiable principles

1. **The device is the only source of truth.** User data lives in the
   database (`core/db/`) and the attachments folder, nowhere else: not in
   shared preferences, not only in memory, not only in the health store.
   Everything the user entered reaches the JSON export. Deleting the
   health-store link must lose nothing.
2. **Nothing leaves the device.** No network calls, no telemetry, no
   analytics, no crash reporting. Health sync talks only to the on-device
   health store. Anything that would go online is opt-in, off by default,
   and decided in an ADR first.
3. **Nothing waits at launch.** The first screen draws from the database
   straight away. The bundled food list, health sync and anything else slow
   run after it, in the background, and never block a screen.
4. **No feature reaches into another feature's internals.** Features talk
   through `data/` repositories, `ui/` widgets and `app/`. Enforced by
   `test/boundaries_test.dart`; its allow-list only shrinks.
5. **Nothing heavy on the UI isolate.** Parsing, bulk imports and exports run
   in an isolate (`compute`) or in drift's background connection.
6. **History is append-friendly.** Soft deletes, UUID v7 ids, UTC timestamps
   with the offset kept, and every write appended to `change_log`.
   Migrations are forward-only and never lose data.

## Settled decisions — do not relitigate

Each has an ADR in `docs/adr/`.

- **Platforms:** mobile first (Android, iOS), desktop from the same code. (0001)
- **Stack:** Flutter + Dart; drift (SQLite), Riverpod, go_router, fl_chart.
  Material comes from `package:material_ui/material_ui.dart`, never
  `package:flutter/material.dart`. (0002)
- **Licence:** AGPL-3.0. (0003)
- **Encryption:** plain SQLite for now, opened only in
  `core/db/connection.dart` so encryption goes in there later. (0004)
- **Health sync:** two-way with Apple Health / Health Connect, off by
  default. Imports are `source = 'health'` with an `external_id` and are
  never written back; Corpus's own writes are skipped on import. Trackers
  reach Corpus only through the phone's health store. (0005)
- **Food data:** USDA SR Legacy bundled as `assets/foods.bin`, loaded on
  first launch. No online food lookup unless a later ADR adds an opt-in. (0006)
- **iOS:** built, tested on a simulator and shipped to TestFlight by GitHub
  Actions; no Mac needed locally. (0007)
- **Units:** stored canonical (kg, cm, ml, kcal, minutes, mmHg); converted
  only for display.
- **Look:** Mentis's layout, greys and Inter, with a matte green accent
  (`lib/app/theme.dart`). Bottom bar: Health · Fitness · **+** · Sleep ·
  Nutrition; everything else in the left drawer.
- **Not a medical device.** No diagnosis, dosing advice or treatment
  suggestions. Show what the user recorded; do not interpret it.

## Layers

`core/` (database, ids, units) ← `data/` (repositories; every write logs to
`change_log`) ← `services/` (health sync, food loader) ← `ui/` (shared
widgets) ← `features/` (one folder per area) ← `app/` (theme, router, shell).
A layer imports only those to its left; `core/` and `data/` never import UI.

## Performance budgets

| Budget                       | Value      | How                                  |
| ---------------------------- | ---------- | ------------------------------------ |
| Android release APK, one ABI | ≤ 26 MB    | CI fails over it (`tool/check_budgets.dart`) |
| Mobile cold start            | < 1.8 s    | by hand on a phone; reported         |
| First food search results    | < 50 ms    | `test/budgets_test.dart`; reported   |
| Save a log entry             | < 100 ms   | `test/budgets_test.dart`; reported   |

Values are in `budgets.json`. Do not raise a budget to make a build pass —
raise it only as a deliberate, separately committed decision.

## Working agreement

- Produce a plan and wait for approval before editing more than two files.
- One task per branch. Commit at every green build.
- `dart format`, `flutter analyze` and `flutter test` must all pass before a
  task is considered done, and generated code must be current
  (`dart run build_runner build`). Run them; do not assume.
- A change to the UI is checked in the running app (emulator or simulator),
  not only in tests.
- Do not add a dependency without asking. State the size cost when you do.
- Do not refactor, reformat or "improve" code outside the stated task.
- Do not rewrite working features.
- If a task turns out to be larger than described, stop and say so rather
  than proceeding.
- When behaviour is ambiguous, ask. Do not infer a product decision.
- A significant decision gets an ADR in `docs/adr/` once agreed.
- Keep `docs/` in step with the code: a change to behaviour, structure,
  dependencies or process updates the doc that describes it in the same task
  (`README.md`, `docs/FEATURES.md`, `docs/ARCHITECTURE.md`,
  `docs/DATA_MODEL.md`, …). Behaviour a person must check by hand goes in
  the manual verification queue in `docs/LAUNCH_DEFERRALS.md`.
- UI copy: say as little as possible. A label and its control; a hint under
  a setting only when it prevents a real mistake.
