//
//  HabitDashboardViewModel.swift
//  Bullet Tracker
//
//  ViewModel for habit dashboard analytics.
//
//  SwiftData migration (bt-0002): habits now arrive from `@Query` in the view;
//  entries come from the relationship via `HabitStore`. The old background
//  Core-Data context dance is gone — for a personal-scale dataset the aggregation
//  runs on the main actor each time the Dashboard tab appears. If it ever janks,
//  add `#Index<HabitEntry>([\.date])` (see bt-0002 watch-items) or move to a
//  `ModelActor`.
//

import SwiftUI

// MARK: - Time Period Enum

enum DashboardTimePeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    case year = "Year"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }

    func startDate(from endDate: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -(days - 1), to: endDate) ?? endDate
    }
}

// MARK: - Habit Stat Data Model

struct HabitStatData: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let color: String
    let completionRate: Int
    let completedCount: Int
    let totalDays: Int
    let currentStreak: Int
}

// MARK: - Dashboard View Model

@MainActor
@Observable
class HabitDashboardViewModel {

    var selectedPeriod: DashboardTimePeriod = .month
    var habitStats: [HabitStatData] = []
    var overallCompletionRate: Int = 0
    var bestStreak: Int = 0
    var currentStreak: Int = 0

    private let calendar = Calendar.current
    private let calculationService = HabitCalculationService.shared

    func loadData(habits: [Habit]) {
        guard !habits.isEmpty else {
            habitStats = []
            overallCompletionRate = 0
            bestStreak = 0
            currentStreak = 0
            return
        }

        let endDate = Date()
        let periodStart = calendar.startOfDay(for: selectedPeriod.startDate(from: endDate))

        // Expand the fetch window to cover the 365-day streak lookback.
        let today = calendar.startOfDay(for: Date())
        let streakStart = calendar.date(byAdding: .day, value: -365, to: today) ?? periodStart
        let fetchStart = min(streakStart, periodStart)

        let allEntries = HabitStore.allEntriesByDay(for: habits, from: fetchStart, to: endDate)

        let batch = calculationService.calculateBatchStats(
            for: habits, allEntries: allEntries, from: periodStart, to: endDate
        )

        habitStats = batch.habitStats
            .map { stat in
                HabitStatData(
                    id: stat.habitId,
                    name: stat.name,
                    icon: stat.icon,
                    color: stat.color,
                    completionRate: stat.completionRate,
                    completedCount: stat.completedCount,
                    totalDays: stat.expectedDays,
                    currentStreak: stat.currentStreak
                )
            }
            .sorted { $0.completionRate > $1.completionRate }

        overallCompletionRate = batch.totalExpected > 0
            ? Int((Double(batch.totalCompleted) / Double(batch.totalExpected)) * 100)
            : 0
        bestStreak = batch.maxStreak
        currentStreak = calculationService.calculateOverallCurrentStreak(for: habits, using: allEntries)
    }
}
