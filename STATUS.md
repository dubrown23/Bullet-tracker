# Project Status

**Last updated:** 2026-10-26

Fast-changing state, written as a story for re-entry. Mechanical facts (bead counts, what's shipped vs. queued) live in `.beads/` and `bead-doctor`; the "why" behind decisions and the full record of every shipped bead live in `ARCHITECTURE.md` → Build Log.

---

## Where we are

Bullet Tracker is a working personal habit app on SwiftData + CloudKit, brought up to the iPhone Duo and Apple's current design language over 2026-10-24/25 (`bt-0008` → `bt-0016`): iOS 26 target, size-class-aware layout, system chrome everywhere, the **week-grid** Today row, one **win rule**, a consistency pass, and a **tappable tile-grid widget** Dustin confirmed on his Duo.

On 2026-10-26 the long-planned merge with **Dustin's Health** started. The design, settled in a dustin-system session (shared note `~/Desktop/Personal/dustin-system/memory/in_flight/habits-voice-dh-bullet-2026-10-26.md`): Dustin talks to Claude on his iPhone; voice lands in dustin-health (dh) as day facts + an inbox of actions; **Bullet pulls and grades everything itself** (the app holds every rule, dh only reports facts). `bt-0017` was Step 0, the proof with fake data and no server: a `Sync/` layer (facts protocol with a fake source, pure grading rules, a sync engine that writes through the same path a tap uses, steps from HealthKit) plus a debug-only Developer screen in Settings. **Passed on iPhone + iPad + widget**, including the hard part: two devices holding two rows for the same habit-day, merged back to one by a deterministic cleanup pass (smallest id wins; a device never deletes unless it sees two or more rows, so zero is unreachable). dh's Step 1 is unblocked.

Standing rule, in Dustin's words: **use Apple's guidelines whenever possible.** No one-offs: fix the pattern, not the instance. Pass tests force the failure state; they don't wait for it to happen by luck.

Harness facts worth knowing: Xcode 27 has no Simulator.app, the Duo simulator only shows the folded panel, so regular-width checks run on the iPad Air sim and the real look is checked on Dustin's devices (`DBd` iPhone, `Dustin's iPad (3)` now paired). One device-interaction session at a time. The app target's folders are plain Xcode groups, not synchronized ones: a new folder needs Sources entries added by hand (`bt-0017` did it in `project.pbxproj`).

## Next (1–3)

1. **`bt-0018` — Step 2 of the voice design, independent of dh.** Rest grade, targets as settings, Today in progress, back to auto (needs an additive source marker + edit time on entries). Queued, design pass when picked up.
2. **Step 3 — the real sync.** Point `HabitSyncEngine` at dh once dh ships Step 1 (inbox, six voice tools, day facts, changed-days list, habits/targets upload). Needs the app's own key to dh. Not a bead yet; shape it when dh is ready.
3. **Page-by-page reassessment, starting with the Dashboard.** Still the design thread from 2026-10-25: job first, then design; one page per turn, renders before approval. Then habit detail, Journal, Settings / forms, Log Details.

## Open threads

- The Settings **"iCloud Sync" toggle is cosmetic**: it saves a preference and posts a notification nothing listens to; `DataStore` always syncs. Remove or wire it when Settings gets its reassessment pass.
- The **widget keeps its own copy of the tick logic** (`CompleteHabitIntent` in `BulletTrackerWidgetsBundle.swift`), not `HabitStore.setCompletion`. Fine today; must share the write path before the widget writes anything the sync relies on.
- Lock Screen / StandBy widget families not started (`bt-0016` did the Home Screen).
- iPad landscape with the sidebar shown puts the weekday letters ~10 pt off the squares (`bt-0014`). Cosmetic.
- Accent orange as a control tint sits below WCAG text contrast; Apple ships system orange the same way. Brand call, left in `bt-0012`.
- `'NSKeyedUnarchiveFromData' should not be used…` console deprecation since `bt-0007`: park.

## Recent

- **2026-10-26 (`bt-0017`).** Dustin arrived with the settled voice design and asked for Step 0 first. Plan reviewed and corrected by Dustin before building: the duplicate-cleanup rule must pick the same row on every device (no edit time exists, so by id), and the pass test must force the duplicate. Built in one sitting, iPhone half passed, then the iPad arrived: paired to the Mac for the first time, and two rounds of the airplane-mode protocol produced no duplicate because the iPad already held the iPhone's row and updated it in place. Replaced with an on-screen row-id readout and an "add a duplicate row" button that creates the two-device state deliberately; that round passed (2 → 1 → 1, same id on both, never 0). Steps matched Health. Test habits removed on both devices.
- **2026-10-25 (long session, `bt-0010` → `bt-0016`).** Design language wave, then a run of corrections driven by Dustin using the app on the Duo: design sweep (`bt-0012`), week-grid Today row (`bt-0013`), win rule + honest header (`bt-0014`), consistency pass (`bt-0015`), widget mirroring the row (`bt-0011`) and the tile-grid widget (`bt-0016`).
- **2026-10-24 (`bt-0008`, `bt-0009`).** Duo arrives. Two audits → four-bead plan. Foundation (iOS 26 target, legacy APIs out, `Tab` API) and Duo layout (two-per-row in regular width).

## Where things live

| What | Where |
|------|-------|
| How we work, conventions | `CLAUDE.md` |
| Vision, founding decisions, every shipped bead's Why + Decision log | `ARCHITECTURE.md` |
| Active beads (`bt-NNNN`) | `.beads/active/` |
| Voice / dh design (shared contract, three parts) | `~/Desktop/Personal/dustin-system/memory/in_flight/habits-voice-dh-bullet-2026-10-26.md` |
| Sync layer | `Sync/` — `HabitFactsSource` (protocol + fake), `HabitGrading` (rules + targets), `HabitSyncEngine`, `HealthSteps`; `HabitStore.dedupeEntries` in `Habits/HabitDataRepository.swift` |
| Developer screen (debug builds) | Settings → Developer → `App/DeveloperSyncView.swift` |
| Design rules in code | `Utilities/DesignSystem.swift`, `App/AppTheme.swift`, `HabitWinRule` in `Data/Models.swift` |
| Widget | `BulletTrackerWidgets/BulletTrackerWidgetsBundle.swift` |
| Project memory for Claude | Xcode CodingAssistant auto-memory |
