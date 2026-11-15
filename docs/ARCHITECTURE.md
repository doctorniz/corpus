# Architecture (draft)

## Local-first requirements

| Requirement | Implication |
|---|---|
| Works offline, always | All reads and writes hit local storage; the network is never on the critical path |
| Instant UX | Embedded DB; no request/response round-trips |
| User owns data | Documented schema; full export; readable without the app |
| Multi-device (later) | Change log / CRDT-friendly records; E2E-encrypted relay |
| Longevity | Versioned, forward-only migrations; export format is stable and versioned |

## Proposed layers

```
┌──────────────────────────────────────────────┐
│ UI (Today, Timeline, modules, charts)        │
├──────────────────────────────────────────────┤
│ Domain layer (entities, validation, units,   │
│ streaks, targets, insights)                  │
├──────────────────────────────────────────────┤
│ Repository / query layer                     │
├──────────────────────────────────────────────┤
│ Local store: SQLite (+ change log)           │
│ Attachments: files on disk, content-hashed   │
├──────────────────────────────────────────────┤
│ Optional: Sync engine ⇄ E2E-encrypted relay  │
└──────────────────────────────────────────────┘
```

- **Storage:** SQLite is the default candidate. It is mature, embeddable everywhere, a single file, readable by many tools, and supports encryption via SQLCipher.
- **Change log:** every mutation is written as an operation (entity, id, field changes, timestamp, device id). This enables history, undo, export diffs and later sync.
- **Sync (later):** options are a CRDT library (Automerge/Yjs), SQLite-based sync (cr-sqlite, ElectricSQL, PowerSync), or a custom op-log over a dumb encrypted relay or user-chosen storage (folder, WebDAV, S3).
- **Security:** optional DB encryption with a key derived from a passphrase or the OS keystore; app lock; no network calls unless the user turns a feature on.

## Decisions

| # | Decision | ADR |
|---|---|---|
| 1 | Mobile + desktop from one codebase (Android, iOS, Windows, macOS, Linux) | [0001](adr/0001-platform-mobile-and-desktop.md) |
| 2 | Flutter + Dart; drift (SQLite), Riverpod, go_router | [0002](adr/0002-stack-flutter.md) |
| 3 | AGPL-3.0 | [0003](adr/0003-license-agpl.md) |
| 4 | Plain SQLite for MVP; encryption seam in `connection.dart`; SQLCipher in Phase 2 | [0004](adr/0004-encryption-deferred.md) |

## Code layout

```
lib/
  main.dart             ProviderScope + app
  app/                  app widget, router, adaptive shell, providers (DI)
  core/
    db/                 drift tables, AppDatabase, connection (encryption seam)
    ids.dart            UUID v7
    units.dart          canonical units + measurement types
  data/                 repositories (every write also appends to change_log)
  features/             one folder per module: today, health, fitness, nutrition, habits
test/                   repository/DB tests on in-memory SQLite
```

## Still open

- **Sync approach** (Phase 3): the change log and UUID v7 ids keep the options open.
- **Health platform integrations**: the `health` Flutter plugin vs. custom platform channels.
- **Offline food database**: source and size.
