//
//  TodayViewModel.swift
//  Bullet Tracker
//
//  ViewModel for the Today daily habit checklist view
//

import SwiftUI

@MainActor
@Observable
class TodayViewModel {
    // MARK: - Properties

    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var showingAddHabitSheet = false
    var selectedHabit: Habit? = nil

    // MARK: - Dependencies

    let dataRepository = HabitDataRepository.shared
    private let calculationService = HabitCalculationService.shared
    private let calendar = Calendar.current

    // MARK: - Computed Properties

    /// Habits from the shared repository
    var habits: [Habit] { dataRepository.habits }

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    var dateDisplayString: String {
        if isToday {
            return "Today"
        }
        if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        }
        return DateFormatters.weekdayMonthDay.string(from: selectedDate)
    }

    var fullDateString: String {
        DateFormatters.fullDate.string(from: selectedDate)
    }

    /// Habits that should be tracked on the selected date
    var trackableHabits: [Habit] {
        habits.filter { HabitFrequencyHelper.shouldTrack($0, on: selectedDate) }
    }

    var completedCount: Int {
        trackableHabits.filter { habit in
            dataRepository.getCompletionState(for: habit, on: selectedDate).isCompleted
        }.count
    }

    var totalCount: Int {
        trackableHabits.count
    }

    var completionProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var progressMessage: String {
        if totalCount == 0 { return "No habits scheduled" }
        if completedCount == totalCount { return "All done! Great job!" }
        let remaining = totalCount - completedCount
        return "\(remaining) habit\(remaining == 1 ? "" : "s") remaining"
    }

    // MARK: - Public Methods

    func loadHabits() {
        dataRepository.loadHabits()
        Task { await loadEntries() }
    }

    func loadEntries() async {
        guard !habits.isEmpty else { return }
        let dateRange = selectedDate...selectedDate
        await dataRepository.loadEntries(for: habits, dateRange: dateRange)
    }

    func goToPreviousDay() {
        guard let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = newDate
        dataRepository.clearCache()
        Task { await loadEntries() }
    }

    func goToNextDay() {
        let today = calendar.startOfDay(for: Date())
        guard selectedDate < today,
              let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = newDate
        dataRepository.clearCache()
        Task { await loadEntries() }
    }

    func goToToday() {
        selectedDate = calendar.startOfDay(for: Date())
        dataRepository.clearCache()
        Task { await loadEntries() }
    }

    func currentStreak(for habit: Habit) -> Int {
        calculationService.calculateCurrentStreak(for: habit)
    }

    /// Returns completion states for the last 7 days
    func last7Days(for habit: Habit) -> [Bool] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return false }
            return dataRepository.getCompletionState(for: habit, on: date).isCompleted
        }
    }
}
