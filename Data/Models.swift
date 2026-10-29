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
    /// bt-0018 — a planned day off (Workout only, only when Dustin calls it).
    /// Neutral: not a win, not a miss; streaks carry through. Additive raw
    /// value — the older columns and values are untouched.
    case rest = 4
}

// MARK: - EntrySource (HabitEntry-level, bt-0018)
//
// Who wrote the entry. Stored as a raw `String?` on `HabitEntry` (additive,
// CloudKit-safe); `nil` = written before bt-0018 = treated as hand, so
// history is never re-graded. "Overrides win": the automatic grader only
// ever rewrites an entry it wrote itself.

enum EntrySource: String, Codable {
    case auto
    case hand
    case voice
}

// MARK: - GradingKind (Habit-level, bt-0018)
//
// Which rulebook (and which targets) a habit carries. Stored as a raw
// `String?` on `Habit`; `nil` = not graded automatically. Also the "kind" the
// app sends dustin-health in Step 3.

enum GradingKind: String, Codable, CaseIterable, Identifiable {
    case diet
    case workout

    var id: String { rawValue }
}

// MARK: - TargetKey (bt-0019)
//
// The five target keys dh and the app share (`lib/habits.js`
// `HABIT_TARGET_KEYS`). Each belongs to one grading kind, so a voice "set my
// protein target to 190" knows which habit to land on. Here rather than in
// `Sync/` because `Habit` reads and writes by it (below) and this file is in
// the widget target too.

enum TargetKey: String, CaseIterable, Sendable, Codable {
    case proteinMinGrams = "protein_min_g"
    case caloriesMin = "calories_min"
    case caloriesMax = "calories_max"
    case workoutMinutesMin = "workout_minutes_min"
    case stepsMin = "steps_min"
    /// bt-0022 — carbs / fat ceilings in grams (dh `b7d3b5c`). They colour
    /// the Dashboard rings only; `DietGrade` never reads them.
    case carbsMaxGrams = "carbs_g"
    case fatMaxGrams = "fat_g"

    var gradingKind: GradingKind {
        switch self {
        case .proteinMinGrams, .caloriesMin, .caloriesMax, .carbsMaxGrams, .fatMaxGrams: return .diet
        case .workoutMinutesMin, .stepsMin: return .workout
        }
    }

    var title: String {
        switch self {
        case .proteinMinGrams: return "protein target"
        case .caloriesMin: return "calorie floor"
        case .caloriesMax: return "calorie ceiling"
        case .workoutMinutesMin: return "workout minutes"
        case .stepsMin: return "steps target"
        case .carbsMaxGrams: return "carbs ceiling"
        case .fatMaxGrams: return "fat ceiling"
        }
    }
}

// MARK: - Win Rule (bt-0014; moved here in bt-0011 so the widget shares it)
//
// The ONE definition of "this tracked day counts" — used by the Today header,
// streaks, completion rates, the heatmap, the PDF summary and the widget.
// Before this, every site checked "an entry exists with state ≠ notDone",
// which for an avoidance habit means *you slipped*, so slipping counted as
// completing.
//
//   simple      → checked
//   multiState  → success or partial ("Tried" is an honest miss, not a win);
//                 a Rest day is neutral — see `isNeutral` (bt-0018)
//   avoidance   → never a win (bt-0024). An avoidance habit is scored by its
//                 slips, not its clean days: a clean day is nothing (empty
//                 square, no streak), a slip is a mark, and the rate shown
//                 beside a good habit's done rate is the *slip rate* — slip
//                 days over scored days, lower is better. Before bt-0024 a
//                 day with no row was a win, which after the bt-0022 wipe
//                 read as a 365-day Weed streak.

enum HabitWinRule {
    static func isWin(style: CompletionStyle, state: CompletionState?, isFuture: Bool) -> Bool {
        switch style {
        case .simple:
            return state != nil && state != .notDone
        case .multiState:
            return state == .success || state == .partial
        case .avoidance:
            return false
        }
    }

    /// bt-0024 — the one switch: this style is scored by slips (avoidance),
    /// so it has no wins, no streaks, and its rate is a slip rate.
    static func isSlipScored(style: CompletionStyle) -> Bool {
        style == .avoidance
    }

    /// bt-0024 — a slip: an avoidance habit with anything logged that day
    /// (`.failure` from a tap; legacy rows stored `.success`, still a slip).
    static func isSlip(style: CompletionStyle, state: CompletionState?) -> Bool {
        isSlipScored(style: style) && isLogged(state: state)
    }

