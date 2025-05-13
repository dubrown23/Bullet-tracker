//
//  CoreDataManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

//
//  CoreDataManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import CoreData
import SwiftUI

class CoreDataManager {
    static let shared = CoreDataManager()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "Bullet_Tracker")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - JournalEntry Methods
    
    func createJournalEntry(content: String, entryType: String, taskStatus: String?, date: Date, priority: Bool, collection: Collection? = nil, tags: [Tag] = []) -> JournalEntry {
        let entry = JournalEntry(context: container.viewContext)
        entry.id = UUID()
        entry.content = content
        entry.entryType = entryType
        entry.taskStatus = taskStatus
        entry.date = date
        entry.priority = priority
        entry.collection = collection
        
        for tag in tags {
            entry.addToTags(tag)
        }
        
        saveContext()
        return entry
    }
    
    func updateJournalEntry(_ entry: JournalEntry, content: String, entryType: String, taskStatus: String?, priority: Bool, collection: Collection? = nil, tags: [Tag] = []) {
        entry.content = content
        entry.entryType = entryType
        entry.taskStatus = taskStatus
        entry.priority = priority
        entry.collection = collection
        
        // Remove existing tags
        if let currentTags = entry.tags as? Set<Tag> {
            for tag in currentTags {
                entry.removeFromTags(tag)
            }
        }
        
        // Add new tags
        for tag in tags {
            entry.addToTags(tag)
        }
        
        saveContext()
    }
    
    func deleteJournalEntry(_ entry: JournalEntry) {
        container.viewContext.delete(entry)
        saveContext()
    }
    
    func fetchEntriesForDate(_ date: Date) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching entries: \(error)")
            return []
        }
    }
    
    func fetchEntriesForCollection(_ collection: Collection) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching entries: \(error)")
            return []
        }
    }
    
    func searchEntries(query: String) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        if !query.isEmpty {
            let contentPredicate = NSPredicate(format: "content CONTAINS[cd] %@", query)
            let tagsPredicate = NSPredicate(format: "ANY tags.name CONTAINS[cd] %@", query)
            fetchRequest.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [contentPredicate, tagsPredicate])
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error searching entries: \(error)")
            return []
        }
    }
    
    // MARK: - Collection Methods
    
    func createCollection(name: String) -> Collection {
        let collection = Collection(context: container.viewContext)
        collection.id = UUID()
        collection.name = name
        saveContext()
        return collection
    }
    
    func updateCollection(_ collection: Collection, name: String) {
        collection.name = name
        saveContext()
    }
    
    func deleteCollection(_ collection: Collection) {
        container.viewContext.delete(collection)
        saveContext()
    }
    
    func fetchAllCollections() -> [Collection] {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching collections: \(error)")
            return []
        }
    }
    
    // MARK: - Tag Methods
    
    func getOrCreateTag(name: String) -> Tag {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try container.viewContext.fetch(fetchRequest)
            if let existingTag = results.first {
                return existingTag
            } else {
                let newTag = Tag(context: container.viewContext)
                newTag.id = UUID()
                newTag.name = name
                saveContext()
                return newTag
            }
        } catch {
            print("Error fetching tag: \(error)")
            
            // Create new tag if fetch fails
            let newTag = Tag(context: container.viewContext)
            newTag.id = UUID()
            newTag.name = name
            saveContext()
            return newTag
        }
    }
    
    func fetchAllTags() -> [Tag] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching tags: \(error)")
            return []
        }
    }
    
    // MARK: - Habit Methods
    
    func createHabit(name: String, color: String, icon: String, frequency: String, customDays: String = "", startDate: Date = Date(), notes: String = "", collection: Collection? = nil) -> Habit {
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
        
        saveContext()
        return habit
    }
    
    func updateHabit(_ habit: Habit, name: String, color: String, icon: String, frequency: String, customDays: String, notes: String, collection: Collection?) {
        habit.name = name
        habit.color = color
        habit.icon = icon
        habit.frequency = frequency
        habit.customDays = customDays
        habit.notes = notes
        habit.collection = collection
        
        saveContext()
    }
    
    func deleteHabit(_ habit: Habit) {
        // First delete all associated entries
        if let entries = habit.entries as? Set<HabitEntry> {
            for entry in entries {
                container.viewContext.delete(entry)
            }
        }
        
        container.viewContext.delete(habit)
        saveContext()
    }
    
    func fetchAllHabits() -> [Habit] {
        let fetchRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching habits: \(error)")
            return []
        }
    }
    
    func fetchHabitsInCollection(_ collection: Collection) -> [Habit] {
        let fetchRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching habits: \(error)")
            return []
        }
    }
    
    // MARK: - Habit Entry Methods
    
    func toggleHabitEntry(habit: Habit, date: Date) -> HabitEntry? {
        // Check if an entry already exists for this habit and date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@", habit, startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let results = try container.viewContext.fetch(fetchRequest)
            
            // If entry exists, toggle its completion status or delete it
            if let existingEntry = results.first {
                existingEntry.completed = !existingEntry.completed
                
                if !existingEntry.completed {
                    // If now uncompleted, just delete the entry
                    container.viewContext.delete(existingEntry)
                    saveContext()
                    return nil
                } else {
                    saveContext()
                    return existingEntry
                }
            } else {
                // If no entry exists, create a new completed one
                let newEntry = HabitEntry(context: container.viewContext)
                newEntry.id = UUID()
                newEntry.date = date
                newEntry.completed = true
                newEntry.habit = habit
                
                saveContext()
                return newEntry
            }
        } catch {
            print("Error toggling habit entry: \(error)")
            return nil
        }
    }
    
    func getHabitEntriesForDate(_ date: Date) -> [HabitEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching habit entries: \(error)")
            return []
        }
    }
    
    func getHabitEntriesForDateRange(start: Date, end: Date) -> [HabitEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: end)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Error fetching habit entries: \(error)")
            return []
        }
    }
    
    func getCompletionRateForHabit(_ habit: Habit, daysBack: Int = 30) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date <= %@ AND completed == %@",
                                             habit, startDate as NSDate, endDate as NSDate, NSNumber(value: true))
        
        do {
            let completedCount = try container.viewContext.fetch(fetchRequest).count
            
            // Calculate days that this habit should have been performed
            var totalDays = 0
            var currentDate = startDate
            
            while currentDate <= endDate {
                if shouldPerformHabit(habit, on: currentDate) {
                    totalDays += 1
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            return totalDays > 0 ? Double(completedCount) / Double(totalDays) : 0
        } catch {
            print("Error calculating habit completion rate: \(error)")
            return 0
        }
    }
    
    // Helper method to determine if a habit should be performed on a given date
    private func shouldPerformHabit(_ habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1 is Sunday, 7 is Saturday
        
        switch habit.frequency {
        case "daily":
            return true
            
        case "weekdays":
            // Weekdays are 2-6 (Monday-Friday)
            return weekday >= 2 && weekday <= 6
            
        case "weekends":
            // Weekends are 1 and 7 (Sunday and Saturday)
            return weekday == 1 || weekday == 7
            
        case "weekly":
            // Assume the habit should be done on the same day of the week as it was started
            if let startDate = habit.startDate {
                let startWeekday = calendar.component(.weekday, from: startDate)
                return weekday == startWeekday
            }
            return false
            
        case "custom":
            // Custom days format: "1,3,5" for Sun, Tue, Thu
            let customDays = habit.customDays?.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? []
            return customDays.contains(weekday)
            
        default:
            return false
        }
    }
    
    // MARK: - Core Data Saving Support
    
    func saveContext() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    // MARK: - Initial Setup
    
    func setupDefaultData() {
        // Check if we already have collections
        let collectionsFetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        
        do {
            let existingCollections = try container.viewContext.fetch(collectionsFetchRequest)
            
            if existingCollections.isEmpty {
                // Create default collections
                _ = createCollection(name: "Daily Log")
                _ = createCollection(name: "Monthly Log")
                _ = createCollection(name: "Future Log")
                _ = createCollection(name: "Habit Tracker")
                
                print("Created default collections")
            }
        } catch {
            print("Error checking for existing collections: \(error)")
        }
    }
}
