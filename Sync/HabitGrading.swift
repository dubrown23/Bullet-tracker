//
//  HabitGrading.swift
//  Bullet Tracker
//
//  bt-0017 / bt-0018. The app's grading rules for habits fed by outside
//  facts. Pure functions over numbers → `CompletionState`, no SwiftData, so
//  they are unit-testable and shared verbatim by the widget if it ever needs
//  them.
//
//  Diet (decided 2026-10-26, shared design note Part A; calorie floor
//  dropped from the grade 2026-10-30 — under the floor is not a miss):
//    🟢 Done    — protein ≥ floor AND calories tracked and ≤ ceiling
//    🟡 Partial — one of the two
//    🔴 Tried   — neither, or nothing tracked that day (missing calories
//                 are a miss, not "under the ceiling")
//
//  Workout:
//    🟢 Done    — workout minutes ≥ target (from dh, Step 3)
//    🟠 Active day — no workout, but steps ≥ target (Apple Watch steps;
//                 its own state since bt-0029, neutral like Rest)
//    🔴 Tried   — neither
//    ⚪ Rest    — never automatic; only when Dustin calls it
//    Minutes unknown (no source yet) → the day can't be marked Tried: steps
//    alone say nothing about whether he trained.
//
//  Targets come from the habit (`Habit.gradingTargets`, bt-0018); the
//  defaults are `GradingTargets.defaults`.
//

import Foundation

// MARK: - Diet

enum DietGrade {
    static func state(proteinGrams: Double?, calories: Double?, targets: GradingTargets = .defaults) -> CompletionState {
        let proteinHit = (proteinGrams ?? 0) >= targets.proteinFloorGrams
        // The floor (`targets.calorieFloor`) is kept as a setting and shown
        // on the Dashboard band, but it no longer grades (2026-10-30).
        let caloriesHit = calories.map { $0 <= targets.calorieCeiling } ?? false

        switch (proteinHit, caloriesHit) {
        case (true, true): return .success
        case (false, false): return .failure
        default: return .partial
        }
    }

    static func state(for facts: DayFacts, targets: GradingTargets = .defaults) -> CompletionState {
        state(proteinGrams: facts.proteinGrams, calories: facts.calories, targets: targets)
    }
}

// MARK: - Workout

enum WorkoutGrade {
    /// `nil` = not enough is known to grade (minutes unknown and steps under
    /// target). Callers treat `nil` as "write nothing".
    static func state(minutes: Double?, steps: Int?, targets: GradingTargets = .defaults) -> CompletionState? {
        if let minutes, minutes >= targets.workoutMinutes { return .success }
        if let steps, Double(steps) >= targets.steps { return .activeDay }
        return minutes == nil ? nil : .failure
    }
}

// MARK: - Today, before the day is over

enum InProgressRule {
    /// The design's "live, but never red until the day ends": on today, a
    /// Tried grade is withheld (no colour); on a past day it stands.
    static func apply(_ grade: CompletionState?, isToday: Bool) -> CompletionState? {
        if isToday && grade == .failure { return nil }
        return grade
    }
}

// MARK: - Ticks

enum TickGrade {
    /// What a plain "done" / "I did it" means for a habit of this style.
    /// Simple → checked. Multi-state → success. Avoidance → the slip
    /// (`.failure`), exactly what tapping the row does.
    static func state(for style: CompletionStyle) -> CompletionState {
        switch style {
        case .simple, .multiState: return .success
        case .avoidance: return .failure
        }
    }
}

// MARK: - Voice grades (bt-0019)

extension VoiceGrade {
    /// The state a spoken grade writes. `auto` has no state: it means
    /// "drop the override" and is handled by `revertToAutomatic`.
    var completionState: CompletionState? {
        switch self {
        case .done: return .success
        case .partial: return .partial
        case .tried: return .failure
        case .rest: return .rest
        case .auto: return nil
        }
    }
}

// MARK: - Wording shared by the row caption and the Developer screen

enum GradeWording {
    static func describe(_ state: CompletionState?) -> String {
        switch state {
        case nil: return "no colour"
        case .notDone?: return "not done"
        case .success?: return "Done"
        case .partial?: return "Partial"
        case .failure?: return "Tried / slipped"
        case .rest?: return "Rest"
        case .activeDay?: return "Active day"
        }
    }

    static func describe(_ source: EntrySource) -> String {
        switch source {
        case .auto: return "Automatic"
        case .hand: return "By hand"
        case .voice: return "By voice"
        }
    }

    /// bt-0021 — the mode word on the Today row and in Log Details.
    static func mode(_ source: EntrySource) -> String {
        switch source {
        case .auto: return "Auto"
        case .hand: return "Set by you"
        case .voice: return "Set by voice"
        }
    }

    /// bt-0021 — the state word beside the mode ("Auto · Done").
    static func stateWord(_ state: CompletionState) -> String {
        switch state {
        case .notDone: return "not marked"
        case .success: return "Done"
        case .partial: return "Partial"
        case .failure: return "Tried"
        case .rest: return "Rest"
        case .activeDay: return "Active day"
        }
    }
}
