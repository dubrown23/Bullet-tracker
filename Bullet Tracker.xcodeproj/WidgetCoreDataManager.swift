//
//  WidgetCoreDataManager.swift
//  BulletTrackerWidgets
//
//  Created by Dustin Brown on 10/30/25.
//

import CoreData
import Foundation

/// Core Data manager specifically for widget extension
/// Uses the same App Group container as the main app
class WidgetCoreDataManager {
    static let shared = WidgetCoreDataManager()
    
    // MARK: - Properties
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Bullet_Tracker")
        
        // Configure to use the same App Group container as main app
        if let storeURL = containerURL() {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            container.persistentStoreDescriptions = [storeDescription]
        }
        
        container.loadPersistentStores { _, error in
            if let error = error {
                print("Widget Core Data error: \(error)")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    // MARK: - Private Methods
    
    private func containerURL() -> URL? {
        let appGroupID = "group.db23.Bullet-Tracker"
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("Warning: Unable to access App Group container from widget")
            return nil
        }
        return appGroupURL.appendingPathComponent("BulletTracker.sqlite")
    }
    
    private init() {}
    
    // MARK: - Core Data Saving
    
    func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Widget save error: \(error)")
            }
        }
    }
}