//
//  HabitGrading.swift
//  Bullet Tracker
//
//  bt-0017. The app's grading rules for habits fed by outside facts. Pure
//  functions over numbers → `CompletionState`, no SwiftData, so they are
//  unit-testable and shared verbatim by the widget if it ever needs them.
//
//  Diet (decided 2026-10-26, shared design note Part A):
//    🟢 Done    — protein ≥ 180 g AND calories within 1,900–2,200
//    🟡 Partial — one of the two
//    🔴 Tried   — neither, or nothing tracked that day
//
//  Targets are constants in Step 0. Step 2 moves them into the habit's
//  settings (and voice can change them); the function signature stays.
//

import Foundation

// MARK: - Targets

enum DietTargets {
    static let proteinFloorGrams: Double = 180
    /// The floor is Dustin's ("yes keep 1900"): undereating is a miss.
    static let calorieFloor: Double = 1900
    static let calorieCeiling: Double = 2200
}

// MARK: - Diet

enum DietGrade {
    static func state(proteinGrams: Double?, calories: Double?) -> CompletionState {
        let proteinHit = (proteinGrams ?? 0) >= DietTargets.proteinFloorGrams
        let caloriesHit = calories.map {
            (DietTargets.calorieFloor...DietTargets.calorieCeiling).contains($0)
        } ?? false

        switch (proteinHit, caloriesHit) {
        case (true, true): return .success
        case (false, false): return .failure
        default: return .partial
        }
    }

    static func state(for facts: DayFacts) -> CompletionState {
        state(proteinGrams: facts.proteinGrams, calories: facts.calories)
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
