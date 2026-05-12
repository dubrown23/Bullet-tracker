# Project Status

**Last updated:** 2026-05-12 (init via /init-project; fresh-eyes review; `bt-0001` decided + shipped — migrate to SwiftData; `bt-0002` Phase 1 activated; strategy set to "(b) one focused push" on the `swiftdata-migration` branch; `Models.swift` first-pass written)

Fast-changing state. For the "why" behind any decision, see `ARCHITECTURE.md`.

---

## Live

- Bullet Tracker iOS app (SwiftUI, Core Data + CloudKit, App Group widget). Working app; ~v1.5-era feature set, mid-cleanup.
- 2026-05-12: adopted the bead / three-doc / skill system; ran a fresh-eyes architecture read pass — see `ARCHITECTURE.md` and `bt-0001`. Patchwork flags identified (#1–#9 in session notes): three overlapping data layers, `details` JSON blob, completion state modeled 3 ways, name-keyword workout detection, half-refactored repo layout, custom Core Data vs. SwiftData, cache-thrash, calc-service concurrency, hand-rolled backup mirrors + vestigial Journal future-log fields.

## In progress

- `bt-0002` — **SwiftData migration, Phase 1** (engine swap, model shape unchanged). Activated 2026-05-12, scope locked (~22 Core-Data-touching `.swift` + the model XML + the project file). **Strategy = "(b)": one focused data-layer push on the `swiftdata-migration` branch** — no Core-Data-coexistence period (the earlier "turn off codegen, gradual migrate" plan was wrong: `@Model` types aren't `NSManagedObject` drop-ins; coexistence needs a fragile dual-model setup — see bt-0002 Decision log). App won't build for the duration; JSON backup is the safety net; merge when it compiles + works. Branch created. `Data/Models.swift` written (first-pass `@Model` types, currently un-targeted so `main`-state still builds). **Next:** Claude writes the migration code on the branch in commit-stages (DataStore → Habits views → widget → calc → Journal/Notes/Settings/Backup → delete CoreData); Dustin's Xcode work is at the end (codegen toggle, re-target Models.swift, build+fix together, test on device + CloudKit + widget + backup round-trip). Dustin TODO before testing: export a JSON backup from Settings.

### Queued (backlog)

- _(none — `bt-0003` Phase 2 not yet created; see Next #3)_

## Next (1–3 items)

1. `bt-0002` Stage A — get `Data/Models.swift` compiling (Xcode codegen toggle + target membership), then `ModelContainer` setup + app wiring, then the Stage-A verification gate.
2. (Independent, anytime) #5 — repo-layout cleanup: finish the folder refactor, delete `WidgetEnums.txt` / committed `.DS_Store`s, archive the old `Documentation/` files.
3. After Phase 1 ships: create `bt-0003` — Phase 2 model restructure (`details` JSON blob → typed; collapse 3-way completion state → one enum; drop vestigial `JournalEntry` fields). Blocked on `bt-0002` + the #9 Journal-intent question.

## Open questions / blockers

- ~~Data foundation: stay on custom Core Data or migrate to SwiftData?~~ — **resolved 2026-05-12: migrate to SwiftData, two-phase** (`bt-0001`).
- What is the Journal "future log / migration" feature meant to do? Vestigial model fields remain (`JournalEntry.isFutureEntry`, `isSpecialEntry`, `hasMigrated`, `targetMonth`, `scheduledDate`, `specialEntryType`, `taskStatus`) but no live UI — Dustin to clarify intent (flag #9). **Now also blocks `bt-0001` Phase 2** (those fields get removed there).

## Recent build (last 3)

_(Newest on top. When a 4th lands, oldest migrates to `ARCHITECTURE.md` → Build Log.)_

- `bt-0001` (shipped 2026-05-12) — **decided the data foundation: migrate to SwiftData, two-phase.** Was the decision bead; design pass run this session. Build work → `bt-0002` (P1) + a future `bt-0003` (P2). Full Why + Decision log in the bead file.
