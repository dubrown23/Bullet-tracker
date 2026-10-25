//
//  TodayViewModel.swift
//  Bullet Tracker
//
//  ViewModel for the Today daily habit checklist view.
//
//  SwiftData migration (bt-0002): the habit list now comes from `@Query` in
//  `TodayView`, so this no longer owns a data repository or a cache. It keeps the
//  view's own state (which day is selected, which sheets are open) and offers
//  small helpers over a passed-in `[Habit]`.
//

import SwiftUI

@MainActor
@Observable
class TodayViewModel {
    // MARK: - View State

    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var showingAddHabitSheet = false
    var selectedHabit: Habit? = nil

    // MARK: - Dependencies

    private let calculationService = HabitCalculationService.shared
    private let calendar = Calendar.current

    // MARK: - Date Display

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    var dateDisplayString: String {
        if isToday { return "Today" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        return DateFormatters.weekdayMonthDay.string(from: selectedDate)
    }

    var fullDateString: String {
        DateFormatters.fullDate.string(from: selectedDate)
    }

    // MARK: - Habit-Derived Helpers (over a passed-in list)

    /// Habits that should be tracked on the selected date, in display order.
    func trackableHabits(from habits: [Habit]) -> [Habit] {
        habits.filter { HabitFrequencyHelper.shouldTrack($0, on: selectedDate) }
    }

    // MARK: - Day Summary (bt-0014)
    //
    // Positive habits (simple + multi-state) and avoidance habits are different
    // kinds of thing, so the header never folds them into one number.
    // "5 of 8 done · 3 clean"  /  "5 of 8 done · 1 slip"  /  "All 8 done".

    struct DaySummary {
        let positiveDone: Int
        let positiveTotal: Int
        let avoidanceTotal: Int
        let slips: Int

        var clean: Int { avoidanceTotal - slips }
    }

    func summary(from habits: [Habit]) -> DaySummary {
        var positiveDone = 0, positiveTotal = 0, avoidanceTotal = 0, slips = 0

        for habit in trackableHabits(from: habits) {
            let entry = HabitStore.entry(for: habit, on: selectedDate)
            if habit.completionStyle == .avoidance {
                avoidanceTotal += 1
                if HabitWinRule.isLogged(state: entry?.effectiveCompletionState) { slips += 1 }
            } else {
                positiveTotal += 1
                if HabitStore.isWin(for: habit, entry: entry, on: selectedDate) { positiveDone += 1 }
            }
        }

        return DaySummary(positiveDone: positiveDone, positiveTotal: positiveTotal,
                          avoidanceTotal: avoidanceTotal, slips: slips)
    }

    func summaryText(from habits: [Habit]) -> String {
        let s = summary(from: habits)
        if s.positiveTotal == 0 && s.avoidanceTotal == 0 { return "No habits scheduled" }

        var parts: [String] = []
        if s.positiveTotal > 0 {
            parts.append(s.positiveDone == s.positiveTotal
                         ? "All \(s.positiveTotal) done"
                         : "\(s.positiveDone) of \(s.positiveTotal) done")
        }
        if s.avoidanceTotal > 0 {
            parts.append(s.slips == 0
                         ? "\(s.clean) clean"
                         : "\(s.slips) slip\(s.slips == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }

    /// True when the header should read as a warning (someone slipped today).
    func hasSlips(from habits: [Habit]) -> Bool {
        summary(from: habits).slips > 0
    }

    func currentStreak(for habit: Habit) -> Int {
        let today = calendar.startOfDay(for: Date())
        guard let yearAgo = calendar.date(byAdding: .day, value: -365, to: today) else { return 0 }
        let entries = HabitStore.entriesByDay(for: habit, from: yearAgo, to: today)
        return calculationService.calculateCurrentStreak(for: habit, using: entries)
    }

    // MARK: - Day Navigation

    func goToPreviousDay() {
        guard let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = newDate
    }

    func goToNextDay() {
        let today = calendar.startOfDay(for: Date())
        guard selectedDate < today,
              let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = newDate
    }

    func goToToday() {
        selectedDate = calendar.startOfDay(for: Date())
    }

    func selectDate(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())
        guard day <= today else { return }
        selectedDate = day
    }
}
