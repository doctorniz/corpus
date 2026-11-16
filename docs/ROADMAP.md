# Roadmap (draft)

## Phase 0: Foundations
- [x] Decide platform, stack, license and encryption (see [ADRs](adr/))
- [x] Project scaffold, SQLite schema v1 (profiles, measurements, change_log), migration hook
- [x] Unit utilities; UTC + offset time storage
- [ ] Persist the device id across launches
- [ ] Export format v1 (JSON)
- [x] CI (GitHub Actions: codegen up to date, format, analyze, test, Android debug build)

## Phase 1: MVP ("usable daily")
- Profile and health booklet basics: conditions, medications, allergies, vaccinations
- Generic measurements: weight, vitals, steps, sleep
- Workout logging with exercise library and templates
- Meal logging with a bundled offline food DB and calorie/macro targets
- Habits with streaks; daily mood/energy check-in
- Today view, unified timeline, quick-add
- Full JSON/CSV export and import; local backup file

## Phase 2: Depth & insight
- Lab results with reference ranges; visits; document vault
- Charts and trends for every measurement; PRs and training volume
- Weekly summaries and cross-domain correlations
- Local reminders (medications, habits, water)
- Encryption at rest and app lock
- Doctor summary PDF export

## Phase 3: Connect
- Imports: Apple Health, Health Connect, GPX/FIT, CSV from other apps
- E2E-encrypted multi-device sync
- Barcode scanning
- Multiple profiles (family)

## Later / ideas
- Optional on-device AI summaries and Q&A over your own data
- Cycle tracking, symptom tracking
- Plugin/extension system for custom trackers
