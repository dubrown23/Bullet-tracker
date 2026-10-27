# Project Status

**Last updated:** 2026-10-27

Fast-changing state, written as a story for re-entry. Mechanical facts (bead counts, what's shipped vs. queued) live in `.beads/` and `bead-doctor`; the "why" behind decisions and the full record of every shipped bead live in `ARCHITECTURE.md` → Build Log.

---

## Where we are

Bullet Tracker is a working personal habit app on SwiftData + CloudKit, brought up to the iPhone Duo and Apple's current design language over 2026-10-24/25 (`bt-0008` → `bt-0016`): iOS 26 target, size-class-aware layout, system chrome everywhere, the **week-grid** Today row, one **win rule**, a consistency pass, and a **tappable tile-grid widget** Dustin confirmed on his Duo.

On 2026-10-26/27 the long-planned merge with **Dustin's Health** went from design to live in three beads. The design (shared note `~/Desktop/Personal/dustin-system/memory/in_flight/habits-voice-dh-bullet-2026-10-26.md`): Dustin talks to Claude on his iPhone; voice lands in dustin-health (dh) as day facts + an inbox of actions; **Bullet pulls and grades everything itself**. `bt-0017` (Step 0) proved the pipeline with fake data and a deterministic duplicate cleanup. `bt-0018` (Step 2) added the rules: a neutral **Rest** grade, **targets as habit settings** with a stamped go-live day, **Today in progress**, and a **source** (auto / hand / voice) on every entry so hand grades win until "Back to Automatic", with **only the iPhone writing automatic grades**.

**`bt-0019` (Step 3) is live as of 2026-10-27 afternoon.** The iPhone holds the app's key to dh in its Keychain (pasted once in Settings → Dustin's Health) and syncs on open and on pull-down: it sends the habit list, targets and today's taps, pulls changed days, meal and workout facts and the voice inbox, applies voice actions through the tap path (a note adds details only), confirms back, and grades with its own rules. **The real Diet and Workout are graded from real data from 2026-10-27 forward**; every earlier day stays as Dustin set it. The iPad never calls dh; it shows what iCloud brings. Dustin's device pass covered every check, including both directions of a past-day re-grade and a voice override holding against the facts. One fix came out of the pass: a "+" in dh's changes cursor had to be percent-encoded.

Standing rule, in Dustin's words: **use Apple's guidelines whenever possible.** No one-offs: fix the pattern, not the instance. Pass tests force the failure state; they don't wait for it to happen by luck. Device pass tests are walked **one action at a time**: "Do: … / You should see: …", then wait.

