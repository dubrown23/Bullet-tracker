//
//  BackupManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/15/25.
//

import Foundation
import CoreData
import SwiftUI

class BackupManager: ObservableObject {
    static let shared = BackupManager()
    private init() {}
    
    // Error message for the last operation
    var errorMessage: String?
    
    // Current backup file version - increment when changing format
    let backupVersion = 1
    
    // MARK: - Backup Creation
    
    func createBackup() -> URL? {
        errorMessage = nil
        
        // Notify progress started
        updateBackupProgress(0.1)
        
        let backupData = prepareBackupData()
        updateBackupProgress(0.7)
        
        guard let jsonData = try? JSONEncoder().encode(backupData) else {
            errorMessage = "Failed to encode backup data"
            return nil
        }
        
        updateBackupProgress(0.8)
        
        // Create a temporary file
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
    
    private func prepareBackupData() -> BackupData {
        updateBackupProgress(0.2)
        
        // Fetch all data from Core Data
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
        
        // Return structured backup data
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
    
    // MARK: - Data Fetching Methods
    
    private func fetchHabits() -> [HabitData] {
        let habits = CoreDataManager.shared.fetchAllHabits()
        
        return habits.map { habit -> HabitData in
            return HabitData(
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
        // Fetch all habit entries using the method from CoreDataManager extension
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        let entries: [HabitEntry]
        
        do {
            entries = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching habit entries: \(error)")
            return []
        }
        
        return entries.map { entry -> HabitEntryData in
            return HabitEntryData(
                id: entry.id?.uuidString ?? UUID().uuidString,
                date: entry.date ?? Date(),
                completed: entry.completed,
                details: entry.details ?? "",
                habitID: entry.habit?.id?.uuidString ?? "",
                completionState: entry.value(forKey: "completionState") as? Int ?? 0
            )
        }
    }
    
    private func fetchCollections() -> [CollectionData] {
        let collections = CoreDataManager.shared.fetchAllCollections()
        
        return collections.map { collection -> CollectionData in
            return CollectionData(
                id: collection.id?.uuidString ?? UUID().uuidString,
                name: collection.name ?? ""
            )
        }
    }
    
    private func fetchJournalEntries() -> [JournalEntryData] {
        // Fetch all journal entries
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        let entries: [JournalEntry]
        
        do {
            entries = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching journal entries: \(error)")
            return []
        }
        
        return entries.map { entry -> JournalEntryData in
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
    }
    
    private func fetchTags() -> [TagData] {
        // Fetch all tags
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let tags: [Tag]
        
        do {
            tags = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching tags: \(error)")
            return []
        }
        
        return tags.map { tag -> TagData in
            return TagData(
                id: tag.id?.uuidString ?? UUID().uuidString,
                name: tag.name ?? ""
            )
        }
    }
    
    // MARK: - Restore Functions
    
    func restoreFromURL(_ url: URL) -> Bool {
        errorMessage = nil
        updateRestoreProgress(0.1)
        
        // Make a local copy of the file to ensure we can access it
        let tempDirectory = FileManager.default.temporaryDirectory
        let localURL = tempDirectory.appendingPathComponent("backup_for_restore.json")
        
        do {
            // Remove any existing file at the destination
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.removeItem(at: localURL)
            }
            
            // Copy the file to the temporary directory
            try FileManager.default.copyItem(at: url, to: localURL)
            print("Successfully copied backup file for restore")
            
            // Continue with the restore process using the local copy
            do {
                let jsonData = try Data(contentsOf: localURL)
                
                do {
                    let backupData = try JSONDecoder().decode(BackupData.self, from: jsonData)
                    updateRestoreProgress(0.3)
                    
                    // Validate backup version
                    if backupData.version > backupVersion {
                        errorMessage = "This backup was created with a newer version of the app"
                        return false
                    }
                    
                    updateRestoreProgress(0.4)
                    
                    // Clear existing data
                    clearExistingData()
                    updateRestoreProgress(0.5)
                    
                    // Import from backup
                    let success = importBackupData(backupData)
                    updateRestoreProgress(1.0)
                    
                    return success
                } catch {
                    print("JSON decoding error: \(error)")
                    errorMessage = "The backup file is not in the correct format"
                    return false
                }
            } catch {
                print("Error reading local copy: \(error)")
                errorMessage = "Could not read the backup file"
                return false
            }
        } catch {
            print("Error copying file for restore: \(error)")
            errorMessage = "Could not access the backup file"
            return false
        }
    }
    
    private func clearExistingData() {
        let context = CoreDataManager.shared.container.viewContext
        let entityNames = ["Habit", "HabitEntry", "Collection", "JournalEntry", "Tag"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try CoreDataManager.shared.container.persistentStoreCoordinator.execute(deleteRequest, with: context)
            } catch {
                print("Error clearing \(entityName) data: \(error)")
            }
        }
        
        // Reset context to ensure clean state
        context.reset()
    }
    
    private func importBackupData(_ backupData: BackupData) -> Bool {
        // Create a new Core Data context for batch operations
        let context = CoreDataManager.shared.container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        var success = true
        
        context.performAndWait {
            do {
                // 1. Import Collections
                updateRestoreProgress(0.6)
                let collectionMap = importCollections(from: backupData.collections, in: context)
                
                // 2. Import Tags
                updateRestoreProgress(0.7)
                let tagMap = importTags(from: backupData.tags, in: context)
                
                // 3. Import Habits
                updateRestoreProgress(0.8)
                let habitMap = importHabits(from: backupData.habits, collectionMap: collectionMap, in: context)
                
                // 4. Import Habit Entries
                updateRestoreProgress(0.85)
                importHabitEntries(from: backupData.habitEntries, habitMap: habitMap, in: context)
                
                // 5. Import Journal Entries
                updateRestoreProgress(0.9)
                importJournalEntries(from: backupData.journalEntries, collectionMap: collectionMap, tagMap: tagMap, in: context)
                
                // Save all changes
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
    
    // Import Collection entities and return a mapping from backup IDs to Core Data objects
    private func importCollections(from backupCollections: [CollectionData], in context: NSManagedObjectContext) -> [String: Collection] {
        var collectionMap: [String: Collection] = [:]
        
        for collectionData in backupCollections {
            let collection = Collection(context: context)
            collection.id = UUID(uuidString: collectionData.id)
            collection.name = collectionData.name
            
            collectionMap[collectionData.id] = collection
        }
        
        return collectionMap
    }
    
    // Import Tag entities and return a mapping from backup IDs to Core Data objects
    private func importTags(from backupTags: [TagData], in context: NSManagedObjectContext) -> [String: Tag] {
        var tagMap: [String: Tag] = [:]
        
        for tagData in backupTags {
            let tag = Tag(context: context)
            tag.id = UUID(uuidString: tagData.id)
            tag.name = tagData.name
            
            tagMap[tagData.id] = tag
        }
        
        return tagMap
    }
    
    // Import Habit entities and return a mapping from backup IDs to Core Data objects
    private func importHabits(from backupHabits: [HabitData], collectionMap: [String: Collection], in context: NSManagedObjectContext) -> [String: Habit] {
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
            
            // Set collection relationship if it exists
            if let collectionID = habitData.collectionID, let collection = collectionMap[collectionID] {
                habit.collection = collection
            }
            
            // Set dynamic properties
            habit.setValue(habitData.trackDetails, forKey: "trackDetails")
            habit.setValue(habitData.detailType, forKey: "detailType")
            habit.setValue(habitData.useMultipleStates, forKey: "useMultipleStates")
            
            habitMap[habitData.id] = habit
        }
        
        return habitMap
    }
    
    // Import HabitEntry entities
    private func importHabitEntries(from backupEntries: [HabitEntryData], habitMap: [String: Habit], in context: NSManagedObjectContext) {
        for entryData in backupEntries {
            // Skip entries without a valid habit reference
            guard let habit = habitMap[entryData.habitID] else { continue }
            
            let entry = HabitEntry(context: context)
            entry.id = UUID(uuidString: entryData.id)
            entry.date = entryData.date
            entry.completed = entryData.completed
            entry.details = entryData.details
            entry.habit = habit
            
            // Set completion state
            entry.setValue(entryData.completionState, forKey: "completionState")
        }
    }
    
    // Import JournalEntry entities
    private func importJournalEntries(from backupEntries: [JournalEntryData], collectionMap: [String: Collection], tagMap: [String: Tag], in context: NSManagedObjectContext) {
        for entryData in backupEntries {
            let entry = JournalEntry(context: context)
            entry.id = UUID(uuidString: entryData.id)
            entry.content = entryData.content
            entry.date = entryData.date
            entry.entryType = entryData.entryType
            entry.taskStatus = entryData.taskStatus
            entry.priority = entryData.priority
            
            // Set collection relationship if it exists
            if let collectionID = entryData.collectionID, let collection = collectionMap[collectionID] {
                entry.collection = collection
            }
            
            // Set tags relationships
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

// Main backup container
struct BackupData: Codable {
    let version: Int
    let createdAt: Date
    let habits: [HabitData]
    let habitEntries: [HabitEntryData]
    let collections: [CollectionData]
    let journalEntries: [JournalEntryData]
    let tags: [TagData]
}

// Habit model for backup
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

// HabitEntry model for backup
struct HabitEntryData: Codable {
    let id: String
    let date: Date
    let completed: Bool
    let details: String
    let habitID: String
    let completionState: Int
}

// Collection model for backup - removed color and icon properties
struct CollectionData: Codable {
    let id: String
    let name: String
}

// JournalEntry model for backup
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

// Tag model for backup - removed color property
struct TagData: Codable {
    let id: String
    let name: String
}

// Notification names for progress updates
extension Notification.Name {
    static let backupProgressUpdated = Notification.Name("backupProgressUpdated")
    static let restoreProgressUpdated = Notification.Name("restoreProgressUpdated")
}
