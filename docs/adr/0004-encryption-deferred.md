# ADR 0004: Plain SQLite for MVP, with an encryption seam

- Status: Accepted
- Date: 2026-11-13

## Context
Health data is sensitive, but SQLCipher adds build complexity across five platforms, and an encrypted DB is harder to inspect while the schema is still changing.

## Decision
- The MVP uses unencrypted SQLite, stored in the app-private support directory.
- The database is opened in exactly one place: `lib/core/db/connection.dart`. Nothing above the repository layer knows how the store is opened.
- Encryption at rest (SQLCipher plus passphrase/OS keystore) and app lock arrive in Phase 2.

## Consequences
- Moving to encryption later needs a one-time migration: export plain → import encrypted (or `sqlcipher_export`).
- Until then, OS-level protection (device encryption, app sandbox) is the only safeguard. The README must say so clearly.
