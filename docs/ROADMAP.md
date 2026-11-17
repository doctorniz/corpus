# Roadmap

## Done

- [x] Decisions on platform, stack, license, encryption, health sync, food data, iOS delivery ([ADRs](adr/))
- [x] Database schema v2, migrations, change log, persistent device id
- [x] All six areas usable: Health, Fitness, Sleep, Nutrition, Women's health, Habits
- [x] **+** sheet to log anything
- [x] Two-way sync with Health Connect (verified on an Android emulator) and Apple Health (written, not yet run on a device)
- [x] Bundled offline food database
- [x] JSON export
- [x] CI: generated code, format, analyze, tests, Android build, unsigned iOS build
- [x] TestFlight workflow (needs Apple secrets before its first run)

## Next

- [ ] First TestFlight build; test HealthKit on a real iPhone
- [ ] Test on a real Android phone with a tracker feeding Health Connect
- [ ] Edit saved workouts, sleep and meals; propagate deletes to the health store
- [ ] App icon and splash screen
- [ ] Import from a JSON export; encrypted backup file
- [ ] Encryption at rest and app lock
- [ ] Medication reminders and dose log; habit reminders
- [ ] Doctor-ready PDF summary
- [ ] Choose which tabs sit in the bottom bar

## Later

- [ ] Recipes, micronutrients, barcode / branded foods (opt-in online lookup)
- [ ] Health Connect history beyond 30 days; background sync
- [ ] GPX/FIT import, workout templates
- [ ] Cross-area insights (sleep vs. training, nutrition vs. weight)
- [ ] Multi-device sync, multiple profiles
- [ ] Play Store / App Store release (privacy policy, store listings, health-data declarations)
