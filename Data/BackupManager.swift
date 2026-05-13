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
        updateBackupProgress(0.3)

        let habitEntries = fetchHabitEntries(in: context)
        updateBackupProgress(0.4)

        let collections = fetchCollections(in: context)
        updateBackupProgress(0.5)

        let journalEntries = fetchJournalEntries(in: context)
        updateBackupProgress(0.6)

        let tags = fetchTags(in: context)
        updateBackupProgress(0.65)

        let notes = fetchNotes(in: context)
        updateBackupProgress(0.7)

        return BackupData(
            version: backupVersion,
            createdAt: Date(),
            habits: habits,
            habitEntries: habitEntries,
            collections: collections,
            journalEntries: journalEntries,
            tags: tags,
            notes: notes
        )
    }

    // MARK: - Private Methods - Data Fetching

    private func fetchHabits(in context: ModelContext) -> [HabitData] {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []

        return habits.map { habit in
            HabitData(
                id: habit.id?.uuidString ?? UUID().uuidString,
                name: habit.name ?? "",
                icon: habit.icon ?? "circle.fill",
                color: habit.color ?? "#007AFF",
                frequency: habit.frequency ?? HabitFrequency.daily.rawValue,
                customDays: habit.customDays ?? "",
                startDate: habit.startDate ?? Date(),
                notes: habit.notes ?? "",
                order: Int(habit.order),
                collectionID: habit.collection?.id?.uuidString,
                trackDetails: habit.trackDetails,
                detailType: habit.detailType ?? "general",
                useMultipleStates: habit.useMultipleStates,
                isNegativeHabit: habit.isNegativeHabit
            )
        }
    }

    private func fetchHabitEntries(in context: ModelContext) -> [HabitEntryData] {
        let entries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []

        return entries.map { entry in
            HabitEntryData(
                id: entry.id?.uuidString ?? UUID().uuidString,
                date: entry.date ?? Date(),
                completed: entry.completed,
                details: entry.details ?? "",
                habitID: entry.habit?.id?.uuidString ?? "",
                completionState: Int(entry.completionState)
            )
        }
    }

    private func fetchCollections(in context: ModelContext) -> [CollectionData] {
        let collections = (try? context.fetch(FetchDescriptor<Collection>())) ?? []

        return collections.map { collection in
            CollectionData(
                id: collection.id?.uuidString ?? UUID().uuidString,
                name: collection.name ?? ""
            )
        }
    }

    private func fetchJournalEntries(in context: ModelContext) -> [JournalEntryData] {
        let entries = (try? context.fetch(FetchDescriptor<JournalEntry>())) ?? []

        return entries.map { entry in
            let tagIDs = (entry.tags ?? []).compactMap { $0.id?.uuidString }

            return JournalEntryData(
                id: entry.id?.uuidString ?? UUID().uuidString,
                content: entry.content ?? "",
                date: entry.date ?? Date(),
                entryType: entry.entryType ?? "note",
                taskStatus: entry.taskStatus,
                priority: entry.priority,
                collectionID: entry.collection?.id?.uuidString,
                tagIDs: tagIDs
            )
        }
    }

    private func fetchTags(in context: ModelContext) -> [TagData] {
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []

        return tags.map { tag in
            TagData(
                id: tag.id?.uuidString ?? UUID().uuidString,
                name: tag.name ?? ""
            )
        }
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
        try? context.delete(model: JournalEntry.self)
        try? context.delete(model: Note.self)
        try? context.delete(model: Tag.self)
        try? context.delete(model: Habit.self)
        try? context.delete(model: Collection.self)
        try? context.save()
    }

    private func importBackupData(_ backupData: BackupData, in context: ModelContext) -> Bool {
        updateRestoreProgress(0.6)
        let collectionMap = importCollections(from: backupData.collections, in: context)

        updateRestoreProgress(0.7)
        let tagMap = importTags(from: backupData.tags, in: context)

        updateRestoreProgress(0.8)
        let habitMap = importHabits(from: backupData.habits, collectionMap: collectionMap, in: context)

        updateRestoreProgress(0.85)
        importHabitEntries(from: backupData.habitEntries, habitMap: habitMap, in: context)

        updateRestoreProgress(0.9)
        importJournalEntries(from: backupData.journalEntries, collectionMap: collectionMap, tagMap: tagMap, in: context)

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

    private func importCollections(from backupCollections: [CollectionData], in context: ModelContext) -> [String: Collection] {
        var collectionMap: [String: Collection] = [:]

        for collectionData in backupCollections {
            let collection = Collection(id: UUID(uuidString: collectionData.id), name: collectionData.name)
            context.insert(collection)
            collectionMap[collectionData.id] = collection
        }

        return collectionMap
    }

    private func importTags(from backupTags: [TagData], in context: ModelContext) -> [String: Tag] {
        var tagMap: [String: Tag] = [:]

        for tagData in backupTags {
            let tag = Tag(id: UUID(uuidString: tagData.id), name: tagData.name)
            context.insert(tag)
            tagMap[tagData.id] = tag
        }

        return tagMap
    }

    private func importHabits(from backupHabits: [HabitData], collectionMap: [String: Collection], in context: ModelContext) -> [String: Habit] {
        var habitMap: [String: Habit] = [:]

        for habitData in backupHabits {
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
                detailType: habitData.detailType,
                trackDetails: habitData.trackDetails,
                useMultipleStates: habitData.useMultipleStates,
                isNegativeHabit: habitData.isNegativeHabit,
                collection: habitData.collectionID.flatMap { collectionMap[$0] }
            )
            context.insert(habit)
            habitMap[habitData.id] = habit
        }

        return habitMap
    }

    private func importHabitEntries(from backupEntries: [HabitEntryData], habitMap: [String: Habit], in context: ModelContext) {
        for entryData in backupEntries {
            guard let habit = habitMap[entryData.habitID] else { continue }

            let entry = HabitEntry(
                id: UUID(uuidString: entryData.id),
                date: entryData.date,
                completed: entryData.completed,
                completionState: Int16(entryData.completionState),
                details: entryData.details,
                habit: habit
            )
            context.insert(entry)
        }
    }

    private func importJournalEntries(from backupEntries: [JournalEntryData], collectionMap: [String: Collection], tagMap: [String: Tag], in context: ModelContext) {
        for entryData in backupEntries {
            let entry = JournalEntry(
                id: UUID(uuidString: entryData.id),
                date: entryData.date,
                content: entryData.content,
                entryType: entryData.entryType,
                priority: entryData.priority,
                taskStatus: entryData.taskStatus,
                collection: entryData.collectionID.flatMap { collectionMap[$0] }
            )
            entry.tags = entryData.tagIDs.compactMap { tagMap[$0] }
            context.insert(entry)
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

struct BackupData: Codable {
    let version: Int
    let createdAt: Date
    let habits: [HabitData]
    let habitEntries: [HabitEntryData]
    let collections: [CollectionData]
    let journalEntries: [JournalEntryData]
    let tags: [TagData]
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
    let collectionID: String?
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
        collectionID = try container.decodeIfPresent(String.self, forKey: .collectionID)
        trackDetails = try container.decodeIfPresent(Bool.self, forKey: .trackDetails) ?? false
        detailType = try container.decodeIfPresent(String.self, forKey: .detailType) ?? "general"
        useMultipleStates = try container.decodeIfPresent(Bool.self, forKey: .useMultipleStates) ?? false
        isNegativeHabit = try container.decodeIfPresent(Bool.self, forKey: .isNegativeHabit) ?? false
    }

    // Standard initializer for creating backups
    init(id: String, name: String, icon: String, color: String, frequency: String, customDays: String, startDate: Date, notes: String, order: Int, collectionID: String?, trackDetails: Bool, detailType: String, useMultipleStates: Bool, isNegativeHabit: Bool) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.frequency = frequency
        self.customDays = customDays
        self.startDate = startDate
        self.notes = notes
        self.order = order
        self.collectionID = collectionID
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

struct CollectionData: Codable {
    let id: String
    let name: String
}

struct JournalEntryData: Codable {
    let id: String
    let content: String
    let date: Date
    let entryType: String
    let taskStatus: String?
    let priority: Bool
    let collectionID: String?
    let tagIDs: [String]
}

struct TagData: Codable {
    let id: String
    let name: String
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
