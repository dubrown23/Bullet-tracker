//
//  Models.swift
//  Bullet Tracker
//
//  SwiftData @Model types.
//
//  Phase 1 (bt-0002): swapped the Core Data engine for SwiftData; model SHAPE
//  was unchanged so the existing App-Group store opens in place.
//
//  Phase 2 (bt-0003) — in progress:
//    Wave 1 (done): dropped the dormant bullet-journal layer entirely —
//      `@Model` types `Collection` / `JournalEntry` / `Tag` and the 7 vestigial
//      "future log / migration" fields. Live Journal tab uses `Note`.
//    Waves 2–5 (queued): lift `HabitEntry.date: Date? → Date`; collapse the
//      4 Habit-level flags into `CompletionStyle` + `DetailKind` enums; type
//      the `details` JSON blob into `HabitEntryDetails`; rewrite hot-path
//      predicates.
//    Wave 6 (queued): the `VersionedSchema` migration that lands all of the
//      above against the live CloudKit-synced store.
//
//  Requirements that must hold for this to work:
//   • The `.xcdatamodeld` entities' Codegen must be set to "Manual/None" so these
//     are the only Habit/HabitEntry/Note types.
//   • This file must be a member of BOTH the app target and the widget target.
//   • CloudKit-safe: every relationship is optional; no `@Attribute(.unique)`.
//

import Foundation
import SwiftData

// MARK: - Habit

@Model
final class Habit {
    var id: UUID?
    var name: String?
    var color: String?
    var icon: String?
    var frequency: String?
    var customDays: String?
    var notes: String?
    var startDate: Date?
    var order: Int32 = 0

    /// Detail-capture flags (still modeled the legacy way in Phase 1; collapsed in Phase 2 Wave 3).
    var detailType: String?
    var trackDetails: Bool = false
    var useMultipleStates: Bool = false
    var isNegativeHabit: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry]?

    init(
        id: UUID? = UUID(),
        name: String? = nil,
        color: String? = nil,
        icon: String? = nil,
        frequency: String? = nil,
        customDays: String? = nil,
        notes: String? = nil,
        startDate: Date? = nil,
        order: Int32 = 0,
        detailType: String? = nil,
        trackDetails: Bool = false,
        useMultipleStates: Bool = false,
        isNegativeHabit: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.frequency = frequency
        self.customDays = customDays
        self.notes = notes
        self.startDate = startDate
        self.order = order
        self.detailType = detailType
        self.trackDetails = trackDetails
        self.useMultipleStates = useMultipleStates
        self.isNegativeHabit = isNegativeHabit
    }
}

// MARK: - HabitEntry

@Model
final class HabitEntry {
    // Re-creates the `byDateIndex` fetch index the original `.xcdatamodeld` had.
    // Cheap to write, big read-time win for date-bounded queries (bt-0004).
    #Index<HabitEntry>([\.date])

    var id: UUID?
    var date: Date?

    /// Legacy completion fields — Phase 1 keeps both; Phase 2 collapses to one value.
    var completed: Bool = false
    var completionState: Int16 = 0

    /// Structured details as a JSON string blob (Phase 2 replaces this with typed fields).
    var details: String?

    var habit: Habit?

    init(
        id: UUID? = UUID(),
        date: Date? = nil,
        completed: Bool = false,
        completionState: Int16 = 0,
        details: String? = nil,
        habit: Habit? = nil
    ) {
        self.id = id
        self.date = date
        self.completed = completed
        self.completionState = completionState
        self.details = details
        self.habit = habit
    }
}

// MARK: - Note

@Model
final class Note {
    var id: UUID?
    var date: Date?
    var content: String?

    init(id: UUID? = UUID(), date: Date? = nil, content: String? = nil) {
        self.id = id
        self.date = date
        self.content = content
    }
}

