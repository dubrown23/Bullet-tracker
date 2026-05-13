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

    /// Stored JSON-string representation of the details payload. The typed
    /// `details: HabitEntryDetails?` accessor below reads/writes this column.
    ///
    /// **Why a `String` and not the typed enum directly?** bt-0004-class
    /// SwiftData failure: storing a `Codable` enum with associated values as a
    /// SwiftData attribute persists *something* on write but on read the
    /// decoder fails with `Could not cast value of type Optional<Any> to
    /// Array<String>` (verified at Wave 3 device test, 2026-05-13). The legacy
    /// JSON-string shape is what every pre-Phase-2 entry on the live store
    /// already used, and `BackupManager`'s wire format also speaks it — so
    /// storing the JSON string here keeps the storage path battle-tested and
    /// lets the typed access live in the computed accessor.
    ///
    /// Private to the class; nothing outside should read/write this directly.
    var detailsJSON: String?

    /// Typed access to the details payload. Reads decode the stored JSON
    /// string lazily on each access (negligible cost — a few µs per entry,
    /// invoked only on the small surfaces that actually render details).
    /// Writes encode the typed value to the legacy JSON shape and store it
    /// via `detailsJSON`. `nil` = no details captured.
    var details: HabitEntryDetails? {
        get {
            guard let raw = detailsJSON, !raw.isEmpty else { return nil }
            return Self.decodeDetails(raw)
        }
        set {
            detailsJSON = newValue.flatMap { Self.encodeDetails($0) }
        }
    }

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
        self.detailsJSON = details.flatMap { Self.encodeDetails($0) }
        self.habit = habit
    }

    // MARK: - HabitEntryDetails ⇄ JSON-string conversion
    //
    // Same wire shape `BackupManager` (and the pre-Phase-2 `details: String`
    // column) used — workout/reading/mood have their own field names; `notes`
    // is the universal shared field. Discriminate on read by which JSON keys
    // are present (the four kinds don't share keys, so it's unambiguous).

    private static func encodeDetails(_ d: HabitEntryDetails) -> String? {
        var dict: [String: Any] = [:]
        switch d {
        case .notes(let n):
            dict["notes"] = n
        case .workout(let types, let duration, let intensity, let n):
            dict["types"] = types
            dict["type"] = types.first ?? ""
            dict["duration"] = duration
            dict["intensity"] = intensity
            dict["notes"] = n
        case .reading(let bookTitle, let pagesRead, let n):
            dict["bookTitle"] = bookTitle
            dict["pagesRead"] = pagesRead
            dict["notes"] = n
        case .mood(let mood, let n):
            dict["mood"] = mood
            dict["notes"] = n
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private static func decodeDetails(_ str: String) -> HabitEntryDetails? {
        guard let data = str.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Non-JSON legacy plaintext — treat the whole string as notes.
            return .notes(notes: str)
        }
        let notes = dict["notes"] as? String ?? ""
        if let types = dict["types"] as? [String] {
            let duration = dict["duration"] as? String ?? ""
            let intensity = dict["intensity"] as? Int ?? 3
            return .workout(types: types, duration: duration, intensity: intensity, notes: notes)
        }
        if dict["bookTitle"] != nil || dict["pagesRead"] != nil {
            let bookTitle = dict["bookTitle"] as? String ?? ""
            let pagesRead = dict["pagesRead"] as? String ?? ""
            return .reading(bookTitle: bookTitle, pagesRead: pagesRead, notes: notes)
        }
        if let mood = dict["mood"] as? Int {
            return .mood(mood: mood, notes: notes)
        }
        return .notes(notes: notes)
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

