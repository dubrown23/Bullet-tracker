//
//  HabitDashboardViewModel.swift
//  Bullet Tracker
//
//  bt-0023 — what the Dashboard shows, in two halves:
//
//    • One day (the selected day in the strip): the Diet and Workout rows'
//      stored `health` blocks — today from the engine's live copy when the
//      row has none yet. No network from here; the iPad shows what iCloud
//      carried.
//    • Trends ending today: habits won per day with the period before for
//      comparison, one row per habit in Today order, nutrition / training
//      series from the stored rows.
//
//  The rules are pure and live in `DashboardModel.swift`; this class only
//  fetches rows and hands them over. For a personal-scale dataset the
//  aggregation runs on the main actor each time the tab appears.
//

import SwiftUI

@MainActor
@Observable
class HabitDashboardViewModel {

    // MARK: - Inputs

    var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    var period: DashboardPeriod = .week

    // MARK: - One day

    struct DayHalf {
        var diet: Habit?
        var workout: Habit?
        var dietEntry: HabitEntry?
        var workoutEntry: HabitEntry?
        /// The Diet row's meals (today: the live copy when the row has none).
        var dietHealth: HealthSnapshot?
        /// The Workout row's sessions, steps and burn (same today rule).
        var workoutHealth: HealthSnapshot?
        /// First day with meals (the Diet habit's go-live). Days before it
        /// say "Meals start …" instead of empty numbers.
        var mealsStart: Date?

        var dietTargets: GradingTargets { diet?.gradingTargets ?? .defaults }
        var workoutTargets: GradingTargets { workout?.gradingTargets ?? .defaults }
        var meals: [HealthSnapshot.Meal] { dietHealth?.meals ?? [] }
        var sessions: [HealthSnapshot.Session] { workoutHealth?.sessions ?? [] }
    }

    var day = DayHalf()

    // MARK: - Trends

    struct HabitRow: Identifiable {
        let id: UUID
        let habit: Habit
        let name: String
        let icon: String
        let color: String
        /// bt-0024 — avoidance: `count` is slip days, read "1 of 7 slipped".
        let isSlipRate: Bool
        let count: Int
        let scored: Int
        let trend: DashboardTrends.Trend
        /// 0 for an avoidance habit (no streaks, bt-0024).
        let streak: Int
        let squares: [Square]
    }

    /// One day in a habit row's mini strip. `nil` colour = nothing that day.
    struct Square: Identifiable {
        let day: Date
        let color: Color?
        var id: Date { day }
    }

    var dayWins: [DashboardTrends.DayWins] = []
    var previousAverage: Double?
    var habitRows: [HabitRow] = []
    var nutritionSeries: [DashboardTrends.Series] = []
    var trainingSeries: [DashboardTrends.Series] = []

    var currentAverage: Double? { DashboardTrends.averageWins(dayWins) }
    var scheduledCeiling: Int { DashboardTrends.scheduledCeiling(dayWins) }
    var averageTrend: DashboardTrends.Trend { DashboardTrends.trend(current: currentAverage, previous: previousAverage) }

    private let calendar = Calendar.current
    private let service = HabitCalculationService.shared

    // MARK: - Load

    func loadData(habits: [Habit], engine: HabitSyncEngine) {
        loadDay(habits: habits, engine: engine)
        loadTrends(habits: habits)
    }

    private func loadDay(habits: [Habit], engine: HabitSyncEngine) {
        var half = DayHalf()
        let dayStart = calendar.startOfDay(for: selectedDate)
        let isToday = calendar.isDateInToday(dayStart)
        half.diet = habits.first { $0.gradingKind == .diet }
        half.workout = habits.first { $0.gradingKind == .workout }
        half.mealsStart = half.diet?.gradingSince.map { calendar.startOfDay(for: $0) }
        if let diet = half.diet {
            half.dietEntry = HabitStore.entry(for: diet, on: dayStart)
            half.dietHealth = half.dietEntry?.health ?? (isToday ? engine.liveSnapshot(for: diet) : nil)
        }
        if let workout = half.workout {
            half.workoutEntry = HabitStore.entry(for: workout, on: dayStart)
            half.workoutHealth = half.workoutEntry?.health ?? (isToday ? engine.liveSnapshot(for: workout) : nil)
        }
        day = half
    }

