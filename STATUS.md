# Project Status

**Last updated:** 2026-05-13 (`bt-0004` **SHIPPED indexes-only** — two `#Index` lines on `HabitEntry.date` + `JournalEntry.date` in `Data/Models.swift`; smoke build clean, device-validation on next app-open. Hot-path predicate rewrite (bead's original item 1) **deferred to `bt-0003`** — `#Predicate` over optional `Date?` fails to compile on this SwiftData version; structurally correct fix is folding the legacy-optional lift into `bt-0003`'s model-restructure surface where the `VersionedSchema` migration belongs. Active in_progress beads: none. Queued: none. Next = shape `bt-0003` Phase 2 when the #9 Journal-intent question lands.)

Fast-changing state. For the "why" behind any decision, see `ARCHITECTURE.md`.

---

## Live

- Bullet Tracker iOS app (SwiftUI, Core Data + CloudKit, App Group widget). Working app; ~v1.5-era feature set, mid-cleanup.
- 2026-05-12: adopted the bead / three-doc / skill system; ran a fresh-eyes architecture read pass — see `ARCHITECTURE.md` and `bt-0001`. Patchwork flags identified (#1–#9 in session notes): three overlapping data layers, `details` JSON blob, completion state modeled 3 ways, name-keyword workout detection, half-refactored repo layout, custom Core Data vs. SwiftData, cache-thrash, calc-service concurrency, hand-rolled backup mirrors + vestigial Journal future-log fields.

## In progress

- _(none — `bt-0004` shipped 2026-05-13; see Recent build for the ship summary and bt-0004's Decision log for the full design-pass + scope-pivot story.)_

### Queued (backlog)

- _(none)_

## Next (1–3 items)

1. **Set up `bt-0003`** — Phase 2 model restructure with expanded scope: (a) type the `details` JSON blob; (b) collapse 3-way completion state → one enum; (c) drop vestigial `JournalEntry` fields; (d) **lift legacy-optional fields including `HabitEntry.date: Date? → Date`** as part of the SwiftData `VersionedSchema` migration; (e) **rewrite the deferred hot-path predicate work from `bt-0004`** (three `HabitStore` reads + two widget per-habit sites) — indexes already in place, so the predicate rewrite is ~50 lines once `date` is non-optional. Blocked on the #9 Journal-intent question.
2. **Device-test 5: cross-device CloudKit sync** — install the new build on a second device (iPad or another phone), wait a few minutes, verify changes flow. Watch-item (b) on bt-0002. Low-risk (config + container ID unchanged from Core Data), but the only real verification.
3. (Independent, anytime) #5 — repo-layout cleanup: finish the folder refactor, delete `WidgetEnums.txt` / committed `.DS_Store`s, archive the old `Documentation/` files.

## Open questions / blockers

- ~~Data foundation: stay on custom Core Data or migrate to SwiftData?~~ — **resolved 2026-05-12: migrate to SwiftData, two-phase** (`bt-0001`).
- What is the Journal "future log / migration" feature meant to do? Vestigial model fields remain (`JournalEntry.isFutureEntry`, `isSpecialEntry`, `hasMigrated`, `targetMonth`, `scheduledDate`, `specialEntryType`, `taskStatus`) but no live UI — Dustin to clarify intent (flag #9). **Blocks `bt-0003` Phase 2** — and now also blocks `bt-0004`'s deferred predicate rewrite (which `bt-0003` will pick up via the legacy-optional lift).

## Recent build (last 3)

_(Newest on top. When a 4th lands, oldest migrates to `ARCHITECTURE.md` → Build Log.)_

- `bt-0004` (shipped 2026-05-13) — **SwiftData data-layer perf pass — indexes-only ship; predicate rewrite deferred to `bt-0003`.** Original four-decision plan: (1) hot-path predicate rewrite, (2) date indexes, (3) cold paths untouched, (4) no `ModelActor`. Build phase surfaced that SwiftData's `#Predicate` on this iOS version rejects every shape of optional-`Date` comparison tried (force-unwrap, inline nil-coalesce, captured-local sentinel) — `Date?` would need to become `Date`, which requires a SwiftData `VersionedSchema` migration against the live CloudKit-synced store. That belongs in `bt-0003`'s model-restructure surface, not as a one-off scope expansion here. Net shipped: two `#Index` lines in `Data/Models.swift` (`HabitEntry.date` + `JournalEntry.date`) — re-creates the `byDateIndex` fetch index the original `.xcdatamodeld` had, making any future date-filtered query cheap (including `bt-0003`'s eventual predicate rewrite). Reverted predicate-rewrite attempts in `HabitDataRepository.swift` and `BulletTrackerWidgetsBundle.swift` back to pre-bt-0004 state (kept in `scope_files` as authorization record). Smoke build clean; device-validation on next app-open (schema change is index-add only, no new entities — Apple docs say lightweight `CREATE INDEX` on first launch). Full Decision log in `bt-0004` including the design pass, the Decision-2-was-wrong correction caught mid-build, and the scope-pivot reasoning.
- `bt-0002` (shipped 2026-05-13, merge `ba1edde`) — **SwiftData migration Phase 1 — engine swap, model shape unchanged.** Replaced the hand-rolled Core Data stack (`NSPersistentCloudKitContainer` + `CoreDataManager` + `HabitDataRepository` cache + `@unchecked Sendable` calc service + the `NSManagedObjectContextDidSave` merge listener) with `@Model` types behind one `ModelContainer` (`DataStore.shared`) sharing the existing App-Group SQLite store in place; CloudKit sync continues via `cloudKitDatabase: .automatic`. Six waves on the `swiftdata-migration` branch: baseline `@Model` types → DataStore wiring → Habits surface (flags #4 + #8 folded) → Notes/Settings/Backup/Journal-export → DayJournalView → widget extension → delete the stack. **Net: +1387 / −2070 = 683 fewer lines** across 35 files for the same functionality. Device-tested 1-4 of 6 (cross-device CloudKit + backup round-trip deferred; both low-risk). Full Decision log in `bt-0002`.
- `bt-0001` (shipped 2026-05-12) — **decided the data foundation: migrate to SwiftData, two-phase.** Was the decision bead; design pass run this session. Build work → `bt-0002` (P1) + a future `bt-0003` (P2). Full Why + Decision log in the bead file.
