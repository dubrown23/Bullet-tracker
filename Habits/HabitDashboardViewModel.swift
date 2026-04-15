//
//  HabitDashboardViewModel.swift
//  Bullet Tracker
//
//  ViewModel for habit dashboard analytics
//

import SwiftUI
import CoreData

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
    var habits: [Habit] = []
    var habitStats: [HabitStatData] = []
    var overallCompletionRate: Int = 0
    var bestStreak: Int = 0
    var currentStreak: Int = 0
    var heatmapDates: [Date] = []
    var dailyCompletionRates: [Date: Double] = [:]
    var isLoading: Bool = false

    private let calendar = Calendar.current
    private let calculationService = HabitCalculationService.shared

    func loadData() {
        loadHabits()
        calculateStatsInBackground()
    }

    private func loadHabits() {
        let context = CoreDataManager.shared.container.viewContext
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]

        do {
            habits = try context.fetch(request)
        } catch {
            habits = []
        }
    }

    private func calculateStatsInBackground() {
        guard !habits.isEmpty else {
            habitStats = []
            overallCompletionRate = 0
            bestStreak = 0
            currentStreak = 0
            return
        }

        isLoading = true

        // Capture values for background work
        let habitObjectIDs = habits.map { $0.objectID }
        let period = selectedPeriod

        Task.detached {
            let bgContext = CoreDataManager.shared.container.newBackgroundContext()
            let service = HabitCalculationService.shared

            // All results computed on background
            let results: (stats: [HabitStatData], overallRate: Int, best: Int, current: Int, dates: [Date], rates: [Date: Double]) = await bgContext.perform {
                // Re-fetch habits on background context
                let bgHabits = habitObjectIDs.compactMap { try? bgContext.existingObject(with: $0) as? Habit }
                guard !bgHabits.isEmpty else {
                    return ([], 0, 0, 0, [], [:])
                }

                let endDate = Date()
                let startDate = period.startDate(from: endDate)
                let calendar = Calendar.current

                // Batch stats on background
                let result = service.calculateBatchStats(
                    for: bgHabits,
                    from: startDate,
                    to: endDate,
                    using: bgContext
                )

                let stats = result.habitStats.map { stat in
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
                }.sorted { $0.completionRate > $1.completionRate }

                let overallRate = result.totalExpected > 0
                    ? Int((Double(result.totalCompleted) / Double(result.totalExpected)) * 100)
                    : 0
                let best = result.maxStreak
                let current = service.calculateOverallCurrentStreak(for: bgHabits, using: result.allEntries)

                // Heatmap on background
                let heatmapEnd = calendar.startOfDay(for: Date())
                let heatmapStart = period.startDate(from: heatmapEnd)

                var dates: [Date] = []
                var currentDate = heatmapStart
                while currentDate <= heatmapEnd {
                    dates.append(currentDate)
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                    currentDate = nextDate
                }

                let rates = service.buildHeatmapData(
                    for: bgHabits,
                    from: heatmapStart,
                    to: heatmapEnd,
                    using: bgContext
                )

                return (stats, overallRate, best, current, dates, rates)
            }

            // Update UI on main thread
            await MainActor.run {
                self.habitStats = results.stats
                self.overallCompletionRate = results.overallRate
                self.bestStreak = results.best
                self.currentStreak = results.current
                self.heatmapDates = results.dates
                self.dailyCompletionRates = results.rates
                self.isLoading = false
            }
        }
    }
}
