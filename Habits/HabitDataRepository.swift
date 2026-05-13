//
//  HabitDataRepository.swift
//  Bullet Tracker
//
//  SwiftData migration (bt-0002): this used to be an `@Observable` singleton
//  holding a `[habit][date] → entry` cache, optimistic-update bookkeeping, and an
//  `NSManagedObjectContextDidSave` listener. All of that is gone — SwiftData's
//  `@Query` keeps views live, and the relationship (`habit.entries`) is the cache.
//  What remains: `HabitStore`, a thin namespace of read helpers (over the in-memory
//  relationship) and write helpers (over a `ModelContext`), plus the
//  `HabitCompletionState` value type the Today UI renders.
//

import SwiftUI
import SwiftData
import WidgetKit

// MARK: - HabitStore

enum HabitStore {

    private static let calendar = Calendar.current
    private static let widgetKind = "HabitTrackerWidget"

    // MARK: - Reads (over the in-memory relationship)

    /// The `HabitEntry` for a habit on a given day, if one exists.
    static func entry(for habit: Habit, on date: Date) -> HabitEntry? {
        let dayStart = calendar.startOfDay(for: date)
        return habit.entries?.first { entry in
            guard let entryDate = entry.date else { return false }
            return calendar.startOfDay(for: entryDate) == dayStart
        }
    }

    /// The completion state for a habit on a specific date.
    static func completionState(for habit: Habit, on date: Date) -> HabitCompletionState {
        guard let entry = entry(for: habit, on: date) else {
            return HabitCompletionState(isCompleted: false, state: 0, hasDetails: false)
        }
        let state = Int(entry.completionState)
        let hasDetails = checkForMeaningfulDetails(in: entry, habit: habit, state: state)
        // isCompleted tracks state > 0 (the legacy `completed` Bool is unreliable; Phase 2 collapses these).
        return HabitCompletionState(isCompleted: state > 0, state: state, hasDetails: hasDetails)
    }

    /// All of a habit's entries in `[startDate, endDate]`, keyed by start-of-day.
    static func entriesByDay(for habit: Habit, from startDate: Date, to endDate: Date) -> [Date: HabitEntry] {
        let lo = calendar.startOfDay(for: startDate)
        let hi = calendar.startOfDay(for: endDate)
        var result: [Date: HabitEntry] = [:]
        for entry in habit.entries ?? [] {
            guard let entryDate = entry.date else { continue }
            let day = calendar.startOfDay(for: entryDate)
            if day >= lo && day <= hi { result[day] = entry }
        }
        return result
    }

    /// `entriesByDay` for many habits at once, keyed by habit id.
    static func allEntriesByDay(for habits: [Habit], from startDate: Date, to endDate: Date) -> [UUID: [Date: HabitEntry]] {
        var result: [UUID: [Date: HabitEntry]] = [:]
        for habit in habits {
            guard let id = habit.id else { continue }
            result[id] = entriesByDay(for: habit, from: startDate, to: endDate)
        }
        return result
    }

    // MARK: - Writes (over a ModelContext)

    /// Sets a habit's completion for a date. `state == 0` removes the entry; otherwise creates/updates it.
    static func setCompletion(for habit: Habit, on date: Date, state: Int, in context: ModelContext) {
        let dayStart = calendar.startOfDay(for: date)

        if state == 0 {
            removeEntry(for: habit, on: dayStart, in: context)
            return
        }

        if let existing = entry(for: habit, on: dayStart) {
            existing.completed = true
            existing.completionState = Int16(state)
        } else {
            let entry = HabitEntry(date: dayStart, completed: true, completionState: Int16(state), habit: habit)
            context.insert(entry)
        }
        save(context)
        reloadWidgetIfToday(dayStart)
    }

    /// Removes a habit's entry for a date, if any.
    static func removeEntry(for habit: Habit, on date: Date, in context: ModelContext) {
        let dayStart = calendar.startOfDay(for: date)
        guard let entry = entry(for: habit, on: dayStart) else { return }
        context.delete(entry)
        save(context)
        reloadWidgetIfToday(dayStart)
    }

    /// Creates or updates a habit's entry for a date, setting its state and details JSON blob.
    static func updateEntryDetails(for habit: Habit, on date: Date, state: Int, details: String, in context: ModelContext) {
        let dayStart = calendar.startOfDay(for: date)
        if let existing = entry(for: habit, on: dayStart) {
            existing.completed = true
            existing.completionState = Int16(state)
            existing.details = details
        } else {
            let entry = HabitEntry(date: dayStart, completed: true, completionState: Int16(state), details: details, habit: habit)
            context.insert(entry)
        }
        save(context)
        reloadWidgetIfToday(dayStart)
    }

    /// Persists a new ordering for the habit list (called from `onMove`).
    static func reorderHabits(_ habits: [Habit], from source: IndexSet, to destination: Int, in context: ModelContext) {
        var reordered = habits
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in reordered.enumerated() {
            habit.order = Int32(index)
        }
        save(context)
    }

    // MARK: - Private

    private static func save(_ context: ModelContext) {
        do { try context.save() } catch {
            debugLog("HabitStore: save failed — \(error.localizedDescription)")
        }
    }

    private static func reloadWidgetIfToday(_ dayStart: Date) {
        if calendar.isDateInToday(dayStart) {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        }
    }

    /// Whether an entry carries details worth surfacing an indicator for.
    private static func checkForMeaningfulDetails(in entry: HabitEntry, habit: Habit, state: Int) -> Bool {
        guard let detailsString = entry.details, !detailsString.isEmpty else { return false }

        // Plain-text (non-JSON) details count as meaningful.
        guard let data = detailsString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return !detailsString.isEmpty
        }

        if isWorkoutHabit(habit) && habit.useMultipleStates {
            // Only the "success" state with actual workout data gets an indicator.
            return state == 1 &&
                (!((json["types"] as? [String])?.isEmpty ?? true) ||
                 !((json["duration"] as? String)?.isEmpty ?? true))
        }

        return !((json["notes"] as? String)?.isEmpty ?? true)
    }

    /// Flag #4: a habit logs workouts iff its `detailType` says so — no more name-keyword guessing.
    private static func isWorkoutHabit(_ habit: Habit) -> Bool {
        habit.detailType == "workout"
    }
}

// MARK: - HabitCompletionState

/// Represents the completion state of a habit on a specific date.
struct HabitCompletionState {
    let isCompleted: Bool
    let state: Int // 0: none, 1: success, 2: partial, 3: failure
    let hasDetails: Bool

    var stateColor: Color {
        guard isCompleted else { return .clear }
        switch state {
        case 1: return Color(hex: "#4CAF50")   // Success — warm green
        case 2: return Color(hex: "#FFB300")   // Partial — warm yellow
        case 3: return Color(hex: "#EF5350")   // Attempted — soft red
        default: return Color(hex: "#4CAF50")
        }
    }

    var stateIcon: String {
        switch state {
        case 1: return "checkmark"
        case 2: return "circle.lefthalf.filled"
        case 3: return "xmark"
        default: return "checkmark"
        }
    }
}
