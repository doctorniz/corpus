# ADR 0007: Build and ship iOS through GitHub Actions

- Status: Accepted
- Date: 2026-11-17

## Context
Development happens on Windows, which cannot build iOS apps.

## Decision
- `ci.yml` compiles the iOS app unsigned on a macOS runner for every push.
- `testflight.yml` builds a signed app and uploads it to TestFlight, on demand or on a `v*` tag, using a distribution certificate, provisioning profile and App Store Connect API key stored as repository secrets.

## Consequences
- An iPhone build is possible without owning a Mac, at the cost of a paid Apple Developer account and a one-time setup ([docs/IOS_RELEASE.md](../IOS_RELEASE.md)).
- iOS-only behaviour (HealthKit in particular) can only be tested on a real iPhone via TestFlight; there is no local iOS debugging.
- macOS runner minutes are billed at a higher rate on private repositories; this repository is public, where they are free.
