# Project Status

**Last updated:** 2026-05-13 (`bt-0003` **in build through Wave 3.5; verified end-to-end on device** — Waves 0 / 1 / 2 / 3 / 3.5 all shipped to `swiftdata-phase2` branch with commits; Path 3 (wipe + restore via `BackupManager`) absorbed **two** SwiftData rejection failures (Wave 1 schema-shrink crash + Wave 3.5 Codable-enum-as-attribute crash) and recovered cleanly each time. Wave 3.5 was a bt-0004-class hotfix: `HabitEntry.details` is now a computed property over a stored `String?` column (`detailsJSON`) — same legacy JSON wire shape `BackupManager` already speaks; consumer API unchanged. Today / Dashboard / Journal / detail-capture all working against real data. CloudKit remains disabled (`cloudKitDatabase: .none`) for build duration; re-enabled at Wave 5 ship. Wave 4 (hot-path predicate rewrites) is next. Punted: `Bullet TrackerTests/Bullet_TrackerTests.swift` cleanup before Wave 5.)

Fast-changing state. For the "why" behind any decision, see `ARCHITECTURE.md`.

---

## Live

- Bullet Tracker iOS app (SwiftUI, Core Data + CloudKit, App Group widget). Working app; ~v1.5-era feature set, mid-cleanup.
- 2026-05-12: adopted the bead / three-doc / skill system; ran a fresh-eyes architecture read pass — see `ARCHITECTURE.md` and `bt-0001`. Patchwork flags identified (#1–#9 in session notes): three overlapping data layers, `details` JSON blob, completion state modeled 3 ways, name-keyword workout detection, half-refactored repo layout, custom Core Data vs. SwiftData, cache-thrash, calc-service concurrency, hand-rolled backup mirrors + vestigial Journal future-log fields.

## In progress

- `bt-0003` — SwiftData Phase 2. **In build on `swiftdata-phase2` branch through Wave 3.5; device-verified.** Waves 0 (backup-restore `@MainActor`), 1 (drop dormant machinery + Path 3 recovery validated), 2 (combined schema changes), 3 (consumer rewrites — 15 files), 3.5 (`HabitEntry.details` storage hotfix — computed property over stored `String?` after bt-0004-class SwiftData rejection) all shipped to branch with commits. CloudKit temporarily disabled (`cloudKitDatabase: .none`) for build duration; re-enabled at Wave 5 ship. Wave 4 (hot-path predicate rewrites) is the next code wave.

### Queued (backlog)

- _(none)_

## Next (1–3 items)

1. **bt-0003 Wave 4 — hot-path predicate rewrites.** `HabitDataRepository`'s 3 in-Swift-filter reads (`entry(for:on:)`, `entriesByDay`, `allEntriesByDay`) + 2 widget per-habit reads → `FetchDescriptor<HabitEntry>` + `#Predicate` on `habit.id` + date range + fetch limit. `bt-0004`'s `#Index<HabitEntry>([\.date])` already carries the read-cost win; the non-optional `date` from Wave 2 unblocks the predicate (was the reason `bt-0004` deferred). Smoke build clean at end of wave; another wipe-and-restore cycle if device test needs it. ~50 lines, mechanical.
2. **bt-0003 Wave 5 — ship.** Re-enable CloudKit (`cloudKitDatabase: .automatic` in `DataStore.swift`). Take a fresh backup; wipe iCloud's side via Settings → name → iCloud → Manage Account Storage (if Bullet Tracker appears there); reinstall + restore; cross-device sync verification if available. Merge `swiftdata-phase2` → `main`. **Pre-ship cleanup:** `Bullet TrackerTests/Bullet_TrackerTests.swift` (punted in Wave 3 — references legacy `entry.completionState > 0` patterns that won't compile against the new model).
3. (Independent, anytime) Repo-layout cleanup — finish the folder refactor, delete `WidgetEnums.txt` / committed `.DS_Store`s, archive the old `Documentation/` files.

## Open questions / blockers

- ~~Data foundation: stay on custom Core Data or migrate to SwiftData?~~ — **resolved 2026-05-12: migrate to SwiftData, two-phase** (`bt-0001`).
- ~~What is the Journal "future log / migration" feature meant to do?~~ — **resolved 2026-05-13:** drop the dormant `JournalEntry`/`Collection`/`Tag` machinery entirely (leftover from the original bullet-journal vision, never wired to UI; live Journal tab is on `Note`). Scope folded into `bt-0003`; reading the code surfaced that the issue was the whole dormant model, not just the 7 fields the patchwork-flags-review captured.

## Recent build (last 3)

_(Newest on top. When a 4th lands, oldest migrates to `ARCHITECTURE.md` → Build Log.)_

- `bt-0004` (shipped 2026-05-13) — **SwiftData data-layer perf pass — indexes-only ship; predicate rewrite deferred to `bt-0003`.** Original four-decision plan: (1) hot-path predicate rewrite, (2) date indexes, (3) cold paths untouched, (4) no `ModelActor`. Build phase surfaced that SwiftData's `#Predicate` on this iOS version rejects every shape of optional-`Date` comparison tried (force-unwrap, inline nil-coalesce, captured-local sentinel) — `Date?` would need to become `Date`, which requires a SwiftData `VersionedSchema` migration against the live CloudKit-synced store. That belongs in `bt-0003`'s model-restructure surface, not as a one-off scope expansion here. Net shipped: two `#Index` lines in `Data/Models.swift` (`HabitEntry.date` + `JournalEntry.date`) — re-creates the `byDateIndex` fetch index the original `.xcdatamodeld` had, making any future date-filtered query cheap (including `bt-0003`'s eventual predicate rewrite). Reverted predicate-rewrite attempts in `HabitDataRepository.swift` and `BulletTrackerWidgetsBundle.swift` back to pre-bt-0004 state (kept in `scope_files` as authorization record). Smoke build clean; device-validation on next app-open (schema change is index-add only, no new entities — Apple docs say lightweight `CREATE INDEX` on first launch). Full Decision log in `bt-0004` including the design pass, the Decision-2-was-wrong correction caught mid-build, and the scope-pivot reasoning.
- `bt-0002` (shipped 2026-05-13, merge `ba1edde`) — **SwiftData migration Phase 1 — engine swap, model shape unchanged.** Replaced the hand-rolled Core Data stack (`NSPersistentCloudKitContainer` + `CoreDataManager` + `HabitDataRepository` cache + `@unchecked Sendable` calc service + the `NSManagedObjectContextDidSave` merge listener) with `@Model` types behind one `ModelContainer` (`DataStore.shared`) sharing the existing App-Group SQLite store in place; CloudKit sync continues via `cloudKitDatabase: .automatic`. Six waves on the `swiftdata-migration` branch: baseline `@Model` types → DataStore wiring → Habits surface (flags #4 + #8 folded) → Notes/Settings/Backup/Journal-export → DayJournalView → widget extension → delete the stack. **Net: +1387 / −2070 = 683 fewer lines** across 35 files for the same functionality. Device-tested 1-5 of 6 (cross-device CloudKit verified 2026-05-13 — iPad pickup of 3-4 same-day habit completions; backup round-trip still deferred, low-risk). Full Decision log in `bt-0002`.
- `bt-0001` (shipped 2026-05-12) — **decided the data foundation: migrate to SwiftData, two-phase.** Was the decision bead; design pass run this session. Build work → `bt-0002` (P1) + a future `bt-0003` (P2). Full Why + Decision log in the bead file.
