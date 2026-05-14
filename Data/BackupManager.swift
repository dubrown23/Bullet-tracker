//
//  BackupManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/15/25.
//
//  SwiftData migration (bt-0002): the JSON backup *file format* is unchanged — the
//  `Codable` mirror structs below are byte-for-byte the same, so old backups still
//  restore and new backups still open in any tool that read the old ones. Only the
//  fetch/insert plumbing moved from Core Data to a passed-in `ModelContext`.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Backup Manager

class BackupManager {
    // MARK: - Singleton

    static let shared = BackupManager()
    private init() {}

    // MARK: - Properties

    /// Error message for the last operation
    var errorMessage: String?

    /// Current backup file version - increment when changing format
    let backupVersion = 1

    // MARK: - Backup Creation

    /// Creates a backup of all app data and returns the file URL.
    func createBackup(in context: ModelContext) -> URL? {
        errorMessage = nil

        updateBackupProgress(0.1)

        let backupData = prepareBackupData(in: context)
        updateBackupProgress(0.7)

        guard let jsonData = try? JSONEncoder().encode(backupData) else {
            errorMessage = "Failed to encode backup data"
            return nil
        }

        updateBackupProgress(0.8)

        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileName = "BulletTracker_Backup_\(formattedDate()).json"
        let fileURL = temporaryDirectory.appendingPathComponent(fileName)

        do {
            try jsonData.write(to: fileURL)
            updateBackupProgress(1.0)
            return fileURL
        } catch {
            errorMessage = "Failed to write backup file: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Restore Functions

    /// Restores app data from a backup file at the given URL.
    func restoreFromURL(_ url: URL, in context: ModelContext) -> Bool {
        errorMessage = nil
        updateRestoreProgress(0.1)

        let tempDirectory = FileManager.default.temporaryDirectory
        let localURL = tempDirectory.appendingPathComponent("backup_for_restore.json")

        do {
            try prepareLocalCopy(from: url, to: localURL)

            let jsonData = try Data(contentsOf: localURL)
            let backupData = try JSONDecoder().decode(BackupData.self, from: jsonData)

            updateRestoreProgress(0.3)

            guard validateBackupVersion(backupData.version) else { return false }

            updateRestoreProgress(0.4)

            clearExistingData(in: context)
            updateRestoreProgress(0.5)

            let success = importBackupData(backupData, in: context)
            updateRestoreProgress(1.0)

            return success

        } catch is DecodingError {
            errorMessage = "The backup file is not in the correct format"
            return false
        } catch {
            errorMessage = "Could not read the backup file"
            return false
        }
    }

    // MARK: - Private Methods - Backup Preparation

    private func prepareBackupData(in context: ModelContext) -> BackupData {
        updateBackupProgress(0.2)

        let habits = fetchHabits(in: context)
        updateBackupProgress(0.4)

        let habitEntries = fetchHabitEntries(in: context)
        updateBackupProgress(0.6)

        let notes = fetchNotes(in: context)
        updateBackupProgress(0.7)

        return BackupData(
            version: backupVersion,
            createdAt: Date(),
            habits: habits,
            habitEntries: habitEntries,
            notes: notes
        )
    }

    // MARK: - Private Methods - Data Fetching

    // The JSON backup wire format is unchanged across the Phase 2 model
    // restructure (bt-0003 Wave 3 design call). HabitData / HabitEntryData
    // still carry the legacy field names (`useMultipleStates` / `isNegativeHabit`
    // / `trackDetails` / `detailType` on habits; `completed` / `completionState: Int`
    // / `details: String` on entries) so:
    //   • Old backups round-trip into the new model on restore (forward compat)
    //   • New backups are still readable by pre-Phase-2 app versions (backward compat)
    // The typed-model ↔ legacy-wire transform happens at the fetch/import boundary
    // below.

    private func fetchHabits(in context: ModelContext) -> [HabitData] {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []

        return habits.map { habit in
            // Derive legacy bool/string fields from the typed `completionStyle` + `detailKind`.
            let style = habit.completionStyle
            let kind = habit.detailKind
            let useMultipleStates = (style == .multiState)
            let isNegativeHabit = (style == .avoidance)
            let trackDetails = (kind != nil)
            let detailType: String = {
                switch kind {
                case .none, .notes: return "general"
                case .workout?: return "workout"
                case .reading?: return "reading"
                case .mood?: return "mood"
                }
            }()

            return HabitData(
                id: habit.id?.uuidString ?? UUID().uuidString,
                name: habit.name ?? "",
                icon: habit.icon ?? "circle.fill",
                color: habit.color ?? "#007AFF",
                frequency: habit.frequency ?? HabitFrequency.daily.rawValue,
                customDays: habit.customDays ?? "",
                startDate: habit.startDate ?? Date(),
                notes: habit.notes ?? "",
                order: Int(habit.order),
                trackDetails: trackDetails,
                detailType: detailType,
                useMultipleStates: useMultipleStates,
                isNegativeHabit: isNegativeHabit
            )
        }
    }

    private func fetchHabitEntries(in context: ModelContext) -> [HabitEntryData] {
        let entries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []

        return entries.map { entry in
            // Convert typed `details: HabitEntryDetails?` back to a JSON string
            // (matches the pre-Phase-2 wire shape every old backup uses).
            let detailsJSONString = entry.details.flatMap { jsonifyDetails($0) } ?? ""

            return HabitEntryData(
                id: entry.id?.uuidString ?? UUID().uuidString,
                date: entry.date,
                completed: entry.completionState != .notDone,
                details: detailsJSONString,
                habitID: entry.habit?.id?.uuidString ?? "",
                completionState: Int(entry.completionState.rawValue)
            )
        }
    }

    /// Convert a typed `HabitEntryDetails` to the legacy JSON string format
    /// (the same shape pre-Phase-2 backups carried — workout/reading/mood
    /// have their own field names; `notes` is the universal shared field).
    private func jsonifyDetails(_ details: HabitEntryDetails) -> String? {
        var dict: [String: Any] = [:]
        switch details {
        case .notes(let notes):
            dict["notes"] = notes
        case .workout(let types, let duration, let intensity, let notes):
            dict["types"] = types
            dict["type"] = types.first ?? ""
            dict["duration"] = duration
            dict["intensity"] = intensity
            dict["notes"] = notes
        case .reading(let bookTitle, let pagesRead, let notes):
            dict["bookTitle"] = bookTitle
            dict["pagesRead"] = pagesRead
            dict["notes"] = notes
        case .mood(let mood, let notes):
            dict["mood"] = mood
            dict["notes"] = notes
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func fetchNotes(in context: ModelContext) -> [NoteData] {
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []

        return notes.map { note in
            NoteData(
                id: note.id?.uuidString ?? UUID().uuidString,
                content: note.content ?? "",
                date: note.date ?? Date()
            )
        }
    }

    // MARK: - Private Methods - Restore Operations

    private func prepareLocalCopy(from sourceURL: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func validateBackupVersion(_ version: Int) -> Bool {
        if version > backupVersion {
            errorMessage = "This backup was created with a newer version of the app"
            return false
        }
        return true
    }

    private func clearExistingData(in context: ModelContext) {
        try? context.delete(model: HabitEntry.self)
        try? context.delete(model: Note.self)
        try? context.delete(model: Habit.self)
        try? context.save()
    }

    private func importBackupData(_ backupData: BackupData, in context: ModelContext) -> Bool {
        updateRestoreProgress(0.7)
        let habitMap = importHabits(from: backupData.habits, in: context)

        updateRestoreProgress(0.85)
        importHabitEntries(from: backupData.habitEntries, habitMap: habitMap, in: context)

        updateRestoreProgress(0.92)
        if let notes = backupData.notes {
            importNotes(from: notes, in: context)
        }

        do {
            try context.save()
            updateRestoreProgress(0.95)
            return true
        } catch {
            errorMessage = "Failed to restore backup: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Private Methods - Entity Import

    private func importHabits(from backupHabits: [HabitData], in context: ModelContext) -> [String: Habit] {
        var habitMap: [String: Habit] = [:]

        for habitData in backupHabits {
            // Derive typed `completionStyle` + `detailKind` from the legacy
            // bool/string fields on the wire format.
            let completionStyle: CompletionStyle = {
                if habitData.isNegativeHabit { return .avoidance }
                if habitData.useMultipleStates { return .multiState }
                return .simple
            }()
            let detailKind: DetailKind? = {
                guard habitData.trackDetails else { return nil }
                switch habitData.detailType {
                case "workout": return .workout
                case "reading": return .reading
                case "mood": return .mood
                default: return .notes  // "general" or unknown → .notes
                }
            }()

            let habit = Habit(
                id: UUID(uuidString: habitData.id),
                name: habitData.name,
                color: habitData.color,
                icon: habitData.icon,
                frequency: habitData.frequency,
                customDays: habitData.customDays,
                notes: habitData.notes,
                startDate: habitData.startDate,
                order: Int32(habitData.order),
                completionStyle: completionStyle,
                detailKind: detailKind
            )
            context.insert(habit)
            habitMap[habitData.id] = habit
        }

        return habitMap
    }

    private func importHabitEntries(from backupEntries: [HabitEntryData], habitMap: [String: Habit], in context: ModelContext) {
        for entryData in backupEntries {
            guard let habit = habitMap[entryData.habitID] else { continue }

            // Map legacy Int completionState → typed CompletionState.
            // If raw value is out of range, fall back to `.success` for entries
            // whose legacy `completed` was true; else `.notDone`.
            let typedState: CompletionState = {
                if let s = CompletionState(rawValue: Int16(entryData.completionState)) { return s }
                return entryData.completed ? .success : .notDone
            }()

            // Parse the legacy details JSON string into typed HabitEntryDetails.
            // The shape is determined by which JSON keys are present (the four
            // detail kinds don't share keys, so this is unambiguous).
            let typedDetails = parseLegacyDetailsJSON(entryData.details, kind: habit.detailKind)

            let entry = HabitEntry(
                id: UUID(uuidString: entryData.id),
                date: entryData.date,
                completionState: typedState,
                details: typedDetails,
                habit: habit
            )
            context.insert(entry)
        }
    }

    /// Parse a legacy `details: String` JSON blob into a typed `HabitEntryDetails`.
    /// Returns `nil` for empty input. Uses the parent habit's `detailKind` as a
    /// hint when the JSON shape is ambiguous (e.g., only `notes` present).
    private func parseLegacyDetailsJSON(_ json: String, kind: DetailKind?) -> HabitEntryDetails? {
        guard !json.isEmpty else { return nil }
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Non-JSON legacy plaintext — treat the whole string as notes.
            return .notes(notes: json)
        }
        let notes = dict["notes"] as? String ?? ""

        // Discriminate by JSON keys first (most reliable signal — they don't overlap).
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
        // No discriminator keys — fall back to the parent habit's detailKind hint,
        // or `.notes` if even that's nil.
        switch kind {
        case .workout: return .workout(types: [], duration: "", intensity: 3, notes: notes)
        case .reading: return .reading(bookTitle: "", pagesRead: "", notes: notes)
        case .mood:    return .mood(mood: 3, notes: notes)
        case .notes, nil: return .notes(notes: notes)
        }
    }

    private func importNotes(from backupNotes: [NoteData], in context: ModelContext) {
        for noteData in backupNotes {
            let note = Note(id: UUID(uuidString: noteData.id), date: noteData.date, content: noteData.content)
            context.insert(note)
        }
    }

    // MARK: - Progress Updates

    private func updateBackupProgress(_ progress: Float) {
        NotificationCenter.default.post(name: .backupProgressUpdated, object: nil, userInfo: ["progress": progress])
    }

    private func updateRestoreProgress(_ progress: Float) {
        NotificationCenter.default.post(name: .restoreProgressUpdated, object: nil, userInfo: ["progress": progress])
    }

    // MARK: - Helper Methods

    private static let backupDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter
    }()

    private func formattedDate() -> String {
        Self.backupDateFormatter.string(from: Date())
    }
}

// MARK: - Data Models for Backup
//
// Wire-format note: `BackupData` lost `collections` / `journalEntries` / `tags`
// fields and `HabitData` lost `collectionID` in bt-0003 Wave 1. Old backup files
// that carry those keys still decode cleanly — `JSONDecoder` ignores unknown
// keys by default, so the dormant data is silently dropped on restore. New
// backups simply don't emit them.

struct BackupData: Codable {
    let version: Int
    let createdAt: Date
    let habits: [HabitData]
    let habitEntries: [HabitEntryData]
    let notes: [NoteData]?
}

struct HabitData: Codable {
    let id: String
    let name: String
    let icon: String
    let color: String
    let frequency: String
    let customDays: String
    let startDate: Date
    let notes: String
    let order: Int
    let trackDetails: Bool
    let detailType: String
    let useMultipleStates: Bool
    let isNegativeHabit: Bool

    // Support older backups that don't have all fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        color = try container.decode(String.self, forKey: .color)
        frequency = try container.decode(String.self, forKey: .frequency)
        customDays = try container.decode(String.self, forKey: .customDays)
        startDate = try container.decode(Date.self, forKey: .startDate)
        notes = try container.decode(String.self, forKey: .notes)
        order = try container.decode(Int.self, forKey: .order)
        trackDetails = try container.decodeIfPresent(Bool.self, forKey: .trackDetails) ?? false
        detailType = try container.decodeIfPresent(String.self, forKey: .detailType) ?? "general"
        useMultipleStates = try container.decodeIfPresent(Bool.self, forKey: .useMultipleStates) ?? false
        isNegativeHabit = try container.decodeIfPresent(Bool.self, forKey: .isNegativeHabit) ?? false
    }

    // Standard initializer for creating backups
    init(id: String, name: String, icon: String, color: String, frequency: String, customDays: String, startDate: Date, notes: String, order: Int, trackDetails: Bool, detailType: String, useMultipleStates: Bool, isNegativeHabit: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.frequency = frequency
        self.customDays = customDays
        self.startDate = startDate
        self.notes = notes
        self.order = order
        self.trackDetails = trackDetails
        self.detailType = detailType
        self.useMultipleStates = useMultipleStates
        self.isNegativeHabit = isNegativeHabit
    }
}

struct HabitEntryData: Codable {
    let id: String
    let date: Date
    let completed: Bool
    let details: String
    let habitID: String
    let completionState: Int
}

struct NoteData: Codable {
    let id: String
    let content: String
    let date: Date
}

// MARK: - Notification Names

extension Notification.Name {
    static let backupProgressUpdated = Notification.Name("backupProgressUpdated")
    static let restoreProgressUpdated = Notification.Name("restoreProgressUpdated")
}
