# Project Status

**Last updated:** 2026-10-25

Fast-changing state, written as a story for re-entry. Mechanical facts (bead counts, what's shipped vs. queued) live in `.beads/` and `bead-doctor`; the "why" behind decisions and the full record of every shipped bead live in `ARCHITECTURE.md` → Build Log.

---

## Where we are

Bullet Tracker is a working personal habit app on SwiftData + CloudKit, and as of 2026-10-25 it has been brought up to the iPhone Duo and Apple's current (iOS 26/27) design language end to end. Dustin got a Duo on 2026-10-24; over two days and nine beads (`bt-0008` → `bt-0016`) we: raised the deployment target to iOS 26 and removed the last legacy APIs; made the layout size-class aware (two habits per row when unfolded); moved every piece of chrome onto system components (toolbars, `safeAreaBar`, text styles, VoiceOver from zero); redesigned the Today row into a **week grid** (glyph, name, streak, seven tappable squares) after Dustin found the icon-as-checkbox "dated"; fixed a real scoring bug with one **win rule** everywhere (avoidance habits no longer count a slip as "done", "Tried" is a miss); ran a consistency pass so the palette, shape, seven-day squares and chips are one family app-wide; and replaced the Home Screen widget twice, landing on a **tappable tile grid** (medium 8, large 12 + day summary, small ring) that Dustin confirmed on his Duo.

Standing rule for all of this, in Dustin's words: **use Apple's guidelines whenever possible.** No one-offs: fix the pattern, not the instance.

Harness facts worth knowing: Xcode 27 has no Simulator.app, the Duo simulator only shows the folded 466×678 pt panel, so regular-width checks run on the iPad Air sim and the unfolded look is checked on Dustin's device (`DBd`). One device-interaction session at a time. The tab bar on the Duo is a system right-hand rail in both postures; not ours to change.

## Next (1–3)

1. **Page-by-page reassessment, starting with the Dashboard.** Do what we did for Today: job first, then design. The open question for the Dashboard is whether a separate analytics tab still earns its place now that Today shows the week. Then habit detail, Journal, Settings / Backup / forms, Log Details. One page per turn; Dustin wants to see renders before approving.
2. **Lock Screen / StandBy widget families.** Home Screen widget is done (`bt-0016`); accessory families not started.
3. **Known small defect:** iPad landscape with the sidebar shown puts the left column's weekday letters ~10 pt off the squares (`bt-0014`). Cosmetic, regular-width only.

## Open threads

- Cross-device iPad CloudKit check of the Phase-2 schema: watch-item only, flag if anything looks inconsistent when the iPad is next used.
- `'NSKeyedUnarchiveFromData' should not be used…` deprecation warning in the console since `bt-0007`: unrelated to sync, park until Apple removes it or a bead touches that code.
- Accent orange used as a control tint (selected states, progress fill) sits below WCAG text contrast; Apple ships system orange the same way. Brand call for Dustin, deliberately left in `bt-0012`.

## Recent

- **2026-10-25 (long session, `bt-0010` → `bt-0016`).** Design language wave shipped, then a run of design corrections driven by Dustin using the app on the Duo: a design sweep (`bt-0012`, which also surfaced that habits could not be edited or deleted from the UI at all), the week-grid Today row prototyped and promoted (`bt-0013`), the win rule + honest header + pinned weekday letters (`bt-0014`), the five-rule consistency pass with `Utilities/DesignSystem.swift` (`bt-0015`), the widget mirroring the row (`bt-0011`) and, after Dustin judged that "not super usable" with eleven habits, the tile-grid widget (`bt-0016`). Dustin ticked widget-target membership for three shared files in Xcode, the only project-file action of the series. Everything merged to `main`.
- **2026-10-24 (`bt-0008`, `bt-0009`).** Duo arrives. Two audits (resizability, design language) → four-bead plan. Foundation: deployment target 26, `UIScreen.main` gone, three share sheets → `ShareLink`, `Tab` API, dead Notes tab removed, `AppTheme` trimmed; bonus bug fix (new habit hidden until tomorrow). Duo layout: `PairedRows` two-per-row in regular width, adaptive icon grid, Dashboard double-navigation bug found and fixed.
- **2026-05-14 (`bt-0005`, `bt-0006`, `bt-0007`).** Repo hygiene (two piles) and the CloudKit data-integrity cleanup via a Development-environment reset, after a first attempt that relaxed the schema broke sync entirely (lesson in `feedback_ios_real_fix`).

## Where things live

| What | Where |
|------|-------|
| How we work, conventions | `CLAUDE.md` |
| Vision, founding decisions, every shipped bead's Why + Decision log | `ARCHITECTURE.md` |
| Active beads (`bt-NNNN`) | `.beads/active/` (none open right now) |
| Design rules in code | `Utilities/DesignSystem.swift`, `App/AppTheme.swift`, `HabitWinRule` in `Data/Models.swift` |
| Widget | `BulletTrackerWidgets/BulletTrackerWidgetsBundle.swift` |
| Historical architecture audit (closed) | `memory/in_flight/patchwork-flags-review.md` |
| Project memory for Claude | Xcode CodingAssistant auto-memory (`feedback_apple_guidelines_first`, `feedback_one_device_session_at_a_time`) |
