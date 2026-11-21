# Corpus — Code Conventions

How code in this repo is written. The principles, budgets and working
agreement are in [`CLAUDE.md`](../CLAUDE.md); the layout is explained in
[`ARCHITECTURE.md`](./ARCHITECTURE.md). Adapted from Mentis's conventions.

## Project structure

```
corpus/
├── lib/
│   ├── core/          # database tables, ids, units, activity list — owned by no feature
│   ├── data/          # repositories (all reads and writes), export, HealthBridge
│   ├── services/      # health sync, bundled-food loader
│   ├── ui/            # shared widgets, form fields, charts
│   ├── features/      # one folder per area: capture, health, fitness, sleep, nutrition, womens, habits, settings
│   └── app/           # app widget, theme, router, shell (bottom bar, masthead, drawer), providers
├── test/              # repository, widget, budget and import-boundary tests
├── integration_test/  # drives the real app end to end (CI: iPhone simulator)
├── tool/              # build_foods.dart, check_budgets.dart
├── assets/            # foods.bin, fonts/inter
├── docs/              # documentation; docs/adr — decision records
└── .github/workflows/ # ci.yml, testflight.yml
```

**Import boundaries** (`test/boundaries_test.dart`): `core/` imports nothing
above it; `data/` imports only `core/`; a feature never imports another
feature. Shared pieces move down to `ui/` or `data/`.

## Naming

| Kind                    | Convention                         | Example                                  |
| ----------------------- | ---------------------------------- | ---------------------------------------- |
| Files                   | snake_case                         | `sleep_screen.dart`, `health_sync.dart`  |
| Tests                   | `*_test.dart`                      | `repositories_test.dart`                 |
| Classes, enums, typedefs | PascalCase                        | `SleepRepository`, `RecordKind`          |
| Functions, variables, constants | camelCase                  | `friendlyDay`, `bundledFoodsVersion`     |
| Repositories            | `[Area]Repository` in `data/`      | `NutritionRepository`                    |
| Riverpod providers      | `[name]Provider`                   | `nutritionProvider`, `themeModeProvider` |
| Database tables         | plural PascalCase (drift), snake_case in SQL | `MealEntries` → `meal_entries` |
| Widget keys for tests   | `ValueKey('area-thing')`           | `ValueKey('habit-save')`                 |
| Event callbacks         | `on[Event]`                        | `onChanged`, `onSaved`                   |

Inside `lib/`, import with relative paths; tests import `package:corpus/…`.

## Widgets

- Material from `package:material_ui/material_ui.dart`; icons from Lucide.
- Colours only from `context.colors` (`CorpusColors` in `app/theme.dart`),
  never a literal `Color(…)` in a feature. Text styles from the theme or
  the shared widgets.
- Build screens from the shared pieces in `ui/`: `PageBody`, `AppCard`,
  `SectionHeader`, `TileGroup` / `RowTile`, `Stat` / `StatRow`, `Pill`,
  `EmptyState`, the form fields in `forms.dart` and the charts in
  `charts.dart`. A tab's top bar is `Masthead`.
- Screens subscribe to repository streams (`StreamHost`, `Loaded`); they do
  not cache data of their own.
- Every control a test taps has a `ValueKey` or a tooltip.
- Never nest tappable widgets (an `InkWell` inside an `InkWell`).

## Data

- All reads and writes go through a repository; screens never touch `db`.
- Every write appends to `change_log` (`Repository.log`) in the same
  transaction.
- Deletes are soft (`deletedAt`); queries filter them out.
- Times are stored in UTC with the offset; days as `yyyy-MM-dd` keys
  (`dayKey`).
- A table change bumps `schemaVersion` with a forward-only migration, then
  regenerate (`dart run build_runner build`) and update `docs/DATA_MODEL.md`.
- A manual entry that has a health-store equivalent calls the `HealthBridge`
  after saving; a write-back failure never blocks the save.

## Styling

- The palette is Mentis's (Open Color greys, light and dark) with a matte
  green accent; the font is Inter, bundled.
- Radii: 8 for controls and menu rows, 12 for cards, 16 for sheet tops.
- Section headings: 12 px, semibold, upper case, tertiary grey.
- Phones: `SafeArea` around anything at the screen's edges; touch targets at
  least 44 px.
- UI copy: as few words as possible; a hint under a setting only when it
  prevents a real mistake.

## Errors

- User-facing failures go through `showSnack` (`ui/widgets.dart`), with a
  `debugPrint` beside it when there is a stack worth keeping.
- Never swallow a failure silently in background work (health sync, food
  loading, export): log it with a short prefix such as `[health]` or
  `[foods]`.

## Testing

| Layer       | Tool                     | Covers                                                    |
| ----------- | ------------------------ | --------------------------------------------------------- |
| Unit        | `flutter test`           | repositories against in-memory SQLite, cycle maths, streaks |
| Widget      | `flutter test`           | the whole app: every tab, menu page and main flow         |
| Budgets     | `test/budgets_test.dart` | food search and save timings (reported)                   |
| Boundaries  | `test/boundaries_test.dart` | import rules                                           |
| End to end  | `integration_test/`      | the real app on a device; CI runs it on an iPhone simulator |

Before merging: generated code current, `dart format`, `flutter analyze`,
`flutter test`, and CI green (Android release build and size budget, iOS
build, iPhone simulator run). Behaviour only a person can check goes in the
manual verification queue in [`LAUNCH_DEFERRALS.md`](./LAUNCH_DEFERRALS.md).

## Git

- One task per branch: `feat/…`, `fix/…`, `refactor/…`, `docs/…`, `chore/…`.
- Conventional Commits: `type(scope): description`, with the why in the body.
- Commit at every green build; merge to `main` once CI passes.

## License

Corpus is under [AGPL-3.0](../LICENSE). Inter is under the SIL Open Font
License (`assets/fonts/inter/OFL.txt`); USDA food data is public domain.
Third-party packages keep their own licences.
