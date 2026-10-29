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

    // bt-0026 — the Today list is two sections: the habits you do, then the
    // ones you avoid ("Avoiding"), each in display order. An avoidance row's
    // control means the opposite thing (tap = slipped), so it gets its own
    // section instead of hiding among the others.

    func positiveHabits(from habits: [Habit]) -> [Habit] {
        trackableHabits(from: habits).filter { $0.completionStyle != .avoidance }
    }

    func avoidanceHabits(from habits: [Habit]) -> [Habit] {
        trackableHabits(from: habits).filter { $0.completionStyle == .avoidance }
    }

    // MARK: - Day Summary (bt-0014)
    //
    // The wording lives on `DaySummary` (`Data/Models.swift`), shared with the
    // widget: "5 of 8 done" / "All 8 done" / "5 of 8 done · 1 slip". A clean
    // avoidance day adds nothing (bt-0024).

    func summary(from habits: [Habit]) -> DaySummary {
        var positiveDone = 0, positiveTotal = 0, avoidanceTotal = 0, slips = 0

        for habit in trackableHabits(from: habits) {
            let entry = HabitStore.entry(for: habit, on: selectedDate)
            if habit.completionStyle == .avoidance {
                avoidanceTotal += 1
                if HabitWinRule.isLogged(state: entry?.effectiveCompletionState) { slips += 1 }
            } else if HabitStore.isNeutral(entry: entry) {
                // A Rest day (bt-0018) is neither done nor missed: "4 of 7", not "4 of 8".
                continue
            } else {
                positiveTotal += 1
                if HabitStore.isWin(for: habit, entry: entry, on: selectedDate) { positiveDone += 1 }
            }
        }

        return DaySummary(positiveDone: positiveDone, positiveTotal: positiveTotal,
                          avoidanceTotal: avoidanceTotal, slips: slips)
    }

    /// bt-0026 — the subtitle counts the habits you do; slips are said by the
    /// Avoiding section. Nothing when only avoidance habits are scheduled.
    func summaryText(from habits: [Habit]) -> String {
        let summary = summary(from: habits)
        if summary.positiveTotal == 0 && summary.avoidanceTotal > 0 { return "" }
        return summary.positiveText(emptyText: "No habits scheduled")
    }

    /// bt-0026 — the Avoiding section's trailer: "1 slipped", or nothing.
    func avoidingTrailerText(from habits: [Habit]) -> String? {
        summary(from: habits).slipsText
    }

    /// True when the header should read as a warning (someone slipped today).
    func hasSlips(from habits: [Habit]) -> Bool {
        summary(from: habits).slips > 0
    }

    /// The row's flame. bt-0026 — the same rule as the Dashboard: counted
    /// from yesterday while today is still open, never back past the
    /// habit's clean start, so the two agree at breakfast.
    func currentStreak(for habit: Habit) -> Int {
        let today = calendar.startOfDay(for: Date())
        guard let yearAgo = calendar.date(byAdding: .day, value: -365, to: today) else { return 0 }
        let entries = HabitStore.entriesByDay(for: habit, from: yearAgo, to: today)
        return calculationService.calculateCurrentStreak(
            for: habit, using: entries,
            allowingOpenToday: true, floor: HistoryMigration.cleanStart(for: habit)
        )
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
