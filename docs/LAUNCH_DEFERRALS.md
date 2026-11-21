# Pre-launch deferrals

Known gaps and the things only a person can check, **logged for review
before a store release**. Adapted from Mentis's file of the same name.

**Structure**

1. **Open deferrals** — work still open.
2. **Manual verification** — human checks: **To do** (`- [ ]`) vs **Done** (`- [x]`).
3. **Addressed (archive)** — closed items; reopen one if it regresses.

**Workflow**

- New gap: add it under **Open deferrals** with an ID.
- Fixed: move it to the archive, and add or refresh its **Manual
  verification** bullet in the same change when it needs re-checking.
- PRs: repeat the **To do** items they touch under "Not tested" so a
  reviewer sees them.
- Planned features live in [`ROADMAP.md`](./ROADMAP.md); this file is for
  gaps in what exists.

---

## Open deferrals

| Area         | ID | Topic                              | Notes |
| ------------ | -- | ---------------------------------- | ----- |
| Structure    | B1 | + sheet imports every feature      | `features/capture` opens each area's forms directly. Should go through a registry of capture actions in `app/` or `ui/`, as Mentis's capture destinations do. Allowed in `test/boundaries_test.dart` until then. |
| Structure    | B2 | Fitness uses Health's vitals screen | `features/fitness` imports `features/health/vitals_screen.dart` for the weight trend. Move the shared chart to `ui/`. |
| Performance  | P1 | Cold start unmeasured on a phone   | Budget 1.8 s. The Android emulator (software rendering) takes 6.3–7.0 s, which says nothing about a phone. Measure on a real device; if over, profile the database open and first queries. |
| Performance  | P2 | Export runs on the UI isolate      | `data/export_service.dart` builds and encodes the JSON on the UI isolate (principle 5). Fine for small records; move the encode to `compute` before records grow. |
| Health sync  | H1 | Deletes are not propagated         | Deleting an entry in Corpus leaves the copy written to Apple Health / Health Connect. |
| Health sync  | H2 | 30 days of history                 | The first sync imports 30 days; older data is not fetched. |
| Editing      | D1 | Saved entries cannot be edited     | Workouts, sleep and meals can be deleted and re-entered, not edited. |
| Security     | S1 | Database not encrypted             | ADR 0004; relies on device encryption. No app lock. |
| Look         | L1 | No app icon or splash screen       | Still Flutter's defaults. |
| Look         | L2 | "Good" green beside the accent     | `success` (#2F9E44) marks targets met; it sits close to the sage accent. Decide whether to keep or align it. |

---

## Manual verification queue

**Format:** `- [ ]` = to run; `- [x]` = verified (with a short date).

### To do

- [ ] **First TestFlight build** installs and opens on a physical iPhone (`docs/IOS_RELEASE.md`).
- [ ] **Apple Health on a real iPhone:** grant access; steps, workouts, sleep, weight and cycle import; a weight, sleep and workout logged in Corpus appear in Apple Health.
- [ ] **Health Connect with a tracker** on a real Android phone: a watch's steps, workouts and sleep arrive in Corpus.
- [ ] **Cold start on a phone** under 1.8 s (P1).
- [ ] **Attachments:** add a photo from the camera and a PDF from files to a clinic letter; both open again after restarting the app.
- [ ] **Export:** Settings › Export everything produces a file that opens and holds every area.
- [ ] **Drawer and theme on iPhone:** the left menu, the theme switch and dark mode look right (notch and home indicator clear).

### Done

- [x] Every tab, the + sheet, food search and logging, water, weight, sleep, workout, medication, period and habit — Android emulator, 2026-11.
- [x] Health Connect permission screen, a sync run, and write-back of weight, sleep and a workout — Android emulator, 2026-11.
- [x] The app runs end to end on an iPhone simulator up to Apple Health's permission sheet — CI, 2026-11.
- [x] Mentis-style masthead, left drawer, theme switch, green accent in light and dark — Android emulator, 2026-11-18.

---

## Addressed (archive)

| Area  | ID | Notes |
| ----- | -- | ----- |
| Cycle | C1 | "Average period 1 days" for a first period still in progress: an ongoing period is no longer averaged (2026-11). |
