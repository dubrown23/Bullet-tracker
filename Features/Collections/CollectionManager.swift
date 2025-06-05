//
//  CollectionManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/4/25.
//

import Foundation
import CoreData

/// Manages automatic collection creation and organization
class CollectionManager {
    
    // MARK: - Properties
    
    private let coreDataManager = CoreDataManager.shared
    
    // MARK: - Public Methods
    
    /// Creates automatic collections for current year and month if they don't exist
    func createCurrentTimeCollections() {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        
        // Ensure Future Log exists
        _ = getOrCreateFutureLogCollection()
        
        // Ensure Monthly Log exists (single collection for all months)
        _ = getOrCreateMonthlyLogCollection()
        
        // Ensure current year collection exists
        _ = getOrCreateYearCollection(year: year)
        
        #if DEBUG
        print("✅ Automatic collections created/verified")
        #endif
    }
    
    /// Gets or creates the Future Log collection
    func getOrCreateFutureLogCollection() -> Collection {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "collectionType == %@", "future")
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try coreDataManager.container.viewContext.fetch(fetchRequest)
            if let existing = results.first {
                return existing
            }
        } catch {
            #if DEBUG
            print("❌ Error fetching future log collection: \(error)")
            #endif
        }
        
        // Create Future Log collection
        return createAutomaticCollection(name: "Future Log", type: "future", sortOrder: -1)
    }
    
    /// Gets or creates the single Monthly Log collection
    func getOrCreateMonthlyLogCollection() -> Collection {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "collectionType == %@", "monthly")
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try coreDataManager.container.viewContext.fetch(fetchRequest)
            if let existing = results.first {
                return existing
            }
        } catch {
            #if DEBUG
            print("❌ Error fetching monthly log collection: \(error)")
            #endif
        }
        
        // Create Monthly Log collection
        return createAutomaticCollection(name: "Monthly Log", type: "monthly", sortOrder: 0)
    }
    
    /// Gets or creates a year collection
    func getOrCreateYearCollection(year: Int) -> Collection {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND isAutomatic == true", String(year))
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try coreDataManager.container.viewContext.fetch(fetchRequest)
            if let existing = results.first {
                return existing
            }
        } catch {
            #if DEBUG
            print("❌ Error fetching year collection: \(error)")
            #endif
        }
        
        // Create new year collection
        return createAutomaticCollection(name: String(year), type: "year", sortOrder: Int32(year))
    }
    
    /// DEPRECATED: Use getOrCreateMonthlyLogCollection instead
    /// Kept for backward compatibility during migration
    func getOrCreateMonthCollection(year: Int, month: Int) -> Collection {
        // For now, return the single Monthly Log collection
        return getOrCreateMonthlyLogCollection()
    }
    
    /// One-time cleanup to remove old automatic year/month collections
    /// One-time cleanup to remove old automatic year/month collections
    func cleanupOldAutomaticCollections() {
        let context = coreDataManager.container.viewContext
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        
        // Find collections that match old patterns
        fetchRequest.predicate = NSPredicate(format: "isAutomatic == true AND (name CONTAINS '-' OR (name MATCHES '^[0-9]{4}$' AND name != %@))", String(Calendar.current.component(.year, from: Date())))
        
        do {
            let oldCollections = try context.fetch(fetchRequest)
            
            if !oldCollections.isEmpty {
                #if DEBUG
                print("🧹 Found \(oldCollections.count) old automatic collections to clean up")
                #endif
                
                for collection in oldCollections {
                    // Don't delete if it has journal entries
                    if let entries = collection.entries, entries.count > 0 {
                        #if DEBUG
                        print("⚠️ Skipping '\(collection.name ?? "")' - has \(entries.count) journal entries")
                        #endif
                        continue
                    }
                    
                    // Don't delete if it has habits
                    if let habits = collection.habits, habits.count > 0 {
                        #if DEBUG
                        print("⚠️ Skipping '\(collection.name ?? "")' - has \(habits.count) habits")
                        #endif
                        continue
                    }
                    
                    // Don't delete Future Log or Monthly Log
                    if let name = collection.name,
                       (name == "Future Log" || name == "Monthly Log") {
                        continue
                    }
                    
                    #if DEBUG
                    print("🗑️ Deleting old collection: \(collection.name ?? "")")
                    #endif
                    context.delete(collection)
                }
                
                try context.save()
                #if DEBUG
                print("✅ Cleanup complete")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Error during cleanup: \(error)")
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    /// Creates an automatic collection with proper sorting and configuration
    private func createAutomaticCollection(name: String, type: String, sortOrder: Int32 = 0) -> Collection {
        let context = coreDataManager.container.viewContext
        let collection = Collection(context: context)
        collection.id = UUID()
        collection.name = name
        collection.isAutomatic = true
        collection.collectionType = type
        collection.sortOrder = sortOrder
        
        coreDataManager.saveContext()
        return collection
    }
    
    // MARK: - Migration Helper
    
    /// Removes old individual month collections (for cleanup after implementing single Monthly Log)
    func cleanupOldMonthCollections() {
        let context = coreDataManager.container.viewContext
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "collectionType == %@ AND name != %@", "month", "Monthly Log")
        
        do {
            let oldMonthCollections = try context.fetch(fetchRequest)
            
            #if DEBUG
            print("🧹 Found \(oldMonthCollections.count) old month collections to clean up")
            #endif
            
            for collection in oldMonthCollections {
                // Move any entries to the Monthly Log collection before deleting
                if let entries = collection.entries as? Set<JournalEntry>, !entries.isEmpty {
                    let monthlyLog = getOrCreateMonthlyLogCollection()
                    for entry in entries {
                        entry.collection = monthlyLog
                    }
                }
                context.delete(collection)
            }
            
            try context.save()
            
            #if DEBUG
            print("✅ Cleanup complete")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error cleaning up old month collections: \(error)")
            #endif
        }
    }
}
