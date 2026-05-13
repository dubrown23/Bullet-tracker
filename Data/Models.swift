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

// MARK: - CompletionStyle (Habit-level)
//
// Replaces the old `useMultipleStates: Bool` + `isNegativeHabit: Bool` pair
// on `Habit`. Pure data here; the SwiftUI affordances (`title`, `description`,
// `icon`, `iconColor`) live as an extension in `Habits/HabitFormView.swift`
// so this file stays free of SwiftUI imports.

enum CompletionStyle: String, Codable, CaseIterable, Identifiable {
    case simple
    case multiState
    case avoidance

    var id: String { rawValue }
}

// MARK: - DetailKind (Habit-level)
//
// Replaces the old `trackDetails: Bool` + `detailType: String?` pair on
// `Habit`. `nil` = no detail capture; otherwise specifies which kind.
// Pairs with `HabitEntryDetails` below — the entry's payload type is
// determined by the habit's `detailKind`.

enum DetailKind: String, Codable, CaseIterable, Identifiable {
    case notes
    case workout
    case reading
    case mood

    var id: String { rawValue }
}

// MARK: - CompletionState (HabitEntry-level)
//
// Replaces the old `completed: Bool` + `completionState: Int16` pair on
// `HabitEntry`. Interpreted in the context of `Habit.completionStyle`:
//   .simple     → `.notDone` or `.success`
//   .multiState → any of the four cases
//   .avoidance  → `.notDone` (didn't slip) or `.failure` (slipped)
//
// Backed by `Int16` so the persisted shape on disk matches the old
// `completionState: Int16` raw column — keeps the backup-restore transform
// trivial (raw value 0/1/2/3 maps 1:1 to the enum).

enum CompletionState: Int16, Codable {
    case notDone = 0
    case success = 1
    case partial = 2
    case failure = 3
}

// MARK: - HabitEntryDetails (HabitEntry payload)
//
// Replaces the old `details: String` JSON blob on `HabitEntry`. Discriminated
// by `Habit.detailKind` — every site that used to hand-parse `json["duration"]`
// now reads `entry.details?.workout?.duration` (or pattern-matches the enum).
// SwiftData persists this as a transformable attribute under the hood; the
// `BackupManager` round-trip in Wave 3 transforms old `details: String` JSON
// into this typed shape on import.

enum HabitEntryDetails: Codable {
    /// Used when `habit.detailKind == .notes`.
    case notes(notes: String)
    /// Used when `habit.detailKind == .workout`.
    case workout(types: [String], duration: String, intensity: Int, notes: String)
    /// Used when `habit.detailKind == .reading`.
    case reading(bookTitle: String, pagesRead: String, notes: String)
    /// Used when `habit.detailKind == .mood`.
    case mood(mood: Int, notes: String)
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

    /// Completion style — replaces `useMultipleStates: Bool` + `isNegativeHabit: Bool`
    /// pair (Call B (c) collapse, Wave 2). The `@Model` macro requires the
    /// default value to be fully qualified (`.simple` shorthand rejected).
    var completionStyle: CompletionStyle = CompletionStyle.simple

    /// Detail-capture kind — replaces `trackDetails: Bool` + `detailType: String?`
    /// pair (Call B (c) collapse, Wave 2). `nil` = no detail capture.
    var detailKind: DetailKind?

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
        completionStyle: CompletionStyle = .simple,
        detailKind: DetailKind? = nil
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
        self.completionStyle = completionStyle
        self.detailKind = detailKind
    }
}

// MARK: - HabitEntry

@Model
final class HabitEntry {
    // Re-creates the `byDateIndex` fetch index the original `.xcdatamodeld` had.
    // Cheap to write, big read-time win for date-bounded queries (bt-0004).
    #Index<HabitEntry>([\.date])

    var id: UUID?

    /// Wave 2 — non-optional. `bt-0004` proved SwiftData's `#Predicate` rejects
    /// every shape of optional-Date comparison on this iOS version; making the
    /// field non-optional is the structural fix and unblocks the Wave 4 hot-path
    /// predicate rewrites. `Date.distantPast` is the syntactic-required default
    /// — every call site must pass an explicit date, so it should never appear
    /// in real data; flag-up sentinel if it ever does. (Fully qualified per the
    /// `@Model` macro's requirement.)
    var date: Date = Date.distantPast

    /// Completion state — replaces `completed: Bool` + `completionState: Int16`
    /// pair (Call B (c) entry-side collapse, Wave 2). Backed by `Int16` so the
    /// persisted shape matches the old raw column; backup-restore transform
    /// reads the old `completionState: Int` → `CompletionState(rawValue:)`.
    /// (Fully qualified per the `@Model` macro's requirement.)
    var completionState: CompletionState = CompletionState.notDone

    /// Structured details — typed shape replaces the old `details: String` JSON
    /// blob (Call A (a) typed-shape decision, Wave 2). Nil = no details captured
    /// (e.g., `habit.detailKind == nil` OR no payload for this entry yet).
    var details: HabitEntryDetails?

    var habit: Habit?

    init(
        id: UUID? = UUID(),
        date: Date,
        completionState: CompletionState = .notDone,
        details: HabitEntryDetails? = nil,
        habit: Habit? = nil
    ) {
        self.id = id
        self.date = date
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

