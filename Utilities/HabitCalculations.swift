//
//  HabitCalculations.swift
//  Bullet Tracker
//
//  Shared utilities for habit streak and completion calculations
//

import Foundation
import CoreData

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

// MARK: - Layout Constants

enum LayoutConstants {
    // Grid dimensions
    static let dateColumnWidth: CGFloat = 52
    static let habitColumnWidth: CGFloat = 50
    static let rowHeight: CGFloat = 44
    static let headerHeight: CGFloat = 60

    // Spacing
    static let standardPadding: CGFloat = 16
    static let smallPadding: CGFloat = 8
    static let tinyPadding: CGFloat = 4

    // Corner radius
    static let cardRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 8
    static let smallRadius: CGFloat = 6

    // Icon sizes
    static let smallIcon: CGFloat = 14
    static let mediumIcon: CGFloat = 20
    static let largeIcon: CGFloat = 24

    // Font sizes
    static let captionSize: CGFloat = 12
    static let bodySize: CGFloat = 14
    static let headlineSize: CGFloat = 16
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

// MARK: - Habit Calculation Service

class HabitCalculationService: @unchecked Sendable {
    static let shared = HabitCalculationService()

    private let calendar = Calendar.current
    private let context: NSManagedObjectContext

    private init() {
        self.context = CoreDataManager.shared.container.viewContext
    }

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

    /// Checks completion from pre-fetched entries dictionary — O(1) lookup
    func isCompleted(in entries: [Date: HabitEntry], on date: Date) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        guard let entry = entries[dayStart] else { return false }
        return entry.completionState > 0
    }

    /// Checks if a habit was completed on a specific date (convenience — fetches from Core Data)
    func isHabitCompleted(_ habit: Habit, on date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return false
        }

