//
//  HabitCalculations.swift
//  Bullet Tracker
//
//  Shared utilities for habit streak and completion calculations.
//
//  SwiftData migration (bt-0002): this used to hold an NSManagedObjectContext and
//  fetch entries itself. Now it's PURE — every method operates on entry
//  collections passed in by the caller. The caller fetches via SwiftData
//  (`HabitStore.entriesByDay(...)` / `HabitStore.allEntriesByDay(...)`).
//  Resolves flag #8 (the `@unchecked Sendable` hack + shared-context concurrency).
//

import Foundation

// MARK: - Shared Calendar

enum AppCalendar {
    static var current: Calendar { Calendar.current }
}

// MARK: - Date Formatters (Static for Performance)

enum DateFormatters {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    static let dayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static let shortDayOfWeek: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    static let dayNumber: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    static let monthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()

    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    // Alias for backward compatibility
    static var shortDateFormatter: DateFormatter { shortDate }

    static let month: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    // Alias for backward compatibility
    static var monthFormatter: DateFormatter { month }

    static let time: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static let weekdayMonthDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let iso: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - Habit Frequency Utility (Static - No Dependencies)

enum HabitFrequencyHelper {
    /// Determines if a habit should be tracked on a given date based on its frequency
    static func shouldTrack(_ habit: Habit, on date: Date) -> Bool {
        HabitFrequency.shouldTrack(
            frequency: habit.frequency,
            on: date,
            customDays: habit.customDays,
            startDate: habit.startDate
        )
    }
}

// MARK: - Habit Calculation Service (pure — no persistence)

final class HabitCalculationService {
    static let shared = HabitCalculationService()

    private let calendar = Calendar.current

    private init() {}

    // MARK: - Frequency Checking

    /// Determines if a habit should be tracked on a given date based on its frequency
    func shouldTrackHabit(_ habit: Habit, on date: Date) -> Bool {
        HabitFrequencyHelper.shouldTrack(habit, on: date)
    }

    // MARK: - Expected Days Calculation

