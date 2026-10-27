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

    // MARK: - Reads (FetchDescriptor + #Predicate, Wave 4)
    //
    // Phase-2 Wave 4 rewrite: every read here used to walk `habit.entries` in
    // memory — `habit.entries?.first { ... }` faults the entire relationship
    // (~entries-per-habit, can be thousands for a habit tracked daily for
    // years) and filters in Swift. Wave 2's non-optional `HabitEntry.date` +
    // bt-0004's `#Index<HabitEntry>([\.date])` make `FetchDescriptor` +
    // `#Predicate` on `habit.id` + a date range the right shape — index-backed,
    // SQL-level narrowing, no full faulting.
    //
    // Signature kept unchanged on purpose: `habit.modelContext` gives us the
    // context the habit is attached to, so no `ModelContext` parameter needs
    // to ripple through the 7 view/viewmodel callers. Reads that arrive with
    // a habit that isn't yet attached to a context (placeholder / preview)
    // fall back to nil-or-empty cleanly.

    /// The `HabitEntry` for a habit on a given day, if one exists. When two
    /// devices have produced two rows, this is the one the cleanup pass will
    /// keep (bt-0018), so what's shown never changes when the pass runs.
    static func entry(for habit: Habit, on date: Date) -> HabitEntry? {
        entries(for: habit, on: date).first
    }

    /// The completion state for a habit on a specific date.
    static func completionState(for habit: Habit, on date: Date) -> HabitCompletionState {
        return completionState(for: habit, entry: entry(for: habit, on: date))
    }

    /// Builds `HabitCompletionState` from an already-fetched entry (or `nil` if
    /// no entry exists). Use when the caller has prefetched the entry as part
    /// of a batched range query — avoids the per-day predicate fetch inside
    /// `completionState(for:on:)`. Wave 4.5 hotfix surface: `TodayHabitRowView`
    /// prefetches a 7-day window once per card body and feeds the entries here.
    static func completionState(for habit: Habit, entry: HabitEntry?) -> HabitCompletionState {
        guard let entry else {
            return HabitCompletionState(isCompleted: false, state: 0, hasDetails: false)
        }
        let state = Int(entry.effectiveCompletionState.rawValue)
        let hasDetails = checkForMeaningfulDetails(in: entry, habit: habit, state: state)
        return HabitCompletionState(isCompleted: entry.effectiveCompletionState != .notDone, state: state, hasDetails: hasDetails)
    }

    /// Whether `date` is a neutral (Rest) day for `habit` (bt-0018).
    static func isNeutral(entry: HabitEntry?) -> Bool {
        HabitWinRule.isNeutral(state: entry?.effectiveCompletionState)
    }

    /// Whether `date` counts as a win for `habit` given its entry (or none) —
    /// the style-aware rule (`HabitWinRule`), not "an entry exists".
    static func isWin(for habit: Habit, entry: HabitEntry?, on date: Date) -> Bool {
        let isFuture = calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
        return HabitWinRule.isWin(
            style: habit.completionStyle,
            state: entry?.effectiveCompletionState,
            isFuture: isFuture
        )
    }

    /// All of a habit's entries in `[startDate, endDate]`, keyed by start-of-day.
    static func entriesByDay(for habit: Habit, from startDate: Date, to endDate: Date) -> [Date: HabitEntry] {
        guard let context = habit.modelContext, let habitID = habit.id else { return [:] }
        let lo = calendar.startOfDay(for: startDate)
        let hiDay = calendar.startOfDay(for: endDate)
        // Inclusive end: extend to the start of the day AFTER `endDate` so the
        // half-open `< hiExclusive` predicate captures `endDate`'s own entries.
        let hiExclusive = calendar.date(byAdding: .day, value: 1, to: hiDay) ?? hiDay
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.habit?.id == habitID && entry.date >= lo && entry.date < hiExclusive
            }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        var result: [Date: HabitEntry] = [:]
        result.reserveCapacity(entries.count)
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            // Two rows on one day (not yet cleaned up): show the survivor.
            if let existing = result[day], dedupeKey(existing) <= dedupeKey(entry) { continue }
            result[day] = entry
        }
        return result
    }

    /// EVERY entry for a habit on a given day — no fetch limit. Normally one;
    /// two or more means two devices wrote the same day before CloudKit
    /// merged (bt-0017). Sorted by id string so callers see the same order
    /// on every device.
    static func entries(for habit: Habit, on date: Date) -> [HabitEntry] {
        guard let context = habit.modelContext, let habitID = habit.id else { return [] }
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.habit?.id == habitID && entry.date >= dayStart && entry.date < dayEnd
            }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.sorted { dedupeKey($0) < dedupeKey($1) }
    }

    /// Raw row count for a habit on a day. The Today row can't show this
    /// (one tick looks the same over one row or two); the Developer screen does.
    static func entryCount(for habit: Habit, on date: Date) -> Int {
        entries(for: habit, on: date).count
    }

    /// `entriesByDay` for many habits at once, keyed by habit id.
    ///
    /// One indexed fetch over the date range, then partition by habit in Swift
    /// — avoids an IN-predicate on optional UUID through an optional
    /// relationship (the fragile shape bt-0004 documented), and avoids
    /// N round-trips one per habit. The `#Index<HabitEntry>([\.date])` from
    /// bt-0004 carries the cost.
    static func allEntriesByDay(for habits: [Habit], from startDate: Date, to endDate: Date) -> [UUID: [Date: HabitEntry]] {
        guard let context = habits.first?.modelContext else { return [:] }
        let lo = calendar.startOfDay(for: startDate)
        let hiDay = calendar.startOfDay(for: endDate)
        let hiExclusive = calendar.date(byAdding: .day, value: 1, to: hiDay) ?? hiDay
        let descriptor = FetchDescriptor<HabitEntry>(
            predicate: #Predicate { entry in
                entry.date >= lo && entry.date < hiExclusive
            }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        // Pre-build the habit-ID set so we partition only entries that belong
        // to one of the passed habits (the date-only predicate catches all
        // habits' entries in the range).
        let wantedIDs = Set(habits.compactMap { $0.id })
        var result: [UUID: [Date: HabitEntry]] = [:]
        for entry in entries {
            guard let id = entry.habit?.id, wantedIDs.contains(id) else { continue }
            let day = calendar.startOfDay(for: entry.date)
            if let existing = result[id]?[day], dedupeKey(existing) <= dedupeKey(entry) { continue }
            result[id, default: [:]][day] = entry
        }
        return result
    }

    // MARK: - Writes (over a ModelContext)
    //
    // bt-0018: every write stamps who wrote the row (`source`, default hand —
    // a tap) and when (`editedAt`). The automatic grader passes `.auto`;
    // Step 3's inbox will pass `.voice`.

    /// Sets a habit's completion for a date. `state == 0` (`.notDone`) removes the entry; otherwise creates/updates it.
    static func setCompletion(for habit: Habit, on date: Date, state: Int, source: EntrySource = .hand, in context: ModelContext) {
        let dayStart = calendar.startOfDay(for: date)
        let typedState = CompletionState(rawValue: Int16(state)) ?? .notDone

        if typedState == .notDone {
            removeEntry(for: habit, on: dayStart, in: context)
            return
        }

        if let existing = entry(for: habit, on: dayStart) {
            existing.completionState = typedState
            existing.source = source
            existing.editedAt = Date()
        } else {
            let entry = HabitEntry(date: dayStart, completionState: typedState, habit: habit, source: source, editedAt: Date())
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
    static func updateEntryDetails(for habit: Habit, on date: Date, state: Int, details: HabitEntryDetails?, source: EntrySource = .hand, in context: ModelContext) {
        let dayStart = calendar.startOfDay(for: date)
        let typedState = CompletionState(rawValue: Int16(state)) ?? .success
        if let existing = entry(for: habit, on: dayStart) {
            existing.completionState = typedState
            existing.details = details
            existing.source = source
            existing.editedAt = Date()
        } else {
            let entry = HabitEntry(date: dayStart, completionState: typedState, details: details, habit: habit, source: source, editedAt: Date())
            context.insert(entry)
        }
        save(context)
        reloadWidgetIfToday(dayStart)
    }

    /// Cleanup pass (bt-0017, rule sharpened in bt-0018): collapses duplicate
    /// rows for one habit + day down to one. Returns how many rows were deleted.
    ///
    /// CloudKit can't enforce "one entry per habit per day", so two devices
    /// writing the same day offline each create a row. The rule here is
    /// built so every device picks the SAME survivor and no sequence of
    /// devices can reach zero rows:
    ///   • A device that sees fewer than two rows deletes nothing.
    ///   • The survivor is, in order: a hand / voice row over an automatic
    ///     one ("overrides win"); then the newest `editedAt`; then the
    ///     smallest `id.uuidString`. All three fields travel with the row,
    ///     so every device orders the same rows the same way.
    ///   • Rows with a `nil` id never win against a row with an id and are
    ///     never deleted (we can't order them deterministically). In
    ///     practice every row has an id; this is belt-and-braces.
    @discardableResult
    static func dedupeEntries(for habit: Habit, on date: Date, in context: ModelContext) -> Int {
        let rows = entries(for: habit, on: date)
        guard rows.count > 1, let winner = rows.first, winner.id != nil else { return 0 }

        var removed = 0
        for row in rows.dropFirst() where row.id != nil {
            context.delete(row)
            removed += 1
        }
        if removed > 0 {
            save(context)
            reloadWidgetIfToday(calendar.startOfDay(for: date))
        }
        return removed
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

    /// Sort key for `entries(for:on:)` / `dedupeEntries` — the survivor sorts
    /// first. Built as one string so plain `<` gives the same order on every
    /// device: hand / voice ("0") before auto ("1"); then newer edits first
    /// (the edit time inverted, zero-padded; rows with no edit time last);
    /// then the smallest id. Rows without an id sort after every row with
    /// one ("~" is above hex digits in ASCII).
    static func dedupeKey(_ entry: HabitEntry) -> String {
        let rank = entry.isAutomatic ? "1" : "0"
        let edited: String
        if let t = entry.editedAt?.timeIntervalSinceReferenceDate {
            // Invert so newer sorts first; pad so string order = numeric order.
            let inverted = max(0, 10_000_000_000 - Int64(t))
            edited = String(format: "%011lld", inverted)
        } else {
            edited = "99999999999"
        }
        return rank + edited + (entry.id?.uuidString ?? "~")
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
    let state: Int // 0: none, 1: success, 2: partial, 3: failure, 4: rest
    let hasDetails: Bool

    var stateColor: Color {
        guard isCompleted else { return .clear }
        switch state {
        case 1: return AppTheme.success
        case 2: return AppTheme.partial
        case 3: return AppTheme.failed
        case 4: return AppTheme.rest
        default: return AppTheme.success
        }
    }

    var stateIcon: String {
        switch state {
        case 1: return "checkmark"
        case 2: return "circle.lefthalf.filled"
        case 3: return "xmark"
        case 4: return "zzz"
        default: return "checkmark"
        }
    }
}
