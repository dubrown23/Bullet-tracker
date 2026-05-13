//
//  Models.swift
//  Bullet Tracker
//
//  SwiftData @Model types. Phase 1 of the SwiftData migration (bt-0002):
//  these MIRROR the existing `Bullet_Tracker.xcdatamodeld` field-for-field so
//  SwiftData can coexist with the Core Data stack on the same App-Group store
//  while consumers migrate over. The model SHAPE is not changed here — typing
//  the `details` blob, collapsing the completion state, and dropping the
//  vestigial JournalEntry fields are Phase 2 (bt-0003).
//
//  Requirements that must hold for this to work:
//   • The `.xcdatamodeld` entities' Codegen must be set to "Manual/None" so these
//     are the only Habit/HabitEntry/Collection/JournalEntry/Note/Tag types.
//   • This file must be a member of BOTH the app target and the widget target.
//   • CloudKit-safe: every relationship is optional; no `@Attribute(.unique)`.
//

import Foundation
import SwiftData

// MARK: - Collection

@Model
final class Collection {
    var id: UUID?
    var name: String?
    var collectionType: String?
    var isAutomatic: Bool = false
    var sortOrder: Int32 = 0

    @Relationship(deleteRule: .nullify, inverse: \Habit.collection)
    var habits: [Habit]?

    @Relationship(deleteRule: .nullify, inverse: \JournalEntry.collection)
    var entries: [JournalEntry]?

    init(
        id: UUID? = UUID(),
        name: String? = nil,
        collectionType: String? = nil,
        isAutomatic: Bool = false,
        sortOrder: Int32 = 0
    ) {
        self.id = id
        self.name = name
        self.collectionType = collectionType
        self.isAutomatic = isAutomatic
        self.sortOrder = sortOrder
    }
}

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

    /// Detail-capture flags (still modeled the legacy way in Phase 1; collapsed in Phase 2).
    var detailType: String?
    var trackDetails: Bool = false
    var useMultipleStates: Bool = false
    var isNegativeHabit: Bool = false

    var collection: Collection?

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
        isNegativeHabit: Bool = false,
        collection: Collection? = nil
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
        self.collection = collection
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

// MARK: - JournalEntry

@Model
final class JournalEntry {
    // Re-creates the `byDateIndex` fetch index the original `.xcdatamodeld` had (bt-0004).
    #Index<JournalEntry>([\.date])

    var id: UUID?
    var date: Date?
    var content: String?
    var entryType: String? = "note"
    var isDraft: Bool = false
    var priority: Bool = false
    var originalDate: Date?

    /// Vestigial "future log / migration" fields — no live UI; removed in Phase 2 (pending #9 intent).
    var isFutureEntry: Bool = false
    var isSpecialEntry: Bool = false
    var hasMigrated: Bool = false
    var targetMonth: Date?
    var scheduledDate: Date?
    var specialEntryType: String?
    var taskStatus: String?

    var collection: Collection?

    @Relationship(deleteRule: .nullify, inverse: \Tag.entries)
    var tags: [Tag]?

    init(
        id: UUID? = UUID(),
        date: Date? = nil,
        content: String? = nil,
        entryType: String? = "note",
        isDraft: Bool = false,
        priority: Bool = false,
        originalDate: Date? = nil,
        isFutureEntry: Bool = false,
        isSpecialEntry: Bool = false,
        hasMigrated: Bool = false,
        targetMonth: Date? = nil,
        scheduledDate: Date? = nil,
        specialEntryType: String? = nil,
        taskStatus: String? = nil,
        collection: Collection? = nil
    ) {
        self.id = id
        self.date = date
        self.content = content
        self.entryType = entryType
        self.isDraft = isDraft
        self.priority = priority
        self.originalDate = originalDate
        self.isFutureEntry = isFutureEntry
        self.isSpecialEntry = isSpecialEntry
        self.hasMigrated = hasMigrated
        self.targetMonth = targetMonth
        self.scheduledDate = scheduledDate
        self.specialEntryType = specialEntryType
        self.taskStatus = taskStatus
        self.collection = collection
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

// MARK: - Tag

@Model
final class Tag {
    var id: UUID?
    var name: String?

    /// Other side of the many-to-many; the inverse is declared on `JournalEntry.tags`.
    var entries: [JournalEntry]?

    init(id: UUID? = UUID(), name: String? = nil) {
        self.id = id
        self.name = name
    }
}
