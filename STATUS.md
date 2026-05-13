# Project Status

**Last updated:** 2026-05-12 (init via /init-project; fresh-eyes review; `bt-0001` decided + shipped — migrate to SwiftData; `bt-0002` Phase 1 in progress on the `swiftdata-migration` branch; baseline `37045dc`; **Wave 1 committed `5551c24`**; **Wave 2 done — commits `87990d7`/`c5b76ab`/`194f02e`** (Habits tab off Core Data: `HabitCalculations` pure, `HabitStore` replaces `HabitDataRepository`, `@Query` in the views, flag #4 + flag #8 folded); next session = Wave 3 (Journal/Notes/Settings/Backup))

Fast-changing state. For the "why" behind any decision, see `ARCHITECTURE.md`.

---

## Live

- Bullet Tracker iOS app (SwiftUI, Core Data + CloudKit, App Group widget). Working app; ~v1.5-era feature set, mid-cleanup.
- 2026-05-12: adopted the bead / three-doc / skill system; ran a fresh-eyes architecture read pass — see `ARCHITECTURE.md` and `bt-0001`. Patchwork flags identified (#1–#9 in session notes): three overlapping data layers, `details` JSON blob, completion state modeled 3 ways, name-keyword workout detection, half-refactored repo layout, custom Core Data vs. SwiftData, cache-thrash, calc-service concurrency, hand-rolled backup mirrors + vestigial Journal future-log fields.

## In progress

- `bt-0002` — **SwiftData migration, Phase 1** (engine swap, model shape unchanged). On the `swiftdata-migration` branch. Scope locked (~22 Core-Data-touching `.swift` + the model XML + the project file). **Strategy "(b)": one focused data-layer push** — no Core-Data-coexistence period (the earlier "turn off codegen, gradual migrate" plan was wrong: `@Model` types aren't `NSManagedObject` drop-ins — see bt-0002 Decision log). App stays red until the last wave; JSON backup is the safety net; merge when it compiles + works.
  - **Done so far:** baseline `37045dc` (`@Model` types in `Models.swift` mirroring the `.xcdatamodeld`; Codegen → Manual/None; `Models.swift` in both targets). **Wave 1** (`5551c24`): `Data/DataStore.swift` (`ModelContainer` — App-Group `BulletTracker.sqlite`, `cloudKitDatabase: .automatic`, in-place open) + `App/Bullet_TrackerApp.swift` → `.modelContainer(DataStore.shared)`. **Wave 2** (`87990d7` 2a / `c5b76ab` 2b / `194f02e` 2c): the entire Habits surface off Core Data — `Utilities/HabitCalculations.swift` made pure (no `@unchecked Sendable`/stored context — flag #8 gone); `Habits/HabitDataRepository.swift` rewritten as `enum HabitStore` (read helpers over `habit.entries`, write helpers over a `ModelContext`, `HabitCompletionState` kept, **flag #4 folded** — `isWorkoutHabit == detailType=="workout"` only); `@Query` in `TodayView`/`HabitDashboardView`; all 10 Habits view/VM files converted (`TodayView*`, `TodayHabitCardView`, `HabitCompletionDetailView`, `HabitDashboardView*`, `HabitDetailDashboardView`, `EditHabitView`, `AddHabitView`, `HabitFormView`). Compile-checked by reading only — no Xcode build run yet (branch stays red until the last wave).
  - **Next session = Wave 3:** Journal/Notes/Settings + `BackupManager` — `DayJournalView`, `JournalExportView`, `JournalJSONExporter`, `JournalPDFGenerator` (note: it still calls the deleted `HabitCalculationService.fetchAllEntries` — re-point at `HabitStore`), `NotesView`, `SettingsView`, `BackupManager` (Codable mirror structs + file format unchanged; reads → `FetchDescriptor`, writes → `obj.init()` + `modelContext.insert`), `BackupRestoreViewModel`. Then **Wave 4** = widget extension (rewrite `CompleteHabitIntent` + provider against a `ModelContainer` built in the extension). Then delete `CoreDataManager*` + `.xcdatamodeld` → build → fix → test → merge.
  - **Carried watch-items:** (a) `@Query`'s `[Habit]` array identity is stable when child `HabitEntry`s change (Habit is a class) → Dashboard recomputes on `.onAppear`, not reactively — fine for now. (b) widget cross-process writes — old `NSManagedObjectContextDidSave` merge listener gone; verify SwiftData main-context auto-merge covers it during device testing. (c) `#Preview`s in dashboard views will crash in the canvas (no `.modelContainer`) — cosmetic.
  - **Dustin TODO before testing:** export a JSON backup from Settings.

### Queued (backlog)

- _(none — `bt-0003` Phase 2 not yet created; see Next #3)_

## Next (1–3 items)

1. `bt-0002` **Wave 3** — Journal/Notes/Settings + `BackupManager` off Core Data (see In progress for the file list; `JournalPDFGenerator` needs re-pointing off the deleted `HabitCalculationService.fetchAllEntries`). Then Wave 4 (widget), then delete `CoreDataManager*`/`.xcdatamodeld` → build → fix → test → merge.
2. (Independent, anytime) #5 — repo-layout cleanup: finish the folder refactor, delete `WidgetEnums.txt` / committed `.DS_Store`s, archive the old `Documentation/` files.
3. After Phase 1 ships: create `bt-0003` — Phase 2 model restructure (`details` JSON blob → typed; collapse 3-way completion state → one enum; drop vestigial `JournalEntry` fields). Blocked on `bt-0002` + the #9 Journal-intent question.

## Open questions / blockers

- ~~Data foundation: stay on custom Core Data or migrate to SwiftData?~~ — **resolved 2026-05-12: migrate to SwiftData, two-phase** (`bt-0001`).
- What is the Journal "future log / migration" feature meant to do? Vestigial model fields remain (`JournalEntry.isFutureEntry`, `isSpecialEntry`, `hasMigrated`, `targetMonth`, `scheduledDate`, `specialEntryType`, `taskStatus`) but no live UI — Dustin to clarify intent (flag #9). **Blocks Phase 2** (the future `bt-0003` — those fields get removed there).

## Recent build (last 3)

_(Newest on top. When a 4th lands, oldest migrates to `ARCHITECTURE.md` → Build Log.)_

- `bt-0001` (shipped 2026-05-12) — **decided the data foundation: migrate to SwiftData, two-phase.** Was the decision bead; design pass run this session. Build work → `bt-0002` (P1) + a future `bt-0003` (P2). Full Why + Decision log in the bead file.
