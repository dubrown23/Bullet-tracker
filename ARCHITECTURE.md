# bullet-tracker — Architecture & Build Reference

## Vision

A quick way to enter data and see it visually — simple, fast, a "quick hit": pop in, tap to log, glance at the patterns. Built for long-term personal tracking, not for other users. Kept deliberately minimal.

Long-term, the plan is to merge this with **Dustin's Health** (a separate voice-activation project for tracking basic stuff) — but that's a deferred project. The near-term goal is to get *this* app dialed in and genuinely working well before attempting anything that big.

## Origin

Not pre-planned — started building it, then rewrote it several times; it began as a completely different app, and it evolves as needs change. As of mid-2026 the priority is getting the *foundation* right — the bead / three-doc / skill system, a clean architecture, the patchwork cleaned up — because earlier attempts haven't stuck. Adopted the bead system 2026-05-12.

## Founding decisions

_(Numbered list. Each entry: decision + reasoning. Append-mostly.)_

1. **Migrate the data layer from Core Data to SwiftData** (decided 2026-05-12 — `bt-0001`). The whole persistence layer was hand-rolled Core Data plumbing (`CoreDataManager` / `HabitDataRepository` cache / `HabitCalculationService` with an `@unchecked Sendable` over a stored context). SwiftData is the framework Apple is actively developing for exactly this shape (iOS-only, single-user, CloudKit-synced); moving to it structurally eliminates several patchwork issues rather than patching them (the "three doors into the DB", the cache-thrash, the calc thread-safety hack) and replaces hand-maintained plumbing with first-party code that SDK updates carry forward — which matches Dustin's stated goal of leaning on Apple frameworks under the hood. Two phases: **Phase 1** (`bt-0002`) = swap the engine with the data model *shape* unchanged (so the existing CloudKit store opens in place); **Phase 2** (later bead) = restructure the model — type the `details` JSON blob, collapse the 3-way completion state to one enum, remove the vestigial `JournalEntry` future-log fields. Approach: one focused push on the `swiftdata-migration` branch (a Core-Data/SwiftData coexistence period was considered and rejected as too fragile for a one-person app), JSON backup as the safety net. Full evaluation + rationale in `bt-0001`'s Decision log; build plan in `bt-0002`.

## Build Log

_(Older Recent build entries migrate here from `STATUS.md` via the 3-entry rolloff. One row per shipped bead: id, ship date, summary, full Why + Decision log.)_

### `bt-0001` (shipped 2026-05-12) — decided the data foundation: migrate to SwiftData, two-phase

**Summary:** decision bead; design pass run this session. Build work → `bt-0002` (Phase 1 — engine swap, model unchanged) + `bt-0003` (Phase 2 — model restructure). Decision-bead deliverable was the direction + a filled Plan, both done.

**Why:**

The entire data layer was hand-rolled Core Data plumbing:
- `CoreDataManager.shared` — `NSPersistentCloudKitContainer`, App Group store, CRUD on Habit/HabitEntry/Collection
- `HabitDataRepository.shared` — `@MainActor @Observable` cache (`habits[]` + `[UUID:[Date:HabitEntry]]`), optimistic UI updates, background-context writes, manual `NSManagedObjectContextDidSave` merge, widget reload
- `HabitCalculationService.shared` — `@unchecked Sendable`, streaks/rates/heatmap, holds its own `viewContext` *and* takes a passed-in context
- Widget extension, `BackupManager`, `JournalPDFGenerator` all touch Core Data directly

iOS-only, single-user, CloudKit-synced — squarely SwiftData's design target. A SwiftData rewrite would delete most of `CoreDataManager`, the manual merge dance, the optimistic-update bookkeeping, the save-notification listener, and the `@unchecked Sendable` hack.

Real migration with real risk: the `.xcdatamodeld` becomes `@Model` types (existing-store migration needs care), the widget gets rewritten against `ModelContainer`, the JSON backup format must stay round-trip-compatible, and CloudKit-via-SwiftData has its own constraints. The model was mid-cleanup (the `JournalEntry` future-log fields, the dual `completed`/`completionState`, the `details` JSON blob) — a migration was the natural moment to fix those, which made it bigger but more worthwhile.

This bead was the **decision**, not the work. Downstream patchwork items deferred until settled: "three doors into the database" → one owner; `details` JSON blob → typed; 3-way completion state → `CompletionStyle` enum; `HabitDataRepository` cache-thrash; `HabitCalculationService` thread-safety.

**Plan locked at decision (two phases):**

- **Phase 1** — swap the engine, model shape unchanged. Convert the 6 entities (`Habit`, `HabitEntry`, `JournalEntry`, `Collection`, `Note`, `Tag`) to SwiftData `@Model` types field-for-field identical to the existing `.xcdatamodeld`, so SwiftData opens the existing App-Group / CloudKit SQLite store with no data restructuring. Delete most of `CoreDataManager` + `HabitDataRepository` cache + the merge listener; stand up `ModelContainer` with `cloudKitDatabase: .automatic`; rewrite widget + `BackupManager` consumers; fold in flag #4 (kill name-keyword workout detection). Highest risk: first launch opening the existing synced store with the new schema. Mitigation: JSON backup fallback. → became `bt-0002`.
- **Phase 2** — clean the model (separate bead, after Phase 1 ships + stabilizes). `details` JSON-string → typed; collapse 3-way completion state to one enum; remove vestigial `JournalEntry` future-log fields (blocked on the #9 Journal-intent question). → became `bt-0003`.
- **Independent of this chain (anytime):** Flag #5 repo-layout cleanup.

**Decision log:**
- 2026-05-12 — created, queued. Surfaced during the 2026-05-12 fresh-eyes architecture review (flag #6 of 9). Holds the data-foundation decision; Plan stays TBD until a design pass. Flags #1/#2/#3/#7/#8 noted as downstream of this decision.
- 2026-05-12 — design pass run; **decided: migrate to SwiftData, two-phase**. Rationale: SwiftData structurally *eliminates* flags #1/#7/#8 rather than patching them; moves the one remaining old-stack layer onto the framework Apple is actively developing (less hand-rolled code to own, SDK updates carry it forward — matches Dustin's "rely on Apple under the hood" goal); migration risk to existing synced data is real but reducible via the two-phase split + the JSON-backup fallback. Downstream flag routing locked: #1/#7/#8 → Phase 1; #2/#3 + Journal-fields half of #9 → Phase 2; #4 → folded into Phase 1; #5 → still independent.
- 2026-05-12 — **shipped** (deliverable = the decided direction + filled Plan, both done). Build work lives in `bt-0002` (Phase 1) + `bt-0003` (Phase 2). This entry is now the permanent decision record.
