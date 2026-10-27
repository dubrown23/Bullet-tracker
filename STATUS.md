# Project Status

**Last updated:** 2026-10-27

Fast-changing state, written as a story for re-entry. Mechanical facts (bead counts, what's shipped vs. queued) live in `.beads/` and `bead-doctor`; the "why" behind decisions and the full record of every shipped bead live in `ARCHITECTURE.md` → Build Log.

---

## Where we are

Bullet Tracker is a working personal habit app on SwiftData + CloudKit, brought up to the iPhone Duo and Apple's current design language over 2026-10-24/25 (`bt-0008` → `bt-0016`): iOS 26 target, size-class-aware layout, system chrome everywhere, the **week-grid** Today row, one **win rule**, a consistency pass, and a **tappable tile-grid widget** Dustin confirmed on his Duo.

On 2026-10-26 the long-planned merge with **Dustin's Health** started. The design, settled in a dustin-system session (shared note `~/Desktop/Personal/dustin-system/memory/in_flight/habits-voice-dh-bullet-2026-10-26.md`): Dustin talks to Claude on his iPhone; voice lands in dustin-health (dh) as day facts + an inbox of actions; **Bullet pulls and grades everything itself** (the app holds every rule, dh only reports facts). `bt-0017` was Step 0, the proof with fake data and no server: a `Sync/` layer (facts protocol with a fake source, pure grading rules, a sync engine that writes through the same path a tap uses, steps from HealthKit) plus a debug-only Developer screen in Settings. **Passed on iPhone + iPad + widget**, including the hard part: two devices holding two rows for the same habit-day, merged back to one by a deterministic cleanup pass (a device never deletes unless it sees two or more rows, so zero is unreachable).

On 2026-10-27 dh's Step 1 went live and passed Dustin's phone voice test, and Bullet shipped **Step 2 (`bt-0018`)** the same day: a **Rest** grade (neutral: not a win, not a miss, streak carries through; Workout only, set by long-press or Log Details, never by a plain tap), **targets as settings** on the habit ("Graded by: Off / Diet / Workout" + the numbers, synced by iCloud, blank = default), **Today in progress** (live numbers under the row, no colour until a target is hit, drop-back allowed, red only after midnight), and **Back to Automatic** (entries now carry a source — auto / hand / voice — and an edit time; old rows count as hand). Dustin's three rules from the plan review hold: Back to Automatic only on or after the habit's go-live day; **only the iPhone writes automatic grades** (the iPad shows them, never writes them); the real Diet / Workout stay **Off** until Step 3 brings real data. Passed on the simulators by device-driving agents and then by Dustin on iPhone, iPad and the widget.

Standing rule, in Dustin's words: **use Apple's guidelines whenever possible.** No one-offs: fix the pattern, not the instance. Pass tests force the failure state; they don't wait for it to happen by luck.

Harness facts worth knowing: Xcode 27 has no Simulator.app, the Duo simulator only shows the folded panel, so regular-width checks run on the iPad Air sim and the real look is checked on Dustin's devices (`DBd` iPhone, `Dustin's iPad (3)` now paired). One device-interaction session at a time. The app target's folders are plain Xcode groups, not synchronized ones: a new folder needs Sources entries added by hand (`bt-0017` did it in `project.pbxproj`).

## Next (1–3)

1. **Step 3 — the real sync.** Point `HabitSyncEngine` at dh (its Step 1 is live): a `HabitFactsSource` over `api/bullet.js` — send habits (name, kind, targets) on open, pull day facts for changed days + the inbox, re-grade changed days, apply the inbox (ticks, set grade / rest / back to auto, undo, note, target change), confirm back. Needs the app's own key (`BULLET_API_KEY`, not yet set in Vercel). Rules already in the engine: overrides win, go-live day, iPhone-only writes. Shape it as a bead at the next session.
2. **Switch the real Diet and Workout to "Graded by"** on the day Step 3 ships (that stamps the go-live day). Workout must be Multi-State first.
3. **Page-by-page reassessment, starting with the Dashboard.** Still the design thread from 2026-10-25: job first, then design; one page per turn, renders before approval. Then habit detail, Journal, Settings / forms, Log Details.

## Open threads

- The Settings **"iCloud Sync" toggle is cosmetic**: it saves a preference and posts a notification nothing listens to; `DataStore` always syncs. Remove or wire it when Settings gets its reassessment pass.
- The **widget keeps its own copy of the tick logic** (`CompleteHabitIntent` in `BulletTrackerWidgetsBundle.swift`), not `HabitStore.setCompletion`. It now stamps source = hand + edit time like a tap (`bt-0018`), so the grader respects widget taps; still a second copy to keep in step.
- **Streak flame appears only once today is done.** Pre-existing: a habit done yesterday but not yet today shows no flame (seen in the `bt-0018` pass test; a Rest day today shows it, correctly). Dustin may want the live streak shown while today is still open — a Today-page design call.
- **Test-habit names truncate on the folded panel** once a streak badge appears ("Test…"). Pre-existing with long names; real habit names are short. Watch when the Today page gets its design pass.
- Lock Screen / StandBy widget families not started (`bt-0016` did the Home Screen).
- iPad landscape with the sidebar shown puts the weekday letters ~10 pt off the squares (`bt-0014`). Cosmetic.
- Accent orange as a control tint sits below WCAG text contrast; Apple ships system orange the same way. Brand call, left in `bt-0012`.
- `'NSKeyedUnarchiveFromData' should not be used…` console deprecation since `bt-0007`: park.

## Recent

- **2026-10-27 (`bt-0018`).** Dustin arrived with dh Step 1 live and asked for Step 2 planned first. Plan reviewed; he added three rules (go-live guard on Back to Automatic, iPhone-only grader, real habits stay Off) and said go. Built in plan order, 55 tests. A process miss on my side: the run destination was still his phone, so the first build landed on DBd before go; he took the backup after and matched the iPad. The simulator pass (agents driving the Duo and iPad sims) found three things: a sync could hang on the Health permission sheet (now bounded), the live caption truncated on the folded panel (own line now), and **Remove test habits crashed** — the rows observe the engine's live numbers, so clearing them after the delete re-rendered a row against a deleted habit; `isDeleted` is only true while pending, so the guard is `modelContext == nil` too. Device pass by Dustin: all six, including the widget tile grey with zzz after a Developer button put Test Workout first. Test habits removed.
- **2026-10-26 (`bt-0017`).** Dustin arrived with the settled voice design and asked for Step 0 first. Plan reviewed and corrected by Dustin before building: the duplicate-cleanup rule must pick the same row on every device (no edit time exists, so by id), and the pass test must force the duplicate. Built in one sitting, iPhone half passed, then the iPad arrived: paired to the Mac for the first time, and two rounds of the airplane-mode protocol produced no duplicate because the iPad already held the iPhone's row and updated it in place. Replaced with an on-screen row-id readout and an "add a duplicate row" button that creates the two-device state deliberately; that round passed (2 → 1 → 1, same id on both, never 0). Steps matched Health. Test habits removed on both devices.
- **2026-10-25 (long session, `bt-0010` → `bt-0016`).** Design language wave, then a run of corrections driven by Dustin using the app on the Duo: design sweep (`bt-0012`), week-grid Today row (`bt-0013`), win rule + honest header (`bt-0014`), consistency pass (`bt-0015`), widget mirroring the row (`bt-0011`) and the tile-grid widget (`bt-0016`).

## Where things live

| What | Where |
|------|-------|
| How we work, conventions | `CLAUDE.md` |
| Vision, founding decisions, every shipped bead's Why + Decision log | `ARCHITECTURE.md` |
| Active beads (`bt-NNNN`) | `.beads/active/` |
| Voice / dh design (shared contract, three parts) | `~/Desktop/Personal/dustin-system/memory/in_flight/habits-voice-dh-bullet-2026-10-26.md` |
| Sync layer | `Sync/` — `HabitFactsSource` (protocol + selectable fake), `HabitGrading` (Diet / Workout / in-progress rules), `HabitSyncEngine` (go-live window, iPhone-only writes, live facts, Back to Automatic), `HealthSteps`; `HabitStore.dedupeEntries` (hand > auto > newest > smallest id) in `Habits/HabitDataRepository.swift` |
| Grading settings + Rest | `Habit.gradingKind / gradingSince / target*`, `HabitEntry.sourceRaw / editedAt`, `CompletionState.rest`, `GradingTargets` — all in `Data/Models.swift`; form section in `Habits/HabitFormView.swift` |
| Developer screen (debug builds) | Settings → Developer → `App/DeveloperSyncView.swift` |
| Design rules in code | `Utilities/DesignSystem.swift`, `App/AppTheme.swift`, `HabitWinRule` in `Data/Models.swift` |
| Widget | `BulletTrackerWidgets/BulletTrackerWidgetsBundle.swift` |
| Project memory for Claude | Xcode CodingAssistant auto-memory |
