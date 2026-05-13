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
            calendar.startOfDay(for: entry.date) == dayStart
        }
    }

    /// The completion state for a habit on a specific date.
    static func completionState(for habit: Habit, on date: Date) -> HabitCompletionState {
        guard let entry = entry(for: habit, on: date) else {
            return HabitCompletionState(isCompleted: false, state: 0, hasDetails: false)
        }
        let state = Int(entry.completionState.rawValue)
        let hasDetails = checkForMeaningfulDetails(in: entry, habit: habit, state: state)
        return HabitCompletionState(isCompleted: entry.completionState != .notDone, state: state, hasDetails: hasDetails)
    }

    /// All of a habit's entries in `[startDate, endDate]`, keyed by start-of-day.
    static func entriesByDay(for habit: Habit, from startDate: Date, to endDate: Date) -> [Date: HabitEntry] {
        let lo = calendar.startOfDay(for: startDate)
        let hi = calendar.startOfDay(for: endDate)
        var result: [Date: HabitEntry] = [:]
        for entry in habit.entries ?? [] {
            let day = calendar.startOfDay(for: entry.date)
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

    /// Sets a habit's completion for a date. `state == 0` (`.notDone`) removes the entry; otherwise creates/updates it.
    static func setCompletion(for habit: Habit, on date: Date, state: Int, in context: ModelContext) {
        let dayStart = calendar.startOfDay(for: date)
        let typedState = CompletionState(rawValue: Int16(state)) ?? .notDone

        if typedState == .notDone {
            removeEntry(for: habit, on: dayStart, in: context)
            return
        }

        if let existing = entry(for: habit, on: dayStart) {
            existing.completionState = typedState
        } else {
            let entry = HabitEntry(date: dayStart, completionState: typedState, habit: habit)
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

    /// Creates or updates a habit's entry for a date, setting its state and typed details payload.
    static func updateEntryDetails(for habit: Habit, on date: Date, state: Int, details: HabitEntryDetails?, in context: ModelContext) {
        let dayStart = calendar.startOfDay(for: date)
        let typedState = CompletionState(rawValue: Int16(state)) ?? .success
        if let existing = entry(for: habit, on: dayStart) {
            existing.completionState = typedState
            existing.details = details
        } else {
            let entry = HabitEntry(date: dayStart, completionState: typedState, details: details, habit: habit)
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
    /// Post-Wave-3: details are typed (`HabitEntryDetails?`), so we pattern-match
    /// the payload directly instead of hand-parsing JSON strings.
    private static func checkForMeaningfulDetails(in entry: HabitEntry, habit: Habit, state: Int) -> Bool {
        guard let details = entry.details else { return false }

        // Workout habits in multi-state mode: only the "success" state with
        // actual workout content gets the indicator (matches pre-Wave-3 logic).
        if habit.detailKind == .workout && habit.completionStyle == .multiState {
            guard case let .workout(types, duration, _, _) = details else { return false }
            return state == 1 && (!types.isEmpty || !duration.isEmpty)
        }

        // For all other cases: any non-empty notes count.
        switch details {
        case .notes(let notes),
             .workout(_, _, _, let notes),
             .reading(_, _, let notes),
             .mood(_, let notes):
            return !notes.isEmpty
        }
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
