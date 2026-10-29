# CLAUDE.md — bullet-tracker

This file auto-loads at the start of every session in this project. Equivalent to Project Instructions. Keep it current.

---

## Project

Bullet Tracker is a personal iOS habit-tracking app (SwiftUI). The intent: a **fast, simple tracker** — quick to open, quick to log (tap), easy to glance at the patterns. Not built for other users. See `ARCHITECTURE.md` → Vision.

Four tabs:
- **Today** — a Reminders-style checklist (`bt-0026`): one round control on the left is the only way to mark the selected day, then the habit glyph + name, six display-only dots for the days before, a flame streak; graded rows carry an Auto / Set by you / Set by voice line; tapping the row opens Log Details; avoidance habits sit in their own **Avoiding** section whose trailer counts slips only; large title + "5 of 8 done" subtitle; arrows move the selected day
- **Dashboard** — completion-rate analytics, streaks, contribution heatmap (week / month / quarter / year)
- **Journal** — any past day's completions (Completed / Tried / Slipped) + captured details + free-text notes; same 7-square date strip as Today; PDF export of a date range
- **Settings** — JSON backup/restore, help

Habit styles: **simple** (done / not), **multi-state** (success / partial / failure), **avoidance** (negative habit — checking it means you slipped). One **win rule** (`HabitWinRule`) scores everything: simple = checked, multi-state = success or partial ("Tried" is a miss), avoidance = no slip. Habits can capture structured details (workout types & duration / intensity, reading log, mood). Storage is **SwiftData + CloudKit sync** (both migration phases shipped 2026-05-13, `bt-0002` / `bt-0003`). An **App Group** lets a home-screen **widget** read the same store — a tappable tile grid (medium 8 / large 12 tiles, small ring) logging today via AppIntents (`bt-0016`). Design rules live in `Utilities/DesignSystem.swift` + `App/AppTheme.swift`: one palette, 22% continuous corners, `DaySquare` / `HabitIconTile` shared by the app and the widget, `DayMark` / `DayControl` / `DayDot` for a day's state in palette colours only (`bt-0026`, the style the Journal and Dashboard adopt next); iOS 26 deployment target, Apple's HIG whenever possible. A **`Sync/` layer** (`bt-0017`, 2026-10-26) is the start of the merge with Dustin's Health: an outside source reports day facts + voice actions, the app grades them with its own rules and writes through the tap path; debug builds get a Settings → Developer screen that drives it with a fake source. **Step 2** (`bt-0018`, 2026-10-27) added the grading rules the sync needs: a neutral **Rest** state (Workout only, never by a plain tap), **"Graded by" + targets** on the habit with a stamped go-live day (history before it is never re-graded), **in-progress today** (blank until a target is hit, red only after midnight), and a **source** (auto / hand / voice) + edit time on every entry so hand grades win until "Back to Automatic"; **only the iPhone writes automatic grades**. **Step 3** (`bt-0019`, live 2026-10-27) is the real sync: `Sync/DustinHealthSource.swift` talks to dh's `api/bullet.js` with a key the iPhone keeps in its Keychain (Settings → Dustin's Health); every run sends habits, targets and today's taps, pulls changed days, facts and the voice inbox, applies voice actions through the tap path (a voice note adds details only), confirms back, grades. The real Diet and Workout are graded from 2026-10-27 forward. **The iPad never calls dh.** **`bt-0021`** (2026-10-27) made the two graded rows legible: the Today caption says **Auto / Set by you / Set by voice** with a Back to Auto button on the row, and Log Details shows dh's meals (per-meal calories and protein) and workout sessions from a `health` key kept beside, never inside, the notes. **`bt-0020`** (2026-10-28) made hand taps reach dh by themselves: one hook at the end of the three `HabitStore` writes arms a 3 s timer every tap restarts (a burst is one send, the same full run as pull-down), leaving the app with a tap waiting sends at once inside a background-task window taken at the tap, and two on-disk dates (`tapWaitingSince` / `lastSentAt`, with the widget's stamp) make the next open sync past the 120 s throttle; iPhone + key only, and the Developer screen's Last run line says why each run happened. **`bt-0022`** (2026-10-28) laid the Dashboard's data (backup keeps the `health` block, steps per day, carbs / fat targets, a one-time history rewrite: clean start 2026-10-27 for every habit except Poison, Workout rebuilt from dh's sessions back to Aug 1); **`bt-0024`** (2026-10-28) made an avoidance habit never a win, never a streak, scored by a **slip rate**; **`bt-0023`** (shipped 2026-10-29) is the **Dashboard that replaces the dh website**: one day on top (shared date strip, **Eaten vs Burned** — burned is Apple Health's active + resting total read by Bullet, never the sessions added up — band bar, three `Gauge` rings, driver line, meals, training with a never-silent warning when sessions exceed Health's active energy) over Week / Month trends (Swift Charts), with pure rules in `Habits/DashboardModel.swift`; a one-time **Refresh Workout Calories** Settings row rewrote the stored sessions Aug 1 → today. **`bt-0026`** (2026-10-29) remade the Today row as a checklist: the round control is the one way to mark, the six dots are history you look at, the row opens Log Details, and Avoiding is its own section.

_History note:_ built incrementally (largely AI-assisted), rewritten several times — started as a different app. An earlier "full digital bullet journal" layer (Collections, Future Log, monthly/daily logs, @mention scheduling, task migration) was scaled back, leaving vestigial model fields — **dropped in `bt-0003` Wave 1 (shipped on the `swiftdata-phase2` branch 2026-05-13)** along with the dormant `JournalEntry` / `Collection` / `Tag` `@Model` types. The data-foundation decision (custom Core Data vs. SwiftData rewrite) is settled — see `bt-0001` → migrate to SwiftData, two-phase (P1 = engine swap, model unchanged; P2 = model cleanup + drop dormant machinery).

---

## Session rituals

Three-doc discipline:

| File | Purpose |
|------|---------|
| `CLAUDE.md` (this file) | How we work together. Stable. Project conventions, rituals, style. |
| `STATUS.md` | What's true right now. Fast-changing. Where we are, Next 1–3, Open threads, Recent (last ~3 sessions, story not ledger), Where things live. Shipped beads roll into `ARCHITECTURE.md` at `/wrap`. |
| `ARCHITECTURE.md` | The project: vision, decisions, build history. Append-mostly. |

Open every session with `/start`, close with `/wrap`. Never start work on a bead with empty `scope_files`.

---

## Bead prefix

This project uses `bt-NNNN` (configured in `.beads/config.yaml`).