    private func loadTrends(habits: [Habit]) {
        guard !habits.isEmpty else {
            dayWins = []
            previousAverage = nil
            habitRows = []
            nutritionSeries = []
            trainingSeries = []
            return
        }
        let today = calendar.startOfDay(for: Date())
        let days = period.days(ending: today, calendar: calendar)
        guard let periodStart = days.first,
              let previousEnd = calendar.date(byAdding: .day, value: -1, to: periodStart) else { return }
        let previousDays = period.days(ending: previousEnd, calendar: calendar)
        let previousStart = previousDays.first ?? periodStart

        // One fetch covering both periods and the streak lookback.
        let streakStart = calendar.date(byAdding: .day, value: -365, to: today) ?? previousStart
        let fetchStart = min(streakStart, previousStart)
        let entries = HabitStore.allEntriesByDay(for: habits, from: fetchStart, to: today)

        dayWins = DashboardTrends.dayWins(habits: habits, entries: entries, days: days, calendar: calendar)
        previousAverage = DashboardTrends.averageWins(
            DashboardTrends.dayWins(habits: habits, entries: entries, days: previousDays, calendar: calendar))

        habitRows = habits.sorted { ($0.order, $0.name ?? "") < ($1.order, $1.name ?? "") }.compactMap { habit in
            guard let id = habit.id else { return nil }
            let habitEntries = entries[id] ?? [:]
            let cleanStart = HistoryMigration.cleanStart(for: habit, calendar: calendar)
            let current = service.calculateCompletionRate(for: habit, using: habitEntries,
                                                          from: max(periodStart, cleanStart), to: today)
            let previous = service.calculateCompletionRate(for: habit, using: habitEntries,
                                                           from: max(previousStart, cleanStart), to: previousEnd)
            let isSlipRate = HabitWinRule.isSlipScored(style: habit.completionStyle)
            // Rates, not counts, so a shorter clean-start window compares fairly.
            let trend = DashboardTrends.trend(current: current.expected > 0 ? current.rate : nil,
                                              previous: previous.expected > 0 ? previous.rate : nil)
            return HabitRow(
                id: id, habit: habit,
                name: habit.name ?? "Unnamed", icon: habit.icon ?? "circle", color: habit.color ?? AppTheme.accentHex,
                isSlipRate: isSlipRate, count: current.completed, scored: current.expected,
                trend: trend,
                streak: service.calculateCurrentStreak(for: habit, using: habitEntries, allowingOpenToday: true, floor: cleanStart),
                squares: days.map { Square(day: $0, color: Self.squareColor(habit: habit, entry: habitEntries[$0])) }
            )
        }

        // Nutrition from the Diet rows, training from the Workout rows.
        nutritionSeries = []
        trainingSeries = []
        if let diet = habits.first(where: { $0.gradingKind == .diet }), let id = diet.id {
            let series = DashboardTrends.nutritionSeries(dietRows: entries[id] ?? [:], days: days,
                                                         targets: diet.gradingTargets, calendar: calendar)
            nutritionSeries = [series.protein, series.calories].filter(\.hasData)
        }
        if let workout = habits.first(where: { $0.gradingKind == .workout }), let id = workout.id {
            let series = DashboardTrends.trainingSeries(workoutRows: entries[id] ?? [:], days: days,
                                                        targets: workout.gradingTargets, calendar: calendar)
            trainingSeries = [series.minutes, series.steps, series.burned].filter(\.hasData)
        }
    }

    /// The Today grid's colours: a positive habit's state colour; an
    /// avoidance habit shows only its slips (bt-0024), in the failed red.
    static func squareColor(habit: Habit, entry: HabitEntry?) -> Color? {
        let state = entry?.effectiveCompletionState
        if HabitWinRule.isSlipScored(style: habit.completionStyle) {
            return HabitWinRule.isSlip(style: habit.completionStyle, state: state) ? AppTheme.failed : nil
        }
        let completion = HabitStore.completionState(for: habit, entry: entry)
        return completion.isCompleted ? completion.stateColor : nil
    }
}
