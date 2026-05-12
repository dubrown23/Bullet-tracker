# Project Status

**Last updated:** 2026-05-12 (init via /init-project; fresh-eyes review; `bt-0001` decided + shipped — migrate to SwiftData; `bt-0002` Phase 1 activated, strategy "(b) one focused push" on the `swiftdata-migration` branch; baseline committed `37045dc` (`@Model` types + codegen off); Wave 1 done — `DataStore.swift` + slimmed `Bullet_TrackerApp` (uncommitted on the branch); next session = Wave 2)

Fast-changing state. For the "why" behind any decision, see `ARCHITECTURE.md`.

---

## Live

- Bullet Tracker iOS app (SwiftUI, Core Data + CloudKit, App Group widget). Working app; ~v1.5-era feature set, mid-cleanup.
- 2026-05-12: adopted the bead / three-doc / skill system; ran a fresh-eyes architecture read pass — see `ARCHITECTURE.md` and `bt-0001`. Patchwork flags identified (#1–#9 in session notes): three overlapping data layers, `details` JSON blob, completion state modeled 3 ways, name-keyword workout detection, half-refactored repo layout, custom Core Data vs. SwiftData, cache-thrash, calc-service concurrency, hand-rolled backup mirrors + vestigial Journal future-log fields.

## In progress

- `bt-0002` — **SwiftData migration, Phase 1** (engine swap, model shape unchanged). On the `swiftdata-migration` branch. Scope locked (~22 Core-Data-touching `.swift` + the model XML + the project file). **Strategy "(b)": one focused data-layer push** — no Core-Data-coexistence period (the earlier "turn off codegen, gradual migrate" plan was wrong: `@Model` types aren't `NSManagedObject` drop-ins — see bt-0002 Decision log). App stays red until the last wave; JSON backup is the safety net; merge when it compiles + works.
  - **Done:** baseline `37045dc` (`@Model` types in `Models.swift` mirroring the `.xcdatamodeld`; Codegen → Manual/None on all 6 entities; `Models.swift` in both targets). **Wave 1** (uncommitted on the branch): `Data/DataStore.swift` (the `ModelContainer` — App-Group `BulletTracker.sqlite`, `cloudKitDatabase: .automatic`, in-place open of the existing store) + `App/Bullet_TrackerApp.swift` slimmed to `.modelContainer(DataStore.shared)` — both compiled clean.
  - **Next session = Wave 2:** read the unread Habits files first (`TodayView`, `TodayViewModel`, `TodayHabitCardView`, `HabitCompletionDetailView`, `HabitDashboardView`, `HabitDashboardViewModel`, `HabitDetailDashboardView`, `EditHabitView`, `HabitFormView`, `AddHabitView`, `ContentView`, `HabitCalculations`), then rewrite `HabitDataRepository` (keep `getCompletionState`/`HabitCompletionState`, `reorderHabits`, post-write `WidgetCenter.reloadTimelines`; delete the cache machinery + the `NSManagedObjectContextDidSave` listener) → `@Query` in views; convert those view files; fold in flag #4 (kill name-keyword "is this a workout?", use `detailType`). Chunk: Today tab → Dashboard/Detail → Edit/Add. Then Waves 3–5 (calc → Journal/Notes/Settings/Backup → widget) → delete `CoreDataManager*` + `.xcdatamodeld` → build → fix → test → merge.
  - **Dustin TODO before testing:** export a JSON backup from Settings.

### Queued (backlog)

- _(none — `bt-0003` Phase 2 not yet created; see Next #3)_

## Next (1–3 items)

1. `bt-0002` **Wave 2** — read the unread Habits view/VM files, rewrite `HabitDataRepository` → `@Query`, convert the Habits screens, fold in flag #4. Chunk it (Today tab → Dashboard/Detail → Edit/Add). Then Waves 3–5.
2. (Independent, anytime) #5 — repo-layout cleanup: finish the folder refactor, delete `WidgetEnums.txt` / committed `.DS_Store`s, archive the old `Documentation/` files.
3. After Phase 1 ships: create `bt-0003` — Phase 2 model restructure (`details` JSON blob → typed; collapse 3-way completion state → one enum; drop vestigial `JournalEntry` fields). Blocked on `bt-0002` + the #9 Journal-intent question.

## Open questions / blockers

- ~~Data foundation: stay on custom Core Data or migrate to SwiftData?~~ — **resolved 2026-05-12: migrate to SwiftData, two-phase** (`bt-0001`).
- What is the Journal "future log / migration" feature meant to do? Vestigial model fields remain (`JournalEntry.isFutureEntry`, `isSpecialEntry`, `hasMigrated`, `targetMonth`, `scheduledDate`, `specialEntryType`, `taskStatus`) but no live UI — Dustin to clarify intent (flag #9). **Blocks Phase 2** (the future `bt-0003` — those fields get removed there).

## Recent build (last 3)

_(Newest on top. When a 4th lands, oldest migrates to `ARCHITECTURE.md` → Build Log.)_

- `bt-0001` (shipped 2026-05-12) — **decided the data foundation: migrate to SwiftData, two-phase.** Was the decision bead; design pass run this session. Build work → `bt-0002` (P1) + a future `bt-0003` (P2). Full Why + Decision log in the bead file.
