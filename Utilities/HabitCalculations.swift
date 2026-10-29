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

// MARK: - Win Rule
//
// `HabitWinRule` (bt-0014) lives in `Data/Models.swift` next to
// `CompletionStyle` / `CompletionState` so the widget target shares it.
// Every score here goes through `isWin(for:in:on:)` below.

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

    /// Expected days minus the neutral (Rest) days in the range (bt-0018), so a
    /// rest day drops out of the denominator as well as the numerator.
    func calculateExpectedDays(for habit: Habit, using entries: [Date: HabitEntry], from startDate: Date, to endDate: Date) -> Int {
        let expected = calculateExpectedDays(for: habit, from: startDate, to: endDate)
        let lo = calendar.startOfDay(for: startDate)
        let hi = calendar.startOfDay(for: endDate)
        let neutral = entries.filter { day, entry in
            day >= lo && day <= hi
                && HabitWinRule.isNeutral(state: entry.effectiveCompletionState)
                && shouldTrackHabit(habit, on: day)
        }.count
        return max(0, expected - neutral)
    }

    // MARK: - Win Checking (Entry-Aware)

    /// Whether `date` counts as a win for `habit`, per `HabitWinRule` — O(1)
    /// lookup in a pre-fetched entries dictionary.
    func isWin(for habit: Habit, in entries: [Date: HabitEntry], on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let isFuture = dayStart > calendar.startOfDay(for: Date())
        return HabitWinRule.isWin(
            style: habit.completionStyle,
            state: entries[dayStart]?.effectiveCompletionState,
            isFuture: isFuture
        )
    }

    /// Whether `date` is a neutral day for `habit` (a Rest day, bt-0018).
    func isNeutral(for habit: Habit, in entries: [Date: HabitEntry], on date: Date) -> Bool {
        HabitWinRule.isNeutral(state: entries[calendar.startOfDay(for: date)]?.effectiveCompletionState)
    }

    /// A day that takes part in scoring: scheduled, and not a Rest day.
    private func isScored(_ habit: Habit, in entries: [Date: HabitEntry], on date: Date) -> Bool {
        shouldTrackHabit(habit, on: date) && !isNeutral(for: habit, in: entries, on: date)
    }

    // MARK: - Streak Calculations (Entry-Aware)

    /// bt-0024 — a slip-scored habit (avoidance) has no streaks anywhere: a
    /// clean day is nothing to count, so Current and Best are always 0 and the
    /// Today row shows no flame. One check, shared by the three streak walks.
    private func hasStreaks(_ habit: Habit) -> Bool {
        !HabitWinRule.isSlipScored(style: habit.completionStyle)
    }

    /// Calculates current streak using pre-fetched entries — no persistence access.
    /// Unscheduled days and Rest days are skipped, not broken on.
    func calculateCurrentStreak(for habit: Habit, using entries: [Date: HabitEntry]) -> Int {
        guard hasStreaks(habit) else { return 0 }
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        let maxDays = 365

        for _ in 0..<maxDays {
            if !isScored(habit, in: entries, on: currentDate) {
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                currentDate = previousDay
                continue
            }

            if isWin(for: habit, in: entries, on: currentDate) {
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
        guard hasStreaks(habit) else { return 0 }
        var bestStreak = 0
        var currentStreak = 0
        var currentDate = startDate

        while currentDate <= endDate {
            if isScored(habit, in: entries, on: currentDate) {
                if isWin(for: habit, in: entries, on: currentDate) {
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

    /// Calculates overall current streak (all habits complete) using pre-fetched entries.
    /// Slip-scored habits (bt-0024) take no part: a clean Weed day neither
    /// extends nor breaks the run.
    func calculateOverallCurrentStreak(for habits: [Habit], using allEntries: [UUID: [Date: HabitEntry]]) -> Int {
        let habits = habits.filter(hasStreaks)
        guard !habits.isEmpty else { return 0 }

        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        let maxDays = 365

        for _ in 0..<maxDays {
            var allCompleted = true
            var anyTracked = false

            for habit in habits {
                let entries = allEntries[habit.id ?? UUID()] ?? [:]
                if isScored(habit, in: entries, on: currentDate) {
                    anyTracked = true
                    if !isWin(for: habit, in: entries, on: currentDate) {
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

    /// bt-0024 — the day that counts toward a habit's rate: a win for a
    /// positive habit, a slip for an avoidance habit. Readers label the
    /// result by `HabitWinRule.isSlipScored(style:)`.
    private func countsTowardRate(_ habit: Habit, in entries: [Date: HabitEntry], on date: Date) -> Bool {
        guard isScored(habit, in: entries, on: date) else { return false }
        if HabitWinRule.isSlipScored(style: habit.completionStyle) {
            return HabitWinRule.isSlip(style: habit.completionStyle,
                                       state: entries[calendar.startOfDay(for: date)]?.effectiveCompletionState)
        }
        return isWin(for: habit, in: entries, on: date)
    }

    /// Calculates completion rate using pre-fetched entries — no persistence access.
    /// For a slip-scored habit (bt-0024) `completed` is the number of **slip
    /// days** and `rate` the slip rate (lower is better); `expected` is the
    /// scored days either way.
    func calculateCompletionRate(for habit: Habit, using entries: [Date: HabitEntry], from startDate: Date, to endDate: Date) -> (completed: Int, expected: Int, rate: Double) {
        let expected = calculateExpectedDays(for: habit, using: entries, from: startDate, to: endDate)
        guard expected > 0 else { return (0, 0, 0) }

        var completed = 0
        var currentDate = startDate

        while currentDate <= endDate {
            if countsTowardRate(habit, in: entries, on: currentDate) {
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
    /// bt-0024: a slip-scored habit's row carries its slip days and slip rate
    /// (`isSlipRate`), and stays out of `totalCompleted` / `totalExpected` —
    /// the overall figure is positive habits only, and a slip never lowers it.
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

            // Count the days that count (wins, or slips for avoidance) within the requested period only
            var completedDays = 0
            var currentDate = startDate
            while currentDate <= endDate {
                if countsTowardRate(habit, in: entriesForHabit, on: currentDate) {
                    completedDays += 1
                }
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }

            let expectedDays = calculateExpectedDays(for: habit, using: entriesForHabit, from: startDate, to: endDate)
            let rate = expectedDays > 0 ? Int((Double(completedDays) / Double(expectedDays)) * 100) : 0
            let streak = calculateCurrentStreak(for: habit, using: entriesForHabit)
            maxStreak = max(maxStreak, streak)
            let isSlipRate = HabitWinRule.isSlipScored(style: habit.completionStyle)

            stats.append(HabitStatResult(
                habitId: habitId,
                name: habit.name ?? "Unnamed",
                icon: habit.icon ?? "circle",
                color: habit.color ?? "#007AFF",
                completionRate: rate,
                completedCount: completedDays,
                expectedDays: expectedDays,
                currentStreak: streak,
                isSlipRate: isSlipRate
            ))

            if !isSlipRate {
                totalCompleted += completedDays
                totalExpected += expectedDays
            }
        }

        return (stats, totalCompleted, totalExpected, maxStreak)
    }

    /// Build heatmap data (fraction of scheduled habits completed per day) from pre-fetched entries.
    /// Positive habits only (bt-0024): a slip-scored habit has no "completed".
    func buildHeatmapData(for habits: [Habit], allEntries: [UUID: [Date: HabitEntry]], from startDate: Date, to endDate: Date) -> [Date: Double] {
        let habits = habits.filter(hasStreaks)
        guard !habits.isEmpty else { return [:] }

        var rates: [Date: Double] = [:]
        var currentDate = calendar.startOfDay(for: startDate)
        let lastDate = calendar.startOfDay(for: endDate)

        while currentDate <= lastDate {
            var completed = 0
            var total = 0

            for habit in habits {
                let entries = allEntries[habit.id ?? UUID()] ?? [:]
                if isScored(habit, in: entries, on: currentDate) {
                    total += 1
                    if isWin(for: habit, in: entries, on: currentDate) {
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
    /// bt-0024 — true for an avoidance habit: `completionRate` is a slip rate
    /// (lower is better) and `completedCount` is slip days.
    let isSlipRate: Bool
}
