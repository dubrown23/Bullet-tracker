# CLAUDE.md — bullet-tracker

This file auto-loads at the start of every session in this project. Equivalent to Project Instructions. Keep it current.

---

## Project

Bullet Tracker is a personal iOS habit-tracking app (SwiftUI). The intent: a **fast, simple tracker** — quick to open, quick to log (tap), easy to glance at the patterns. Not built for other users. See `ARCHITECTURE.md` → Vision.

Four tabs:
- **Today** — daily habit checklist; tap to complete, day navigation, mini 7-day streak dots
- **Dashboard** — completion-rate analytics, streaks, contribution heatmap (week / month / quarter / year)
- **Journal** — view any past day's habit completions + captured details + free-text notes; PDF export of a date range
- **Settings** — JSON backup/restore, help

Habit styles: **simple** (done / not), **multi-state** (success / partial / failure), **avoidance** (negative habit — checking it means you slipped). Habits can capture structured details (workout types & duration / intensity, reading log, mood). Storage is **Core Data + CloudKit sync**; an **App Group** lets a home-screen **widget** (small / medium / large, tappable habit circles via AppIntents) read the same store.

_History note:_ built incrementally (largely AI-assisted), rewritten several times — started as a different app. An earlier "full digital bullet journal" layer (Collections, Future Log, monthly/daily logs, @mention scheduling, task migration) was scaled back, leaving vestigial model fields. Data foundation (custom Core Data vs. a SwiftData rewrite) under review — see `bt-0001`.

---

## Session rituals

Three-doc discipline:

| File | Purpose |
|------|---------|
| `CLAUDE.md` (this file) | How we work together. Stable. Project conventions, rituals, style. |
| `STATUS.md` | What's true right now. Fast-changing. Live, In progress, Next 1–3, Open questions, Recent build. |
| `ARCHITECTURE.md` | The project: vision, decisions, build history. Append-mostly. |

Open every session with `/start`, close with `/wrap`. Never start work on a bead with empty `scope_files`.

---

## Bead prefix

This project uses `bt-NNNN` (configured in `.beads/config.yaml`).
