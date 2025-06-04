//
//  BackupManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/15/25.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - Backup Manager

class BackupManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = BackupManager()
    private init() {}
    
    // MARK: - Properties
    
    /// Error message for the last operation
    var errorMessage: String?
    
    /// Current backup file version - increment when changing format
    let backupVersion = 1
    
    // MARK: - Constants
    
    private let entityNames = ["Habit", "HabitEntry", "Collection", "JournalEntry", "Tag"]
    
    // MARK: - Backup Creation
    
    /// Creates a backup of all app data and returns the file URL
    func createBackup() -> URL? {
        errorMessage = nil
        
        updateBackupProgress(0.1)
        
        let backupData = prepareBackupData()
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
    
    /// Restores app data from a backup file at the given URL
    func restoreFromURL(_ url: URL) -> Bool {
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
            
            clearExistingData()
            updateRestoreProgress(0.5)
            
            let success = importBackupData(backupData)
            updateRestoreProgress(1.0)
            
            return success
            
        } catch let error as DecodingError {
            #if DEBUG
            print("JSON decoding error: \(error)")
            #endif
            errorMessage = "The backup file is not in the correct format"
            return false
        } catch {
            #if DEBUG
            print("Error during restore: \(error)")
            #endif
            errorMessage = "Could not read the backup file"
            return false
        }
    }
    
    // MARK: - Private Methods - Backup Preparation
    
    private func prepareBackupData() -> BackupData {
        updateBackupProgress(0.2)
        
        let habits = fetchHabits()
        updateBackupProgress(0.3)
        
        let habitEntries = fetchHabitEntries()
        updateBackupProgress(0.4)
        
        let collections = fetchCollections()
        updateBackupProgress(0.5)
        
        let journalEntries = fetchJournalEntries()
        updateBackupProgress(0.6)
        
        let tags = fetchTags()
        updateBackupProgress(0.7)
        
        return BackupData(
            version: backupVersion,
            createdAt: Date(),
            habits: habits,
            habitEntries: habitEntries,
            collections: collections,
            journalEntries: journalEntries,
            tags: tags
        )
    }
    
    // MARK: - Private Methods - Data Fetching
    
    private func fetchHabits() -> [HabitData] {
        let habits = CoreDataManager.shared.fetchAllHabits()
        
        return habits.map { habit in
            HabitData(
                id: habit.id?.uuidString ?? UUID().uuidString,
                name: habit.name ?? "",
                icon: habit.icon ?? "circle.fill",
                color: habit.color ?? "#007AFF",
                frequency: habit.frequency ?? "daily",
                customDays: habit.customDays ?? "",
                startDate: habit.startDate ?? Date(),
                notes: habit.notes ?? "",
                order: Int(habit.order),
                collectionID: habit.collection?.id?.uuidString,
                trackDetails: habit.value(forKey: "trackDetails") as? Bool ?? false,
                detailType: habit.value(forKey: "detailType") as? String ?? "general",
                useMultipleStates: habit.value(forKey: "useMultipleStates") as? Bool ?? false
            )
        }
    }
    
    private func fetchHabitEntries() -> [HabitEntryData] {
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        
        do {
            let entries = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
            
            return entries.map { entry in
                HabitEntryData(
                    id: entry.id?.uuidString ?? UUID().uuidString,
                    date: entry.date ?? Date(),
                    completed: entry.completed,
                    details: entry.details ?? "",
                    habitID: entry.habit?.id?.uuidString ?? "",
                    completionState: entry.value(forKey: "completionState") as? Int ?? 0
                )
            }
        } catch {
            #if DEBUG
            print("Error fetching habit entries: \(error)")
            #endif
            return []
        }
    }
    
    private func fetchCollections() -> [CollectionData] {
        let collections = CoreDataManager.shared.fetchAllCollections()
        
        return collections.map { collection in
            CollectionData(
                id: collection.id?.uuidString ?? UUID().uuidString,
                name: collection.name ?? ""
            )
        }
    }
    
    private func fetchJournalEntries() -> [JournalEntryData] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        do {
            let entries = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
            
            return entries.map { entry in
                let tagIDs = (entry.tags?.allObjects as? [Tag])?.compactMap { $0.id?.uuidString } ?? []
                
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
        } catch {
            #if DEBUG
            print("Error fetching journal entries: \(error)")
            #endif
            return []
        }
    }
    
    private func fetchTags() -> [TagData] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        
        do {
            let tags = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
            
            return tags.map { tag in
                TagData(
                    id: tag.id?.uuidString ?? UUID().uuidString,
                    name: tag.name ?? ""
                )
            }
        } catch {
            #if DEBUG
            print("Error fetching tags: \(error)")
            #endif
            return []
        }
    }
    
    // MARK: - Private Methods - Restore Operations
    
    private func prepareLocalCopy(from sourceURL: URL, to destinationURL: URL) throws {
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        #if DEBUG
        print("Successfully copied backup file for restore")
        #endif
    }
    
    private func validateBackupVersion(_ version: Int) -> Bool {
        if version > backupVersion {
            errorMessage = "This backup was created with a newer version of the app"
            return false
        }
        return true
    }
    
    private func clearExistingData() {
        let context = CoreDataManager.shared.container.viewContext
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try CoreDataManager.shared.container.persistentStoreCoordinator.execute(
                    deleteRequest,
                    with: context
                )
            } catch {
                #if DEBUG
                print("Error clearing \(entityName) data: \(error)")
                #endif
            }
        }
        
        context.reset()
    }
    
    private func importBackupData(_ backupData: BackupData) -> Bool {
        let context = CoreDataManager.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        var success = true
        
        context.performAndWait {
            do {
                updateRestoreProgress(0.6)
                let collectionMap = importCollections(from: backupData.collections, in: context)
                
                updateRestoreProgress(0.7)
                let tagMap = importTags(from: backupData.tags, in: context)
                
                updateRestoreProgress(0.8)
                let habitMap = importHabits(
                    from: backupData.habits,
                    collectionMap: collectionMap,
                    in: context
                )
                
                updateRestoreProgress(0.85)
                importHabitEntries(
                    from: backupData.habitEntries,
                    habitMap: habitMap,
                    in: context
                )
                
                updateRestoreProgress(0.9)
                importJournalEntries(
                    from: backupData.journalEntries,
                    collectionMap: collectionMap,
                    tagMap: tagMap,
                    in: context
                )
                
                try context.save()
                updateRestoreProgress(0.95)
                
            } catch {
                success = false
                errorMessage = "Failed to restore backup: \(error.localizedDescription)"
                context.rollback()
            }
        }
        
        return success
    }
    
    // MARK: - Private Methods - Entity Import
    
    private func importCollections(
        from backupCollections: [CollectionData],
        in context: NSManagedObjectContext
    ) -> [String: Collection] {
        var collectionMap: [String: Collection] = [:]
        
        for collectionData in backupCollections {
            let collection = Collection(context: context)
            collection.id = UUID(uuidString: collectionData.id)
            collection.name = collectionData.name
            
            collectionMap[collectionData.id] = collection
        }
        
        return collectionMap
    }
    
    private func importTags(
        from backupTags: [TagData],
        in context: NSManagedObjectContext
    ) -> [String: Tag] {
        var tagMap: [String: Tag] = [:]
        
        for tagData in backupTags {
            let tag = Tag(context: context)
            tag.id = UUID(uuidString: tagData.id)
            tag.name = tagData.name
            
            tagMap[tagData.id] = tag
        }
        
        return tagMap
    }
    
    private func importHabits(
        from backupHabits: [HabitData],
        collectionMap: [String: Collection],
        in context: NSManagedObjectContext
    ) -> [String: Habit] {
        var habitMap: [String: Habit] = [:]
        
        for habitData in backupHabits {
            let habit = Habit(context: context)
            habit.id = UUID(uuidString: habitData.id)
            habit.name = habitData.name
            habit.icon = habitData.icon
            habit.color = habitData.color
            habit.frequency = habitData.frequency
            habit.customDays = habitData.customDays
            habit.startDate = habitData.startDate
            habit.notes = habitData.notes
            habit.order = Int32(habitData.order)
            
            if let collectionID = habitData.collectionID,
               let collection = collectionMap[collectionID] {
                habit.collection = collection
            }
            
            habit.setValue(habitData.trackDetails, forKey: "trackDetails")
            habit.setValue(habitData.detailType, forKey: "detailType")
            habit.setValue(habitData.useMultipleStates, forKey: "useMultipleStates")
            
            habitMap[habitData.id] = habit
        }
        
        return habitMap
    }
    
    private func importHabitEntries(
        from backupEntries: [HabitEntryData],
        habitMap: [String: Habit],
        in context: NSManagedObjectContext
    ) {
        for entryData in backupEntries {
            guard let habit = habitMap[entryData.habitID] else { continue }
            
            let entry = HabitEntry(context: context)
            entry.id = UUID(uuidString: entryData.id)
            entry.date = entryData.date
            entry.completed = entryData.completed
            entry.details = entryData.details
            entry.habit = habit
            
            entry.setValue(entryData.completionState, forKey: "completionState")
        }
    }
    
    private func importJournalEntries(
        from backupEntries: [JournalEntryData],
        collectionMap: [String: Collection],
        tagMap: [String: Tag],
        in context: NSManagedObjectContext
    ) {
        for entryData in backupEntries {
            let entry = JournalEntry(context: context)
            entry.id = UUID(uuidString: entryData.id)
            entry.content = entryData.content
            entry.date = entryData.date
            entry.entryType = entryData.entryType
            entry.taskStatus = entryData.taskStatus
            entry.priority = entryData.priority
            
            if let collectionID = entryData.collectionID,
               let collection = collectionMap[collectionID] {
                entry.collection = collection
            }
            
            for tagID in entryData.tagIDs {
                if let tag = tagMap[tagID] {
                    entry.addToTags(tag)
                }
            }
        }
    }
    
    // MARK: - Progress Updates
    
    private func updateBackupProgress(_ progress: Float) {
        NotificationCenter.default.post(
            name: .backupProgressUpdated,
            object: nil,
            userInfo: ["progress": progress]
        )
    }
    
    private func updateRestoreProgress(_ progress: Float) {
        NotificationCenter.default.post(
            name: .restoreProgressUpdated,
            object: nil,
            userInfo: ["progress": progress]
        )
    }
    
    // MARK: - Helper Methods
    
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: Date())
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

// MARK: - Notification Names

extension Notification.Name {
    static let backupProgressUpdated = Notification.Name("backupProgressUpdated")
    static let restoreProgressUpdated = Notification.Name("restoreProgressUpdated")
}
