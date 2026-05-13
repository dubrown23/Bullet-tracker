# Project Status

**Last updated:** 2026-05-13 (`bt-0002` **SHIPPED** — merge `ba1edde` to `main`; SwiftData migration Phase 1 complete; +1387 / −2070 net = 683 fewer lines; device-tested 1-4 of 6 (cross-device CloudKit + backup round-trip deferred, low-risk). Active in_progress beads: none. Next = decide where `bt-0002` deferred-perf (d)+(e) lives — new `bt-0004` vs fold into `bt-0003` — then shape `bt-0003` Phase 2 when the #9 Journal-intent question lands.)

Fast-changing state. For the "why" behind any decision, see `ARCHITECTURE.md`.

---

## Live

- Bullet Tracker iOS app (SwiftUI, Core Data + CloudKit, App Group widget). Working app; ~v1.5-era feature set, mid-cleanup.
- 2026-05-12: adopted the bead / three-doc / skill system; ran a fresh-eyes architecture read pass — see `ARCHITECTURE.md` and `bt-0001`. Patchwork flags identified (#1–#9 in session notes): three overlapping data layers, `details` JSON blob, completion state modeled 3 ways, name-keyword workout detection, half-refactored repo layout, custom Core Data vs. SwiftData, cache-thrash, calc-service concurrency, hand-rolled backup mirrors + vestigial Journal future-log fields.

## In progress

- _(none — `bt-0002` shipped 2026-05-13; see Recent build for the ship summary and bt-0002's Decision log for the full wave-by-wave story.)_

### Queued (backlog)

- _(none — `bt-0003` Phase 2 not yet created; see Next #1.)_

## Next (1–3 items)

1. **Decide where `bt-0002` deferred-perf items (d)+(e) live** — own bead (`bt-0004` "SwiftData data-layer perf pass") OR fold into the future `bt-0003` Phase 2 (already touching the data layer). Architectural call; see bt-0002 ship Decision log entry for the full tradeoff. Once decided, create the bead (queued, Plan = `TBD — design pass needed when picked up.`).
2. **Set up `bt-0003`** — Phase 2 model restructure (`details` JSON blob → typed; collapse 3-way completion state → one enum; drop vestigial `JournalEntry` fields). Blocked on the #9 Journal-intent question — until Dustin clarifies what the future-log feature was meant to do, those fields can't be safely dropped.
3. **Device-test 5: cross-device CloudKit sync** — install the new build on a second device (iPad or another phone), wait a few minutes, verify changes flow. Watch-item (b) on bt-0002. Low-risk (config + container ID unchanged from Core Data), but the only real verification.
4. (Independent, anytime) #5 — repo-layout cleanup: finish the folder refactor, delete `WidgetEnums.txt` / committed `.DS_Store`s, archive the old `Documentation/` files.

## Open questions / blockers

- ~~Data foundation: stay on custom Core Data or migrate to SwiftData?~~ — **resolved 2026-05-12: migrate to SwiftData, two-phase** (`bt-0001`).
- What is the Journal "future log / migration" feature meant to do? Vestigial model fields remain (`JournalEntry.isFutureEntry`, `isSpecialEntry`, `hasMigrated`, `targetMonth`, `scheduledDate`, `specialEntryType`, `taskStatus`) but no live UI — Dustin to clarify intent (flag #9). **Blocks Phase 2** (the future `bt-0003` — those fields get removed there).

## Recent build (last 3)

_(Newest on top. When a 4th lands, oldest migrates to `ARCHITECTURE.md` → Build Log.)_

- `bt-0002` (shipped 2026-05-13, merge `ba1edde`) — **SwiftData migration Phase 1 — engine swap, model shape unchanged.** Replaced the hand-rolled Core Data stack (`NSPersistentCloudKitContainer` + `CoreDataManager` + `HabitDataRepository` cache + `@unchecked Sendable` calc service + the `NSManagedObjectContextDidSave` merge listener) with `@Model` types behind one `ModelContainer` (`DataStore.shared`) sharing the existing App-Group SQLite store in place; CloudKit sync continues via `cloudKitDatabase: .automatic`. Six waves on the `swiftdata-migration` branch: baseline `@Model` types → DataStore wiring → Habits surface (flags #4 + #8 folded) → Notes/Settings/Backup/Journal-export → DayJournalView → widget extension → delete the stack. **Net: +1387 / −2070 = 683 fewer lines** across 35 files for the same functionality. Device-tested 1-4 of 6 (cross-device CloudKit + backup round-trip deferred; both low-risk). Full Decision log in `bt-0002`.
- `bt-0001` (shipped 2026-05-12) — **decided the data foundation: migrate to SwiftData, two-phase.** Was the decision bead; design pass run this session. Build work → `bt-0002` (P1) + a future `bt-0003` (P2). Full Why + Decision log in the bead file.