Harness facts worth knowing: Xcode 27 has no Simulator.app, the Duo simulator only shows the folded panel, so regular-width checks run on the iPad Air sim and the real look is checked on Dustin's devices (`DBd` iPhone, `Dustin's iPad (3)`). One device-interaction session at a time; check the run destination before any run (it has been his phone). The app target's folders are plain Xcode groups and a hook blocks direct `project.pbxproj` edits: create new files with `XcodeWrite` into an existing group and Xcode adds them to the target itself.

## Next (1–3)

1. **`bt-0020` — send hand taps to dh automatically.** A tap only reaches dh on the next sync today (open or pull-down), so "what's left today" by voice can lag behind what Dustin tapped. Wanted: a quiet sync a few seconds after any hand tap (Today, Log Details, widget), several taps → one sync, iPhone only. Queued with Why + Out of scope; plan at the next session.
2. **dh-side loose ends from the Step 3 pass** (for the dh session, not Bullet): Claude voice can log and correct a meal but has no "delete a meal" tool; the zero-calorie "Test meal" row dated 2026-10-26 should be deleted from the food log.
3. **Page-by-page reassessment, starting with the Dashboard.** Still the design thread from 2026-10-25: job first, then design; one page per turn, renders before approval. Then habit detail, Journal, Settings / forms, Log Details.

## Open threads

- **Claude voice drops the word "test" from habit names** ("Test Sauna" → "Sauna"). dh matches names exactly, so this is the voice side, not the sync. Real habit names work. Keep test habits for in-app checks only.
- **A plain tick shows no "By voice" in the UI.** The source line lives in Log Details and only for graded habits (bt-0018 design). Fine for now; a Today-page design call if Dustin wants to see who ticked what.
- **Confirm on the iPad that the four test habits are gone** once iCloud delivers the delete (removed from the iPhone at go-live).
- The shared design note's RESUME HERE line (dustin-system) still says the Vercel key isn't set; it is, and Step 3 is live. ds owns that file.
- The Settings **"iCloud Sync" toggle is cosmetic**: it saves a preference and posts a notification nothing listens to; `DataStore` always syncs. Remove or wire it when Settings gets its reassessment pass.
- The **widget keeps its own copy of the tick logic** (`CompleteHabitIntent` in `BulletTrackerWidgetsBundle.swift`), not `HabitStore.setCompletion`. It stamps source = hand + edit time like a tap; still a second copy to keep in step (and `bt-0020` will need a hook there too).
- **Streak flame appears only once today is done.** Pre-existing: a habit done yesterday but not yet today shows no flame. Dustin may want the live streak shown while today is still open — a Today-page design call.
- Lock Screen / StandBy widget families not started (`bt-0016` did the Home Screen).
- iPad landscape with the sidebar shown puts the weekday letters ~10 pt off the squares (`bt-0014`). Cosmetic.
- Accent orange as a control tint sits below WCAG text contrast; Apple ships system orange the same way. Brand call, left in `bt-0012`.
- `'NSKeyedUnarchiveFromData' should not be used…` console deprecation since `bt-0007`: park.

## Recent

- **2026-10-27 afternoon (`bt-0019`).** Dustin asked for Step 3 planned first, against the live server contract. Plan read right; he added four points (dh had already withdrawn the morning's voice-test rows; trim the pasted key; a voice note adds details only and never blocks the grade; delete the test meal and check the re-grade back) and said go. Built in one sitting, 71 tests. He took the iPhone backup first, then I installed on both devices; the key went Mac Keychain → clipboard → Universal Clipboard, never printed. The first real sync connected and the day's real Workout note landed in the Journal. The second failed on dh's changes cursor (a "+" read as a space) — fixed, tested, reinstalled. He asked for one action at a time from there, and the pass ran that way: voice tick, hand ticks reaching "what's left today", real-meal captions, past-day re-grade both ways, a hand override held and dropped, a voice target held, iPad read-only, widget. Claude voice dropped "test" from every test-habit name, so voice checks ran on real habits. Go-live the same afternoon: real Diet and Workout graded, "call diet partial" and "back on auto" by voice, a real treadmill walk turning Workout green. Queued `bt-0020`.
- **2026-10-27 morning (`bt-0018`).** Dustin arrived with dh Step 1 live and asked for Step 2 planned first. Plan reviewed; he added three rules (go-live guard on Back to Automatic, iPhone-only grader, real habits stay Off) and said go. Built in plan order, 55 tests. A process miss on my side: the run destination was still his phone, so the first build landed on DBd before go. The simulator pass found three things (a sync could hang on the Health permission sheet, the live caption truncated on the folded panel, "Remove test habits" crashed on a deleted model); all fixed. Device pass by Dustin: all six checks, including the widget tile grey with zzz.
- **2026-10-26 (`bt-0017`).** Dustin arrived with the settled voice design and asked for Step 0 first. Plan reviewed and corrected by Dustin before building: the duplicate-cleanup rule must pick the same row on every device, and the pass test must force the duplicate. The airplane-mode protocol produced no duplicate; replaced with an on-screen row-id readout and an "add a duplicate row" button; that round passed (2 → 1 → 1, same id on both, never 0). Steps matched Health.

## Where things live

| What | Where |
|------|-------|
| How we work, conventions | `CLAUDE.md` |
| Vision, founding decisions, every shipped bead's Why + Decision log | `ARCHITECTURE.md` |
| Active beads (`bt-NNNN`) | `.beads/active/` |
| Voice / dh design (shared contract, three parts) | `~/Desktop/Personal/dustin-system/memory/in_flight/habits-voice-dh-bullet-2026-10-26.md` |
| dh server contract | `~/Desktop/Personal/dustin-health/api/bullet.js` (ops sync / changes / facts / inbox / ack), `supabase/migrations/0011_habit_inbox.sql`; key in Vercel `BULLET_API_KEY`, Mac Keychain copy `dustin-health-bullet-api-key` |
| Sync layer | `Sync/` — `HabitFactsSource` (protocol + selectable fake), `DustinHealthSource` (`APIKeyStore` Keychain, `DustinHealthClient`, `DustinHealthWire`, `DustinHealthFacts`), `HabitGrading` (Diet / Workout / in-progress rules, voice grade mapping), `HabitSyncEngine` (one run: sync → changes → inbox → facts → grade → cleanup; status + cursor; iPhone-only), `HealthSteps`; `HabitStore.dedupeEntries / mergeDetails / addJournalNote` in `Habits/HabitDataRepository.swift` |
| Settings → Dustin's Health (key, status, Couldn't apply, Remove key; iPad line) | `App/HealthSyncSettingsView.swift` |
| Grading settings + Rest + targets | `Habit.gradingKind / gradingSince / target*`, `TargetKey`, `HabitEntry.sourceRaw / editedAt`, `CompletionState.rest`, `GradingTargets` — all in `Data/Models.swift`; form section in `Habits/HabitFormView.swift` |
| Developer screen (debug builds) | Settings → Developer → `App/DeveloperSyncView.swift` (fake switch, Run now = real sync when off, rows readout, dh key presence) |
| Design rules in code | `Utilities/DesignSystem.swift`, `App/AppTheme.swift`, `HabitWinRule` in `Data/Models.swift` |
| Widget | `BulletTrackerWidgets/BulletTrackerWidgetsBundle.swift` |
| Project memory for Claude | Xcode CodingAssistant auto-memory |
