# ADR 0005: Two-way sync with Apple Health and Health Connect

- Status: Accepted
- Date: 2026-11-17

## Decision
- Corpus reads from and writes to the phone's health store (HealthKit on iOS, Health Connect on Android) through the `health` Flutter plugin.
- Fitness trackers are not paired directly. Any watch or band that syncs to the health store (Apple Watch, Garmin, Fitbit, Samsung, Oura…) reaches Corpus that way.
- Sync is off until the user turns it on in Settings.

## Consequences
- No per-device Bluetooth work, and no network access: both stores are on-device.
- Duplicates are avoided in both directions: imported rows carry an `external_id`; rows Corpus wrote are skipped on import by source id; imported rows are never written back.
- Known gaps: deletes and edits in Corpus are not propagated; Health Connect only exposes the 30 days before permission was granted unless history access is requested; no background sync.
- Adding a data type means updating three places: `health_sync.dart`, the Android manifest permissions, and (for App Store review) the declared HealthKit usage.
