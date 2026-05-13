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

    func completedCount(from habits: [Habit]) -> Int {
        trackableHabits(from: habits).filter {
            HabitStore.completionState(for: $0, on: selectedDate).isCompleted
        }.count
    }

    func totalCount(from habits: [Habit]) -> Int {
        trackableHabits(from: habits).count
    }

    func completionProgress(from habits: [Habit]) -> Double {
        let total = totalCount(from: habits)
        guard total > 0 else { return 0 }
        return Double(completedCount(from: habits)) / Double(total)
    }

    func progressMessage(from habits: [Habit]) -> String {
        let total = totalCount(from: habits)
        if total == 0 { return "No habits scheduled" }
        let completed = completedCount(from: habits)
        if completed == total { return "All done! Great job!" }
        let remaining = total - completed
        return "\(remaining) habit\(remaining == 1 ? "" : "s") remaining"
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
