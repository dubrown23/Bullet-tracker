//
//  CoreDataManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import CoreData
import SwiftUI

/// Manages all Core Data operations for the Bullet Tracker app
class CoreDataManager {
    // MARK: - Singleton
    
    static let shared = CoreDataManager()
    
    // MARK: - Properties
    
    /// The Core Data container configured for CloudKit sync
    let container: NSPersistentCloudKitContainer

    /// App Group identifier for sharing data between main app and widget
    private static let appGroupIdentifier = "group.db23.Bullet-Tracker"

    // MARK: - Initialization
    
    private init() {
        container = NSPersistentCloudKitContainer(name: "Bullet_Tracker")
        
        configureContainer()
        loadPersistentStores()
        configureViewContext()
    }
    
    // MARK: - Container Configuration
    
    /// Configures the container for CloudKit sync
    private func configureContainer() {
        guard let description = container.persistentStoreDescriptions.first else { return }
        
        // Configure store URL to use App Group container for widget access
        if let appGroupURL = containerURL() {
            description.url = appGroupURL
        }
        
        // Enable history tracking and remote notifications for CloudKit sync
        description.setOption(true as NSNumber,
                            forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    }
    
    /// Loads the persistent stores
    private func loadPersistentStores() {
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                // In production, we should handle this gracefully
                // Log the error for debugging but don't crash the app
                debugLog("Core Data error: \(error.localizedDescription)")
                
                // You might want to show an alert to the user and attempt recovery
                // For now, we'll continue but the app may not function properly
            }
        }
    }
    
    /// Configures the view context
    private func configureViewContext() {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    /// Returns the URL for the App Group container to share Core Data with widgets
    private func containerURL() -> URL? {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
            debugLog("Unable to access App Group container. Widgets won't be able to access data.")
            return nil
        }
        return appGroupURL.appendingPathComponent("BulletTracker.sqlite")
    }
    
    // MARK: - Core Data Saving
    
    /// Saves the view context if there are changes
    func saveContext() {
        guard container.viewContext.hasChanges else { return }
        
        do {
            try container.viewContext.save()
        } catch {
            let nserror = error as NSError
            // In production, handle this more gracefully
            debugLog("Core Data save error: \(nserror.localizedDescription)")
            
            // Rollback the context to prevent further issues
            container.viewContext.rollback()
            
            // In a production app, you might want to:
            // 1. Show an alert to the user
            // 2. Attempt to save again
            // 3. Prompt for app restart if critical
        }
    }
    
    // MARK: - App Group Support
    
    /// Returns the App Group identifier for sharing data with widgets
    static var sharedAppGroupIdentifier: String {
        return Self.appGroupIdentifier
    }
    
    // MARK: - Initial Setup
    
    /// Sets up default data on first launch
    func setupDefaultData() {
        // No longer create default collections - we use automatic collections now
    }
}

// MARK: - Collection Management

extension CoreDataManager {
    /// Fetches all collections sorted by name (used by BackupManager)
    func fetchAllCollections() -> [Collection] {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            return []
        }
    }
}

// MARK: - Habit Management

extension CoreDataManager {
    /// Creates a new habit
    func createHabit(
        name: String,
        color: String,
        icon: String,
        frequency: String,
        customDays: String = "",
        startDate: Date = Date(),
        notes: String = "",
        collection: Collection? = nil
    ) -> Habit {
        let habit = Habit(context: container.viewContext)
        habit.id = UUID()
        habit.name = name
        habit.color = color
        habit.icon = icon
        habit.frequency = frequency
        habit.customDays = customDays
        habit.startDate = startDate
        habit.notes = notes
        habit.collection = collection
        
        // Set order based on existing habits count
        let fetchRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        do {
            let count = try container.viewContext.count(for: fetchRequest)
            habit.order = Int32(count)
        } catch {
            habit.order = 0
        }
        
        saveContext()
        return habit
    }
    
    /// Updates an existing habit
    func updateHabit(
        _ habit: Habit,
        name: String,
        color: String,
        icon: String,
        frequency: String,
        customDays: String,
        notes: String,
        collection: Collection?
    ) {
        habit.name = name
        habit.color = color
        habit.icon = icon
        habit.frequency = frequency
        habit.customDays = customDays
        habit.notes = notes
        habit.collection = collection
        
        saveContext()
    }
    
    /// Deletes a habit and all its entries
    func deleteHabit(_ habit: Habit) {
        // Delete all associated entries
        if let entries = habit.entries as? Set<HabitEntry> {
            entries.forEach { container.viewContext.delete($0) }
        }
        
        container.viewContext.delete(habit)
        saveContext()
    }
    
    /// Fetches all habits sorted by name
    func fetchAllHabits() -> [Habit] {
        let fetchRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            return []
        }
    }
    
}