    /// Calculates how many days a habit should have been tracked in a date range
    func calculateExpectedDays(for habit: Habit, from startDate: Date, to endDate: Date) -> Int {
        let frequency = HabitFrequency(rawValue: habit.frequency ?? HabitFrequency.daily.rawValue) ?? .daily

        // Fast path for daily habits
        if frequency == .daily {
            let components = calendar.dateComponents([.day], from: startDate, to: endDate)
            return (components.day ?? 0) + 1
        }

        // Count applicable days for other frequencies
        var count = 0
        var currentDate = startDate

        while currentDate <= endDate {
            if shouldTrackHabit(habit, on: currentDate) {
                count += 1
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return count
    }

    // MARK: - Completion Checking (Entry-Aware)

    /// Checks completion from a pre-fetched entries dictionary — O(1) lookup
    func isCompleted(in entries: [Date: HabitEntry], on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let entry = entries[dayStart] else { return false }
        return entry.completionState != .notDone
    }

    // MARK: - Streak Calculations (Entry-Aware)

    /// Calculates current streak using pre-fetched entries — no persistence access
    func calculateCurrentStreak(for habit: Habit, using entries: [Date: HabitEntry]) -> Int {
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        let maxDays = 365

        for _ in 0..<maxDays {
            if !shouldTrackHabit(habit, on: currentDate) {
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
                continue
            }

            if isCompleted(in: entries, on: currentDate) {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    /// Calculates best streak using pre-fetched entries — no persistence access
    func calculateBestStreak(for habit: Habit, using entries: [Date: HabitEntry], from startDate: Date, to endDate: Date) -> Int {
        var bestStreak = 0
        var currentStreak = 0
        var currentDate = startDate

        while currentDate <= endDate {
            if shouldTrackHabit(habit, on: currentDate) {
                if isCompleted(in: entries, on: currentDate) {
                    currentStreak += 1
                    bestStreak = max(bestStreak, currentStreak)
                } else {
                    currentStreak = 0
                }
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return bestStreak
    }

    /// Calculates overall current streak (all habits complete) using pre-fetched entries
    func calculateOverallCurrentStreak(for habits: [Habit], using allEntries: [UUID: [Date: HabitEntry]]) -> Int {
        guard !habits.isEmpty else { return 0 }

        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        let maxDays = 365

        for _ in 0..<maxDays {
            var allCompleted = true
            var anyTracked = false

            for habit in habits {
                if shouldTrackHabit(habit, on: currentDate) {
                    anyTracked = true
                    let entries = allEntries[habit.id ?? UUID()] ?? [:]
                    if !isCompleted(in: entries, on: currentDate) {
                        allCompleted = false
                        break
                    }
                }
            }

            if anyTracked && allCompleted {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Completion Rate (Entry-Aware)

    /// Calculates completion rate using pre-fetched entries — no persistence access
    func calculateCompletionRate(for habit: Habit, using entries: [Date: HabitEntry], from startDate: Date, to endDate: Date) -> (completed: Int, expected: Int, rate: Double) {
        let expected = calculateExpectedDays(for: habit, from: startDate, to: endDate)
        guard expected > 0 else { return (0, 0, 0) }

        var completed = 0
        var currentDate = startDate

        while currentDate <= endDate {
            if shouldTrackHabit(habit, on: currentDate) && isCompleted(in: entries, on: currentDate) {
                completed += 1
            }
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        let rate = Double(completed) / Double(expected)
        return (completed, expected, rate)
    }

    // MARK: - Batch Statistics (Entry-Aware)

    /// Calculate stats for multiple habits from pre-fetched entries.
    /// `allEntries` must cover BOTH the requested period and the 365-day streak lookback.
    func calculateBatchStats(
        for habits: [Habit],
        allEntries: [UUID: [Date: HabitEntry]],
        from startDate: Date,
        to endDate: Date
    ) -> (habitStats: [HabitStatResult], totalCompleted: Int, totalExpected: Int, maxStreak: Int) {

        var stats: [HabitStatResult] = []
        var totalCompleted = 0
        var totalExpected = 0
        var maxStreak = 0

        for habit in habits {
            guard let habitId = habit.id else { continue }
            let entriesForHabit = allEntries[habitId] ?? [:]

            // Count completed days within the requested period only
            var completedDays = 0
            var currentDate = startDate
            while currentDate <= endDate {
                if shouldTrackHabit(habit, on: currentDate) && isCompleted(in: entriesForHabit, on: currentDate) {
                    completedDays += 1
                }
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }

            let expectedDays = calculateExpectedDays(for: habit, from: startDate, to: endDate)
            let rate = expectedDays > 0 ? Int((Double(completedDays) / Double(expectedDays)) * 100) : 0
            let streak = calculateCurrentStreak(for: habit, using: entriesForHabit)
            maxStreak = max(maxStreak, streak)

            stats.append(HabitStatResult(
                habitId: habitId,
                name: habit.name ?? "Unnamed",
                icon: habit.icon ?? "circle",
                color: habit.color ?? "#007AFF",
                completionRate: rate,
                completedCount: completedDays,
                expectedDays: expectedDays,
                currentStreak: streak
            ))

            totalCompleted += completedDays
            totalExpected += expectedDays
        }

        return (stats, totalCompleted, totalExpected, maxStreak)
    }

    /// Build heatmap data (fraction of scheduled habits completed per day) from pre-fetched entries.
    func buildHeatmapData(for habits: [Habit], allEntries: [UUID: [Date: HabitEntry]], from startDate: Date, to endDate: Date) -> [Date: Double] {
        guard !habits.isEmpty else { return [:] }

        var rates: [Date: Double] = [:]
        var currentDate = calendar.startOfDay(for: startDate)
        let lastDate = calendar.startOfDay(for: endDate)

        while currentDate <= lastDate {
            var completed = 0
            var total = 0

            for habit in habits {
                if shouldTrackHabit(habit, on: currentDate) {
                    total += 1
                    if let habitId = habit.id,
                       let entry = allEntries[habitId]?[currentDate],
                       entry.completionState != .notDone {
                        completed += 1
                    }
                }
            }

            rates[currentDate] = total > 0 ? Double(completed) / Double(total) : 0

            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return rates
    }
}

// MARK: - Stat Result Model

struct HabitStatResult {
    let habitId: UUID
    let name: String
    let icon: String
    let color: String
    let completionRate: Int
    let completedCount: Int
    let expectedDays: Int
    let currentStreak: Int
}