    /// bt-0018 — a day that counts as neither win nor miss. Streaks skip it
    /// the way they skip an unscheduled day; rates and the heatmap drop it
    /// from both sides of the fraction; the day summary leaves the habit out.
    static func isNeutral(state: CompletionState?) -> Bool {
        state == .rest
    }

    /// Whether the entry (or its absence) means the person *logged* something
    /// that day — a check, a partial, a miss, a slip, or a rest day. Drives
    /// row visuals, not scores.
    static func isLogged(state: CompletionState?) -> Bool {
        state != nil && state != .notDone
    }
}

// MARK: - Day Summary (bt-0014; wording shared with the widget since bt-0024)
//
// Positive habits (simple + multi-state) and avoidance habits are different
// kinds of thing, so the header never folds them into one number:
// "5 of 8 done" / "All 8 done" / "5 of 8 done · 1 slip". A clean avoidance
// day adds nothing (bt-0024 — the old "· 3 clean" tail is gone). Rest days
// are left out of "N of M".

struct DaySummary: Equatable {
    let positiveDone: Int
    let positiveTotal: Int
    let avoidanceTotal: Int
    let slips: Int

    /// The Today subtitle and the widget header, one wording.
    /// `emptyText` is what to say when nothing is scheduled at all.
    func text(emptyText: String) -> String {
        if positiveTotal == 0 && avoidanceTotal == 0 { return emptyText }
        var parts: [String] = []
        if positiveTotal > 0 {
            parts.append(positiveDone == positiveTotal
                         ? "All \(positiveTotal) done"
                         : "\(positiveDone) of \(positiveTotal) done")
        }
        if slips > 0 {
            parts.append("\(slips) slip\(slips == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - HabitEntryDetails (HabitEntry payload)
//
// Replaces the old `details: String` JSON blob on `HabitEntry`. Discriminated
// by `Habit.detailKind` — every site that used to hand-parse `json["duration"]`
// now reads `entry.details?.workout?.duration` (or pattern-matches the enum).
// SwiftData persists this as a transformable attribute under the hood; the
// `BackupManager` round-trip in Wave 3 transforms old `details: String` JSON
// into this typed shape on import.

enum HabitEntryDetails: Codable, Equatable {
    /// Used when `habit.detailKind == .notes`.
    case notes(notes: String)
    /// Used when `habit.detailKind == .workout`.
    case workout(types: [String], duration: String, intensity: Int, notes: String)
    /// Used when `habit.detailKind == .reading`.
    case reading(bookTitle: String, pagesRead: String, notes: String)
    /// Used when `habit.detailKind == .mood`.
    case mood(mood: Int, notes: String)
}

// MARK: - Workout type chips (bt-0021)
//
// The six buckets the Log Details form offers. One list, shared by the form
// and the sync, which lights a chip from the category dustin-health reports
// for a session. Not Apple's activity types: dh keeps those but only sends
// the category, so the finer chips (Functional, Core/Pre-Hab, HIIT/Jump)
// are Dustin's to add by hand.

enum WorkoutTypeChips {
    static let all = ["Cardio", "Strength", "Functional", "Core/Pre-Hab", "HIIT/Jump", "Other"]

    /// dh's `activity_category` → a chip. Walking, running, cycling,
    /// swimming, hockey and any team sport (dh names the sport) are Cardio;
    /// strength is Strength; "other" is Other. Unknown → no chip.
    static func chip(forCategory category: String?) -> String? {
        guard let category = category?.lowercased(), !category.isEmpty else { return nil }
        switch category {
        case "strength": return "Strength"
        case "other": return "Other"
        default: return "Cardio"
        }
    }
}

// MARK: - HealthSnapshot (bt-0021)
//
// What dustin-health reported for one habit-day: the workout sessions (on a
// Workout row) or the meals (on a Diet row). Stored under its own `health`
// key inside `HabitEntry.detailsJSON`, beside the details keys and never
// inside them, so a note (hand or voice) and this list can't wipe each
// other, and a build that doesn't know the key reads the row as before.
// Written only by the sync (`HabitStore.setHealth`), only when it changed.

struct HealthSnapshot: Codable, Equatable, Sendable {
    struct Session: Codable, Equatable, Sendable {
        var name: String
        var category: String?
        var minutes: Double
        var sets: Int
        var start: Date?
        /// bt-0022 — Watch active calories over the session's linked records;
        /// `nil` = dh doesn't know (a dash, never 0).
        var activeKcal: Double? = nil
        /// bt-0022 — Apple's activity name on the primary Watch record
        /// ("Indoor Run", "Running", "Hockey"). Names differ by source, so
        /// anything that lights a chip from this maps by name, never exactly.
        var activityType: String? = nil
    }

    struct Meal: Codable, Equatable, Sendable {
        var id: String?
        var name: String
        /// `nil` = dh doesn't know (shown as a dash), never 0.
        var calories: Double?
        var protein: Double?
        var carbs: Double?
        var fat: Double?
        var at: Date?
    }

    var sessions: [Session] = []
    var meals: [Meal] = []
    /// bt-0022 — the day's step count from Apple Health, stored on the
    /// Workout row by the sync so the Dashboard (and the iPad, which has no
    /// HealthKit) can show it. `nil` = not read that run. A missing key in
    /// an older stored row decodes as `nil`.
    var steps: Int? = nil
    /// bt-0023 — the day's calories burned from Apple Health (Active Energy
    /// and Resting Energy, kcal), stored on the Workout row beside the steps.
    /// **The daily burn is Health's total and nothing else**: dh's per-session
    /// `activeKcal` is already inside it and is never added on top. `nil` =
    /// Health had no reading (a dash, never 0); a missing key decodes as `nil`.
    var activeBurnKcal: Double? = nil
    var restingBurnKcal: Double? = nil

    var isEmpty: Bool {
        sessions.isEmpty && meals.isEmpty && steps == nil && activeBurnKcal == nil && restingBurnKcal == nil
    }

    /// Active + resting from Health; `nil` when neither is known.
    var totalBurnKcal: Double? { Self.sum([activeBurnKcal, restingBurnKcal]) }

    var totalMinutes: Double { sessions.reduce(0) { $0 + $1.minutes } }
    /// The sessions' own active calories added up — for the per-session rows
    /// and the sessions-over-Health check only (bt-0023), never the day's burn.
    var totalActiveKcal: Double? { Self.sum(sessions.map(\.activeKcal)) }
    var totalCalories: Double? { Self.sum(meals.map(\.calories)) }
    var totalProtein: Double? { Self.sum(meals.map(\.protein)) }
    var totalCarbs: Double? { Self.sum(meals.map(\.carbs)) }
    var totalFat: Double? { Self.sum(meals.map(\.fat)) }

    /// Sum of the known values; `nil` when none is known (dh's SQL `sum`
    /// skips nulls the same way).
    private static func sum(_ values: [Double?]) -> Double? {
        let known = values.compactMap { $0 }
        return known.isEmpty ? nil : known.reduce(0, +)
    }

    /// Whole-second dates, so a snapshot survives the JSON round trip
    /// unchanged and the "write only when changed" check holds.
    static func wholeSecond(_ date: Date?) -> Date? {
        date.map { Date(timeIntervalSince1970: $0.timeIntervalSince1970.rounded(.down)) }
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

    /// Completion style — replaces `useMultipleStates: Bool` + `isNegativeHabit: Bool`
    /// pair (Call B (c) collapse, Wave 2). The `@Model` macro requires the
    /// default value to be fully qualified (`.simple` shorthand rejected).
    var completionStyle: CompletionStyle = CompletionStyle.simple

    /// Detail-capture kind — replaces `trackDetails: Bool` + `detailType: String?`
    /// pair (Call B (c) collapse, Wave 2). `nil` = no detail capture.
    var detailKind: DetailKind?

    // MARK: bt-0018 — automatic grading (all additive, all optional)
    //
    // Raw storage below; typed access through the extension at the bottom of
    // this file. `nil` everywhere = the habit is not graded automatically and
    // the built-in targets apply, so no existing row needs migrating.

    /// `GradingKind.rawValue` — "diet" / "workout"; `nil` = off.
    var gradingKindRaw: String?
    /// Go-live day (start of day). Automatic grades and "Back to Automatic"
    /// apply from this day forward only; days before it are never touched.
    var gradingSince: Date?
    /// Targets. `nil` = built-in default (`GradingTargets.defaults`).
    var targetProteinGrams: Double?
    var targetCalorieLow: Double?
    var targetCalorieHigh: Double?
    var targetWorkoutMinutes: Double?
    var targetSteps: Double?
    /// bt-0022 — carbs / fat ceilings (grams) for the Dashboard rings. Sent
    /// to dh like the five above; not part of any grade. Additive, optional.
    var targetCarbsGrams: Double?
    var targetFatGrams: Double?

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

    /// Pass-through accessor (`bt-0007` first attempt — made this field
    /// optional + nil-coalesced here to absorb null values arriving from
    /// CloudKit. The change wasn't a SwiftData lightweight migration against
    /// the live CloudKit-synced schema: SwiftData wrapped the optional in a
    /// `NSCompositeAttributeDescription` while CloudKit's container schema
    /// kept `CD_completionState` as `INT64` — mismatch broke sync entirely
    /// with "Unknown value class" errors. Reverted; accessor kept as a no-op
    /// so the 13 read-site renames don't have to revert with it. Full failure
    /// log in `bt-0007`.)
    var effectiveCompletionState: CompletionState { completionState }

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
            // bt-0021 — the `health` key rides along untouched: a Done in
            // Log Details or a voice note can never drop dh's list.
            var object = Self.healthOnly(from: detailsJSON)
            if let newValue {
                object.merge(Self.detailsDictionary(newValue)) { _, new in new }
            }
            detailsJSON = object.isEmpty ? nil : Self.string(from: object)
        }
    }

    /// bt-0021 — dh's sessions (Workout row) or meals (Diet row) for this
    /// day, under the `health` key of the same string. Written only by the
    /// sync through `HabitStore.setHealth`; every other write leaves it be.
    var health: HealthSnapshot? {
        get {
            guard let object = Self.healthObject(in: detailsJSON) else { return nil }
            return Self.decodeHealth(object)
        }
        set {
            var object = Self.jsonObject(from: detailsJSON)
            if let encoded = newValue.flatMap(Self.encodeHealth) {
                object[Self.healthKey] = encoded
            } else {
                object.removeValue(forKey: Self.healthKey)
            }
            detailsJSON = object.isEmpty ? nil : Self.string(from: object)
        }
    }

    var habit: Habit?

    // MARK: bt-0018 — who wrote this row, and when (additive, optional)

    /// `EntrySource.rawValue`. `nil` = written before bt-0018 → hand.
    var sourceRaw: String?
    /// Last write through `HabitStore`. `nil` on rows from before bt-0018.
    var editedAt: Date?

    init(
        id: UUID? = UUID(),
        date: Date,
        completionState: CompletionState = .notDone,
        details: HabitEntryDetails? = nil,
        habit: Habit? = nil,
        source: EntrySource? = nil,
        editedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.completionState = completionState
        self.detailsJSON = details.flatMap { Self.string(from: Self.detailsDictionary($0)) }
        self.habit = habit
        self.sourceRaw = source?.rawValue
        self.editedAt = editedAt
    }

    /// Typed source. A row with no marker is a hand row: it predates the
    /// grader, and history is never re-graded.
    var source: EntrySource {
        get { sourceRaw.flatMap(EntrySource.init(rawValue:)) ?? .hand }
        set { sourceRaw = newValue.rawValue }
    }

    /// True for rows the automatic grader may rewrite or remove.
    var isAutomatic: Bool { source == .auto }

    /// bt-0021 — a hand / voice row that carries a grade: the only kind that
    /// wins over the automatic one. A `notDone` hand row holds details only
    /// (notes typed before the day was marked) and never blocks the grader.
    var isOverride: Bool { !isAutomatic && effectiveCompletionState != .notDone }

    // MARK: - HabitEntryDetails ⇄ JSON-string conversion
    //
    // Same wire shape `BackupManager` (and the pre-Phase-2 `details: String`
    // column) used — workout/reading/mood have their own field names; `notes`
    // is the universal shared field. Discriminate on read by which JSON keys
    // are present (the four kinds don't share keys, so it's unambiguous).

    private static let healthKey = "health"

    /// The details keys as a dictionary (the legacy wire shape).
    private static func detailsDictionary(_ d: HabitEntryDetails) -> [String: Any] {
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
        return dict
    }

    /// The stored string as a dictionary. Non-JSON legacy plaintext is a
    /// notes line; nothing stored → empty.
    private static func jsonObject(from raw: String?) -> [String: Any] {
        guard let raw, !raw.isEmpty else { return [:] }
        guard let data = raw.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["notes": raw]
        }
        return dict
    }

    private static func healthObject(in raw: String?) -> Any? {
        jsonObject(from: raw)[healthKey]
    }

    /// Just the `health` key (if any), for the `details` setter to build on.
    private static func healthOnly(from raw: String?) -> [String: Any] {
        guard let health = healthObject(in: raw) else { return [:] }
        return [healthKey: health]
    }

    /// Sorted keys, so the same content is always the same string.
    private static func string(from object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private static func encodeHealth(_ snapshot: HealthSnapshot) -> Any? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private static func decodeHealth(_ object: Any) -> HealthSnapshot? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(HealthSnapshot.self, from: data)
    }

    private static func decodeDetails(_ str: String) -> HabitEntryDetails? {
        let dict = jsonObject(from: str)
        let notes = dict["notes"] as? String
        if let types = dict["types"] as? [String] {
            let duration = dict["duration"] as? String ?? ""
            let intensity = dict["intensity"] as? Int ?? 3
            return .workout(types: types, duration: duration, intensity: intensity, notes: notes ?? "")
        }
        if dict["bookTitle"] != nil || dict["pagesRead"] != nil {
            let bookTitle = dict["bookTitle"] as? String ?? ""
            let pagesRead = dict["pagesRead"] as? String ?? ""
            return .reading(bookTitle: bookTitle, pagesRead: pagesRead, notes: notes ?? "")
        }
        if let mood = dict["mood"] as? Int {
            return .mood(mood: mood, notes: notes ?? "")
        }
        // bt-0021 — a row holding only the `health` key has no details.
        guard let notes else { return nil }
        return .notes(notes: notes)
    }
}

// MARK: - Grading targets (bt-0018)
//
// The numbers the Diet / Workout rules compare against. A plain value built
// from a habit (blank field → built-in default) so the grading functions in
// `Sync/HabitGrading.swift` stay pure and the widget target can read a
// habit's kind without importing anything else.

struct GradingTargets: Equatable, Sendable {
    var proteinFloorGrams: Double
    /// The floor is Dustin's ("yes keep 1900"): undereating is a miss.
    var calorieFloor: Double
    var calorieCeiling: Double
    var workoutMinutes: Double
    var steps: Double
    /// bt-0022 — ring ceilings only (the dh website's fixed 180 / 65).
    /// Defaulted here so existing call sites don't name them.
    var carbsCeilingGrams: Double = 180
    var fatCeilingGrams: Double = 65

    static let defaults = GradingTargets(
        proteinFloorGrams: 180,
        calorieFloor: 1900,
        calorieCeiling: 2200,
        workoutMinutes: 30,
        steps: 10_000,
        carbsCeilingGrams: 180,
        fatCeilingGrams: 65
    )
}

extension Habit {
    /// Which rulebook this habit is graded by; `nil` = not graded.
    var gradingKind: GradingKind? {
        get { gradingKindRaw.flatMap(GradingKind.init(rawValue:)) }
        set { gradingKindRaw = newValue?.rawValue }
    }

    /// True once grading has been switched on (go-live day stamped).
    var isAutoGraded: Bool { gradingKind != nil && gradingSince != nil }

    /// Whether `day` is on or after the go-live day. False when grading is
    /// off. Automatic grades and "Back to Automatic" only exist on such days.
    func isWithinGrading(_ day: Date, calendar: Calendar = .current) -> Bool {
        guard gradingKind != nil, let since = gradingSince else { return false }
        return calendar.startOfDay(for: day) >= calendar.startOfDay(for: since)
    }

    /// Whether Rest may be set on this habit (Workout only, by design).
    var offersRest: Bool { gradingKind == .workout }

    /// bt-0019 — the wire targets, read from and written to the optional
    /// columns. `nil` = blank = built-in default. (Seven since bt-0022.)
    func target(for key: TargetKey) -> Double? {
        switch key {
        case .proteinMinGrams: return targetProteinGrams
        case .caloriesMin: return targetCalorieLow
        case .caloriesMax: return targetCalorieHigh
        case .workoutMinutesMin: return targetWorkoutMinutes
        case .stepsMin: return targetSteps
        case .carbsMaxGrams: return targetCarbsGrams
        case .fatMaxGrams: return targetFatGrams
        }
    }

    func setTarget(_ key: TargetKey, to value: Double?) {
        switch key {
        case .proteinMinGrams: targetProteinGrams = value
        case .caloriesMin: targetCalorieLow = value
        case .caloriesMax: targetCalorieHigh = value
        case .workoutMinutesMin: targetWorkoutMinutes = value
        case .stepsMin: targetSteps = value
        case .carbsMaxGrams: targetCarbsGrams = value
        case .fatMaxGrams: targetFatGrams = value
        }
    }

    /// The habit's targets with blanks filled from the defaults.
    var gradingTargets: GradingTargets {
        let d = GradingTargets.defaults
        return GradingTargets(
            proteinFloorGrams: targetProteinGrams ?? d.proteinFloorGrams,
            calorieFloor: targetCalorieLow ?? d.calorieFloor,
            calorieCeiling: targetCalorieHigh ?? d.calorieCeiling,
            workoutMinutes: targetWorkoutMinutes ?? d.workoutMinutes,
            steps: targetSteps ?? d.steps,
            carbsCeilingGrams: targetCarbsGrams ?? d.carbsCeilingGrams,
            fatCeilingGrams: targetFatGrams ?? d.fatCeilingGrams
        )
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

