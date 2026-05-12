# Project Status

**Last updated:** 2026-05-12 (project initialized via /init-project)

Fast-changing state. For the "why" behind any decision, see `ARCHITECTURE.md`.

---

## Live

- Bullet Tracker iOS app (SwiftUI, Core Data + CloudKit, App Group widget). Working app; ~v1.5-era feature set, mid-cleanup.
- 2026-05-12: adopted the bead / three-doc / skill system; ran a fresh-eyes architecture read pass — see `ARCHITECTURE.md` and `bt-0001`. Patchwork flags identified (#1–#9 in session notes): three overlapping data layers, `details` JSON blob, completion state modeled 3 ways, name-keyword workout detection, half-refactored repo layout, custom Core Data vs. SwiftData, cache-thrash, calc-service concurrency, hand-rolled backup mirrors + vestigial Journal future-log fields.

## In progress

_(Beads currently flipped to `in_progress`. None yet.)_

### Queued (backlog)

- `bt-0001` — decide the data foundation (custom Core Data vs. SwiftData rewrite). Queued; Plan TBD until design pass.

## Next (1–3 items)

1. Design pass on `bt-0001` — evaluate the SwiftData migration (what it buys, migration cost, risk to existing synced data), then Dustin decides.
2. (Independent of `bt-0001`, anytime) #4 — kill name-keyword "is this a workout" detection (use `detailType`).
3. (Independent, anytime) #5 — repo-layout cleanup: finish the folder refactor, delete `WidgetEnums.txt` / committed `.DS_Store`s, archive the old `Documentation/` files.

## Open questions / blockers

- Data foundation: stay on custom Core Data or migrate to SwiftData? — `bt-0001`.
- What is the Journal "future log / migration" feature meant to do? Vestigial model fields remain (`JournalEntry.isFutureEntry`, `isSpecialEntry`, `hasMigrated`, `targetMonth`, `scheduledDate`, `specialEntryType`, `taskStatus`) but no live UI — Dustin to clarify intent (flag #9).

## Recent build (last 3)

_(Newest on top. When a 4th lands, oldest migrates to `ARCHITECTURE.md` → Build Log. Empty at init.)_
