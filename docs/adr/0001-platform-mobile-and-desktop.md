# ADR 0001: Target mobile and desktop from day one

- Status: Accepted
- Date: 2026-11-13

## Context
Daily logging (meals, sets, habits) happens on a phone. Managing health records, documents and long-term trends is easier on a large screen.

## Decision
Ship Android, iOS, Windows, macOS and Linux from a single codebase. The web is not a target for now.

## Consequences
- The UI must be adaptive: bottom navigation on narrow screens, a navigation rail on wide ones (`lib/app/shell.dart`).
- Multi-device use makes sync more valuable, but sync stays in Phase 3 (see ROADMAP).
- iOS/macOS builds need a Mac; CI should cover the other platforms.
