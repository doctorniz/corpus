# ADR 0002: Flutter + Dart, drift, Riverpod, go_router

- Status: Accepted
- Date: 2026-11-13

## Context
We need one codebase for mobile and desktop, an embedded SQL store, and access to native health platforms (HealthKit, Health Connect) later. We considered Tauri, Expo, Flutter and a PWA.

## Decision
- **UI/runtime:** Flutter (Material 3)
- **Storage:** SQLite via [drift](https://drift.simonbinder.eu/) with code-generated, type-safe tables and migrations
- **State / DI:** Riverpod
- **Navigation:** go_router (`StatefulShellRoute` for the module tabs)
- **IDs:** UUID v7 (time-ordered, sync-friendly)

## Consequences
- One language (Dart) end to end. Native health integrations come through Flutter plugins (e.g. `health`).
- drift requires code generation: run `dart run build_runner build` after changing tables.
- Toolchain: Flutter 3.50 / Dart 3.14 (upgraded 2026-11-14). Since Flutter 3.47, Material widgets come from `package:material_ui/material_ui.dart`, not `package:flutter/material.dart`.
