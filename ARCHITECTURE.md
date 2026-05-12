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