        let request: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@ AND completionState > 0",
            habit, startOfDay as NSDate, endOfDay as NSDate
        )
        request.fetchLimit = 1

        let count = (try? context.count(for: request)) ?? 0
        return count > 0
    }

    // MARK: - Streak Calculations (Entry-Aware)

    /// Calculates current streak using pre-fetched entries — no Core Data queries
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

    /// Convenience: fetches entries then calculates current streak
    func calculateCurrentStreak(for habit: Habit) -> Int {
        let today = calendar.startOfDay(for: Date())
        guard let yearAgo = calendar.date(byAdding: .day, value: -365, to: today) else { return 0 }
        let entries = fetchEntries(for: habit, from: yearAgo, to: today)
        return calculateCurrentStreak(for: habit, using: entries)
    }

    /// Calculates best streak using pre-fetched entries — no Core Data queries
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

    /// Convenience: fetches entries then calculates best streak
    func calculateBestStreak(for habit: Habit, from startDate: Date, to endDate: Date) -> Int {
        let entries = fetchEntries(for: habit, from: startDate, to: endDate)
        return calculateBestStreak(for: habit, using: entries, from: startDate, to: endDate)
    }

    /// Calculates overall current streak using pre-fetched entries — no Core Data queries
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

    /// Convenience: fetches all entries then calculates overall streak
    func calculateOverallCurrentStreak(for habits: [Habit]) -> Int {
        let today = calendar.startOfDay(for: Date())
        guard let yearAgo = calendar.date(byAdding: .day, value: -365, to: today) else { return 0 }
        let allEntries = fetchAllEntries(for: habits, from: yearAgo, to: today)
        return calculateOverallCurrentStreak(for: habits, using: allEntries)
    }

    // MARK: - Completion Rate (Entry-Aware)

    /// Calculates completion rate using pre-fetched entries — no Core Data queries
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

    /// Convenience: fetches entries then calculates completion rate
    func calculateCompletionRate(for habit: Habit, from startDate: Date, to endDate: Date) -> (completed: Int, expected: Int, rate: Double) {
        let entries = fetchEntries(for: habit, from: startDate, to: endDate)
        return calculateCompletionRate(for: habit, using: entries, from: startDate, to: endDate)
    }

    // MARK: - Batch Fetching (Performance Optimization)

    /// Fetches all entries for a habit in a date range (more efficient than individual queries)
    func fetchEntries(for habit: Habit, from startDate: Date, to endDate: Date, using ctx: NSManagedObjectContext? = nil) -> [Date: HabitEntry] {
        let fetchContext = ctx ?? context
        let request: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit, startDate as NSDate, endDate as NSDate
        )

        let entries = (try? fetchContext.fetch(request)) ?? []

        var result: [Date: HabitEntry] = [:]
        for entry in entries {
            if let date = entry.date {
                let dayStart = calendar.startOfDay(for: date)
                result[dayStart] = entry
            }
        }

        return result
    }

    /// Fetches all entries for multiple habits in a date range (single query - much more efficient)
    func fetchAllEntries(for habits: [Habit], from startDate: Date, to endDate: Date, using ctx: NSManagedObjectContext? = nil) -> [UUID: [Date: HabitEntry]] {
        guard !habits.isEmpty else { return [:] }

        let fetchContext = ctx ?? context
        let request: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "habit IN %@ AND date >= %@ AND date <= %@",
            habits, startDate as NSDate, endDate as NSDate
        )

        let entries = (try? fetchContext.fetch(request)) ?? []

        var result: [UUID: [Date: HabitEntry]] = [:]
        // Initialize empty dictionaries for each habit
        for habit in habits {
            if let id = habit.id {
                result[id] = [:]
            }
        }

        // Group entries by habit and date
        for entry in entries {
            guard let habitId = entry.habit?.id, let date = entry.date else { continue }
            let dayStart = calendar.startOfDay(for: date)
            result[habitId]?[dayStart] = entry
        }

        return result
    }

    // MARK: - Batch Statistics (Performance Optimization)

    /// Calculate stats for multiple habits efficiently using batch-fetched entries
    func calculateBatchStats(
        for habits: [Habit],
        from startDate: Date,
        to endDate: Date,
        using ctx: NSManagedObjectContext? = nil
    ) -> (habitStats: [HabitStatResult], totalCompleted: Int, totalExpected: Int, maxStreak: Int, allEntries: [UUID: [Date: HabitEntry]]) {

        // Expand fetch range to cover streak lookback (365 days)
        let today = calendar.startOfDay(for: Date())
        let streakStart = calendar.date(byAdding: .day, value: -365, to: today) ?? startDate
        let fetchStart = min(streakStart, startDate)

        // Single batch fetch for all habits covering both stats and streak ranges
        let allEntries = fetchAllEntries(for: habits, from: fetchStart, to: endDate, using: ctx)

        var stats: [HabitStatResult] = []
        var totalCompleted = 0
        var totalExpected = 0
        var maxStreak = 0

        for habit in habits {
            guard let habitId = habit.id else { continue }
            let entriesForHabit = allEntries[habitId] ?? [:]

            // Count completed days from pre-fetched entries (within the requested period only)
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

            // Calculate streak using pre-fetched entries — no additional queries
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

        return (stats, totalCompleted, totalExpected, maxStreak, allEntries)
    }

    /// Build heatmap data efficiently using batch fetch
    func buildHeatmapData(for habits: [Habit], from startDate: Date, to endDate: Date, using ctx: NSManagedObjectContext? = nil) -> [Date: Double] {
        guard !habits.isEmpty else { return [:] }

        // Single batch fetch
        let allEntries = fetchAllEntries(for: habits, from: startDate, to: endDate, using: ctx)

        var rates: [Date: Double] = [:]
        var currentDate = startDate

        while currentDate <= endDate {
            var completed = 0
            var total = 0

            for habit in habits {
                if shouldTrackHabit(habit, on: currentDate) {
                    total += 1
                    if let habitId = habit.id,
                       let entry = allEntries[habitId]?[currentDate],
                       entry.completionState > 0 {
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
