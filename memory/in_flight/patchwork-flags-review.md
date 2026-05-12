---
topic: Bullet Tracker fresh-eyes architecture review — 9 patchwork flags
started: 2026-05-12
status: open — #6 beaded as bt-0001; #4/#5 queued in STATUS Next; #9 awaiting Dustin's intent; rest downstream of bt-0001
---

# What this is

2026-05-12 read pass over ~8,800 lines of Swift + the Core Data model, done as a "fresh eyes — app was patchworked together, may be fundamentally better ways" review. Nine flags surfaced. This file holds the full table (plain English + technical + lean + where it landed) so the bt-0001 design pass and the #4/#5 cleanups have the detail in one place. STATUS.md has the one-line versions; bt-0001 has the data-layer ones in detail.

# The 9 flags

| # | Flag | Plain English | Technically | Lean | Disposition |
|---|---|---|---|---|---|
| 1 | Three doors into the database | `CoreDataManager`, `HabitDataRepository`, `HabitCalculationService` each open their own connection + run their own queries; the "repository" stacks on top of the manager rather than replacing it | 3 types, 3 `viewContext` refs, no single owner | Pick one owner; others go through it | Downstream of bt-0001 |
| 2 | Structured details = JSON string blob | workout types/duration/intensity, book/pages, mood all squished into one text field as JSON; every screen hand-parses by string key | `HabitEntry.details: String` holding `JSONSerialization` dicts; `json["types"]` etc. | **Biggest one** — typed `Codable`, child entities, or columns | Downstream of bt-0001 (the JSON-blob fix is first in line if we stay Core Data) |
| 3 | Completion state modeled 3 ways | entry has both old `completed` bool AND newer 0/1/2/3 state code, plus 3–4 bools on the habit saying the same thing; code already calls `completed` vestigial but still writes it | `completed: Bool` + `completionState: Int16` (magic nums) + `useMultipleStates`/`isNegativeHabit`/`trackDetails`/`detailType`; `CompletionStyle` enum is the intended model | Collapse to `CompletionStyle` enum + one state value; drop `completed` | Downstream of bt-0001 |
| 4 | "Is this a workout?" guessed from the name | app decides whether to show workout fields by substring-matching the habit name against workout/exercise/gym/fitness/training/movement | substring match on `habit.name` OR `detailType == "workout"` | `detailType` already exists — kill the name-keyword fallback | **Independent — STATUS Next #2** (small, do anytime) |
| 5 | Repo layout half-refactored | source files sorted into `App/`/`Data/`/`Habits/`/… but the `.xcdatamodeld`, `.entitlements`, `Assets.xcassets` still in the old nested `Bullet Tracker/` folder; stray empty `WidgetEnums.txt`, committed `.DS_Store`s, 90 KB of 2024–25 docs in `Documentation/` + root `BULLET TRACKER COLLABORATION PROTOCOL.md` superseded by the new `CLAUDE.md` | hygiene | Finish the move, delete strays, archive old docs (consider a real `.gitignore` — currently 0 bytes) | **Independent — STATUS Next #3** (low-risk, do anytime) |
| 6 | All hand-rolled Core Data — in the SwiftData era | iOS-only, single-user, CloudKit-synced = SwiftData's sweet spot; migrating would delete most of the manager, the manual context-merge, optimistic-update bookkeeping, the save-notification listener, the `@unchecked Sendable` calc service. But real migration: model rewrite, widget rewrite, backup compat, CloudKit-with-SwiftData constraints | `NSPersistentCloudKitContainer` + manual everything vs `@Model` + `ModelContainer` | **Dustin's call.** Standalone decision, not bundled | **`bt-0001`** (queued; Plan TBD until design pass) |
| 7 | Cache nuked on almost every tap | day navigation calls `clearCache()` then reloads, every time; a custom `.appBecameActive` notification is posted but nothing consumes it | `[UUID:[Date:Entry]]` + single `loadedDateRange` doesn't fit "jump to arbitrary day"; `.appBecameActive` post has no listener | Real but maybe moot if #6 happens | Downstream of bt-0001 |
| 8 | Calc service lies about thread-safety | marked `@unchecked Sendable` while holding a main-thread DB connection AND accepting whatever connection you pass; dashboard passes it a fresh background context | `HabitCalculationService.shared` — stored `viewContext` + `using ctx:` params | Make it stateless pure functions over a passed-in context, or fold into the repo | Downstream of bt-0001 |
| 9 | Backup = hand-maintained twin of every entity | JSON backup has a parallel `Codable` struct hierarchy mirroring the Core Data model, kept in sync by hand; also `JournalEntry` has `isFutureEntry`/`isSpecialEntry`/`hasMigrated`/`targetMonth`/`scheduledDate`/`specialEntryType`/`taskStatus` — leftover from a half-built bullet-journal "future log / migration" feature with no live UI | `BackupData` + 6 mirror structs; vestigial Journal fields | Need Dustin to say what the Journal "future log" was meant to do before this can be shaped | **STATUS Open questions** — awaiting Dustin's intent |

# Context the design pass should carry

- Vision (per ARCHITECTURE.md): fast, simple personal tracker — "quick hit", tap-to-log, glance at patterns. Not multi-user. Long-term (deferred): merge with Dustin's Health (voice-tracking project).
- The app was rewritten several times; the "full digital bullet journal" layer (Collections / Future Log / monthly+daily logs / @mention scheduling / auto task migration) described in the old `Documentation/Bullet Track - Overview.md` (v1.5) was scaled back — only vestigial model fields remain. So old docs ≠ current code; trust the code.
- Old `Documentation/feature list.md` + `Bullet Tracker - Future Optimizations` have future-feature ideas (streaks/insights/templates/etc.) — not in scope now, just noting they exist for the #5 archive.
