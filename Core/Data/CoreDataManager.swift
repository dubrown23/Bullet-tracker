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
    
    // MARK: - Initialization
    
    private init() {
        container = NSPersistentCloudKitContainer(name: "Bullet_Tracker")
        
        #if DEBUG
        print("🔵 CloudKit Container initialized")
        #endif
        
        configureContainer()
        loadPersistentStores()
        configureViewContext()
    }
    
    // MARK: - Container Configuration
    
    /// Configures the container for CloudKit sync
    private func configureContainer() {
        guard let description = container.persistentStoreDescriptions.first else { return }
        
        // Enable history tracking and remote notifications for CloudKit sync
        description.setOption(true as NSNumber,
                            forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber,
                            forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        #if DEBUG
        print("📱 Store Configuration:")
        print("   - History Tracking: Enabled")
        print("   - Remote Notifications: Enabled")
        #endif
    }
    
    /// Loads the persistent stores
    private func loadPersistentStores() {
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            #if DEBUG
            print("✅ CloudKit Store loaded successfully")
            print("📱 Store URL: \(storeDescription.url?.absoluteString ?? "No URL")")
            print("☁️ CloudKit enabled: \(storeDescription.cloudKitContainerOptions != nil)")
            #endif
        }
    }
    
    /// Configures the view context
    private func configureViewContext() {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Core Data Saving
    
    /// Saves the view context if there are changes
    func saveContext() {
        guard container.viewContext.hasChanges else {
            #if DEBUG
            print("ℹ️ No changes to save")
            #endif
            return
        }
        
        do {
            #if DEBUG
            print("💾 Saving context with changes...")
            #endif
            try container.viewContext.save()
            #if DEBUG
            print("✅ Context saved successfully")
            #endif
        } catch {
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    // MARK: - Initial Setup
    
    /// Sets up default data on first launch
    func setupDefaultData() {
        // No longer create default collections - we use automatic collections now
        #if DEBUG
        print("✅ Default data setup complete (no collections created)")
        #endif
    }
}

// MARK: - Journal Entry Management

extension CoreDataManager {
    /// Creates a new journal entry
    /// - Parameters:
    ///   - content: The text content of the entry
    ///   - entryType: The type of entry (task, event, note)
    ///   - taskStatus: The status if this is a task
    ///   - date: The date of the entry
    ///   - priority: Whether this is a priority item
    ///   - collection: The collection this entry belongs to
    ///   - tags: Tags associated with this entry
    /// - Returns: The created journal entry
    func createJournalEntry(
        content: String,
        entryType: String,
        taskStatus: String?,
        date: Date,
        priority: Bool,
        collection: Collection? = nil,
        tags: [Tag] = []
    ) -> JournalEntry {
        let entry = JournalEntry(context: container.viewContext)
        entry.id = UUID()
        entry.content = content
        entry.entryType = entryType
        entry.taskStatus = taskStatus
        entry.date = date
        entry.priority = priority
        entry.collection = collection
        
        tags.forEach { entry.addToTags($0) }
        
        saveContext()
        return entry
    }
    
    /// Updates an existing journal entry
    func updateJournalEntry(
        _ entry: JournalEntry,
        content: String,
        entryType: String,
        taskStatus: String?,
        priority: Bool,
        collection: Collection? = nil,
        tags: [Tag] = []
    ) {
        entry.content = content
        entry.entryType = entryType
        entry.taskStatus = taskStatus
        entry.priority = priority
        entry.collection = collection
        
        // Update tags
        if let currentTags = entry.tags as? Set<Tag> {
            currentTags.forEach { entry.removeFromTags($0) }
        }
        tags.forEach { entry.addToTags($0) }
        
        saveContext()
    }
    
    /// Deletes a journal entry
    func deleteJournalEntry(_ entry: JournalEntry) {
        container.viewContext.delete(entry)
        saveContext()
    }
    
    /// Fetches entries for a specific date
    func fetchEntriesForDate(_ date: Date) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching entries: \(error)")
            #endif
            return []
        }
    }
    
    /// Fetches entries for a specific collection
    func fetchEntriesForCollection(_ collection: Collection) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching entries: \(error)")
            #endif
            return []
        }
    }
    
    /// Searches entries by content or tag
    func searchEntries(query: String) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        if !query.isEmpty {
            let contentPredicate = NSPredicate(format: "content CONTAINS[cd] %@", query)
            let tagsPredicate = NSPredicate(format: "ANY tags.name CONTAINS[cd] %@", query)
            fetchRequest.predicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [contentPredicate, tagsPredicate]
            )
        }
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error searching entries: \(error)")
            #endif
            return []
        }
    }
}

// MARK: - Collection Management

extension CoreDataManager {
    /// Creates a new collection
    func createCollection(name: String) -> Collection {
        let collection = Collection(context: container.viewContext)
        collection.id = UUID()
        collection.name = name
        saveContext()
        return collection
    }
    
    /// Updates a collection's name
    func updateCollection(_ collection: Collection, name: String) {
        collection.name = name
        saveContext()
    }
    
    /// Deletes a collection
    func deleteCollection(_ collection: Collection) {
        container.viewContext.delete(collection)
        saveContext()
    }
    
    /// Fetches all collections sorted by name
    func fetchAllCollections() -> [Collection] {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching collections: \(error)")
            #endif
            return []
        }
    }
}

// MARK: - Tag Management

extension CoreDataManager {
    /// Gets an existing tag or creates a new one
    func getOrCreateTag(name: String) -> Tag {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try container.viewContext.fetch(fetchRequest)
            if let existingTag = results.first {
                return existingTag
            }
        } catch {
            #if DEBUG
            print("❌ Error fetching tag: \(error)")
            #endif
        }
        
        // Create new tag
        let newTag = Tag(context: container.viewContext)
        newTag.id = UUID()
        newTag.name = name
        saveContext()
        return newTag
    }
    
    /// Fetches all tags sorted by name
    func fetchAllTags() -> [Tag] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching tags: \(error)")
            #endif
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
        #if DEBUG
        print("🆕 Creating habit: \(name)")
        #endif
        
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
            #if DEBUG
            print("❌ Error determining habit count: \(error)")
            #endif
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
            #if DEBUG
            print("❌ Error fetching habits: \(error)")
            #endif
            return []
        }
    }
    
    /// Fetches habits in a specific collection
    func fetchHabitsInCollection(_ collection: Collection) -> [Habit] {
        let fetchRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching habits: \(error)")
            #endif
            return []
        }
    }
}

// MARK: - Habit Entry Management

extension CoreDataManager {
    /// Toggles a habit entry for a specific date
    /// - Parameters:
    ///   - habit: The habit to toggle
    ///   - date: The date to toggle for
    /// - Returns: The updated or created entry, or nil if deleted
    func toggleHabitEntry(habit: Habit, date: Date) -> HabitEntry? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        do {
            let results = try container.viewContext.fetch(fetchRequest)
            
            if let existingEntry = results.first {
                // Toggle existing entry
                existingEntry.completed = !existingEntry.completed
                
                if !existingEntry.completed {
                    // Delete if now uncompleted
                    container.viewContext.delete(existingEntry)
                    saveContext()
                    return nil
                } else {
                    saveContext()
                    return existingEntry
                }
            } else {
                // Create new completed entry
                let newEntry = HabitEntry(context: container.viewContext)
                newEntry.id = UUID()
                newEntry.date = date
                newEntry.completed = true
                newEntry.habit = habit
                
                saveContext()
                return newEntry
            }
        } catch {
            #if DEBUG
            print("❌ Error toggling habit entry: \(error)")
            #endif
            return nil
        }
    }
    
    /// Gets all habit entries for a specific date
    func getHabitEntriesForDate(_ date: Date) -> [HabitEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching habit entries: \(error)")
            #endif
            return []
        }
    }
    
    /// Gets habit entries for a date range
    func getHabitEntriesForDateRange(start: Date, end: Date) -> [HabitEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: end) else {
            return []
        }
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching habit entries: \(error)")
            #endif
            return []
        }
    }
    
    /// Calculates the completion rate for a habit
    func getCompletionRateForHabit(_ habit: Habit, daysBack: Int = 30) -> Double {
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -daysBack, to: endDate) else {
            return 0
        }
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date <= %@ AND completed == %@",
            habit,
            startDate as NSDate,
            endDate as NSDate,
            NSNumber(value: true)
        )
        
        do {
            let completedCount = try container.viewContext.count(for: fetchRequest)
            
            // Calculate expected days
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
            #if DEBUG
            print("❌ Error calculating habit completion rate: \(error)")
            #endif
            return 0
        }
    }
}

// MARK: - Private Helper Methods

private extension CoreDataManager {
    /// Determines if a habit should be performed on a given date based on its frequency
    func shouldPerformHabit(_ habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday, 7 = Saturday
        
        switch habit.frequency {
        case "daily":
            return true
            
        case "weekdays":
            return (2...6).contains(weekday) // Monday-Friday
            
        case "weekends":
            return weekday == 1 || weekday == 7 // Sunday or Saturday
            
        case "weekly":
            // Same day of week as start date
            guard let startDate = habit.startDate else { return false }
            let startWeekday = calendar.component(.weekday, from: startDate)
            return weekday == startWeekday
            
        case "custom":
            // Parse custom days: "1,3,5" for Sun, Tue, Thu
            let customDays = habit.customDays?
                .components(separatedBy: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? []
            return customDays.contains(weekday)
            
        default:
            return false
        }
    }
}

// MARK: - Future Entry Management

extension CoreDataManager {
    /// Fetches future entries scheduled for a specific month
    func fetchFutureEntriesForMonth(year: Int, month: Int) -> [JournalEntry] {
        let calendar = Calendar.current
        let startComponents = DateComponents(year: year, month: month, day: 1)
        guard let startDate = calendar.date(from: startComponents) else { return [] }
        
        let endComponents = DateComponents(month: 1)
        guard let endDate = calendar.date(byAdding: endComponents, to: startDate) else { return [] }
        
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isFutureEntry == true AND scheduledDate >= %@ AND scheduledDate < %@ AND hasMigrated == false",
                                           startDate as NSDate, endDate as NSDate)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "scheduledDate", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching future entries: \(error)")
            #endif
            return []
        }
    }
    
    /// Migrates incomplete tasks from one date to another
    func migrateIncompleteTasks(from: Date, to: Date) {
        let calendar = Calendar.current
        let fromStart = calendar.startOfDay(for: from)
        let fromEnd = calendar.date(byAdding: .day, value: 1, to: fromStart)!
        
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "entryType == %@ AND taskStatus == %@ AND date >= %@ AND date < %@ AND hasMigrated == false",
                                           "task", "pending", fromStart as NSDate, fromEnd as NSDate)
        
        do {
            let tasks = try container.viewContext.fetch(fetchRequest)
            
            #if DEBUG
            if !tasks.isEmpty {
                print("📋 Migrating \(tasks.count) incomplete tasks from \(fromStart) to \(to)")
            }
            #endif
            
            for task in tasks {
                // Mark old task as migrated
                task.hasMigrated = true
                
                // Create new task for today
                let newTask = JournalEntry(context: container.viewContext)
                newTask.id = UUID()
                newTask.content = task.content
                newTask.entryType = task.entryType
                newTask.taskStatus = "pending"
                newTask.date = to
                newTask.collection = task.collection
                newTask.priority = task.priority
                
                // If this is the first migration, set originalDate
                if task.originalDate == nil {
                    newTask.originalDate = task.date
                } else {
                    newTask.originalDate = task.originalDate
                }
                
                // Copy tags
                if let tags = task.tags {
                    for tag in tags {
                        newTask.addToTags(tag as! Tag)
                    }
                }
            }
            
            if !tasks.isEmpty {
                saveContext()
            }
        } catch {
            #if DEBUG
            print("❌ Error migrating tasks: \(error)")
            #endif
        }
    }
    
    /// Migrates future entries that are due
    func migrateDueFutureEntries() {
        let today = Date()
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: today)
        
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isFutureEntry == true AND scheduledDate <= %@ AND hasMigrated == false",
                                           todayStart as NSDate)
        
        do {
            let dueEntries = try container.viewContext.fetch(fetchRequest)
            
            #if DEBUG
            if !dueEntries.isEmpty {
                print("📅 Migrating \(dueEntries.count) due future entries")
            }
            #endif
            
            for entry in dueEntries {
                // Mark as migrated
                entry.hasMigrated = true
                entry.isFutureEntry = false
                
                // Update date to scheduled date or today if no scheduled date
                if let scheduledDate = entry.scheduledDate {
                    entry.date = scheduledDate
                } else {
                    entry.date = todayStart
                }
            }
            
            if !dueEntries.isEmpty {
                saveContext()
            }
        } catch {
            #if DEBUG
            print("❌ Error migrating future entries: \(error)")
            #endif
        }
    }
}
// MARK: - Collection Sorting

extension CoreDataManager {
    /// Fetches all collections sorted by type and order
    func fetchAllCollectionsSorted() -> [Collection] {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        
        // Sort by sortOrder first, then by name
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching sorted collections: \(error)")
            #endif
            return []
        }
    }
}
// MARK: - Migration Support Methods

extension CoreDataManager {
    /// Fetches incomplete tasks from before a specific date
    func fetchIncompleteTasks(before date: Date) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "entryType == %@ AND taskStatus == %@ AND date < %@ AND hasMigrated == false",
            EntryType.task.rawValue,
            TaskStatus.pending.rawValue,
            date as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching incomplete tasks: \(error)")
            #endif
            return []
        }
    }
    
    /// Creates a migrated copy of a task
    func createMigratedTask(from originalTask: JournalEntry, to date: Date) -> JournalEntry {
        let newTask = JournalEntry(context: container.viewContext)
        newTask.id = UUID()
        newTask.date = date
        newTask.entryType = originalTask.entryType
        newTask.taskStatus = TaskStatus.pending.rawValue
        newTask.priority = originalTask.priority
        newTask.collection = originalTask.collection
        
        // Add migration prefix if not already present
        let originalContent = originalTask.content ?? ""
        if !originalContent.hasPrefix("→ ") {
            newTask.content = "→ \(originalContent)"
        } else {
            newTask.content = originalContent
        }
        
        // Track original date
        if let existingOriginalDate = originalTask.originalDate {
            newTask.originalDate = existingOriginalDate
        } else {
            newTask.originalDate = originalTask.date
        }
        
        // Copy tags
        if let tags = originalTask.tags as? Set<Tag> {
            for tag in tags {
                newTask.addToTags(tag)
            }
        }
        
        // Mark original as migrated
        originalTask.hasMigrated = true
        
        return newTask
    }
    
    /// Fetches future entries that are due by a specific date
    func fetchDueFutureEntries(by date: Date) -> [JournalEntry] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "isFutureEntry == true AND scheduledDate <= %@ AND hasMigrated == false",
            date as NSDate
        )
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("❌ Error fetching due future entries: \(error)")
            #endif
            return []
        }
    }
    
    /// Creates a daily log copy of a future entry
    func createDailyEntryFromFuture(_ futureEntry: JournalEntry) -> JournalEntry {
        let dailyEntry = JournalEntry(context: container.viewContext)
        dailyEntry.id = UUID()
        dailyEntry.content = futureEntry.content
        dailyEntry.entryType = futureEntry.entryType
        dailyEntry.taskStatus = futureEntry.taskStatus
        dailyEntry.priority = futureEntry.priority
        dailyEntry.collection = futureEntry.collection
        dailyEntry.date = futureEntry.scheduledDate ?? Date()
        dailyEntry.isFutureEntry = false
        
        // Copy tags
        if let tags = futureEntry.tags as? Set<Tag> {
            for tag in tags {
                dailyEntry.addToTags(tag)
            }
        }
        
        // Mark future entry as migrated (but keep it in Future Log)
        futureEntry.hasMigrated = true
        
        return dailyEntry
    }
    
    /// Batch save with error handling
    func performBatchSave() {
        guard container.viewContext.hasChanges else { return }
        
        do {
            try container.viewContext.save()
            #if DEBUG
            print("✅ Batch save completed successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error during batch save: \(error)")
            #endif
            // Rollback changes on error
            container.viewContext.rollback()
        }
    }
    
    /// Gets the last migration date from UserDefaults
    func getLastMigrationDate() -> Date? {
        UserDefaults.standard.object(forKey: "lastMigrationDate") as? Date
    }
    
    /// Sets the last migration date in UserDefaults
    func setLastMigrationDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "lastMigrationDate")
    }
}

// MARK: - Year Collection Management (Phase 5)

extension CoreDataManager {
    /// Gets or creates a year collection
    func getOrCreateYearCollection(year: Int) -> Collection? {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        let yearString = String(year)
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND isAutomatic == %@",
                                           yearString, NSNumber(value: true))
        fetchRequest.fetchLimit = 1
        
        do {
            if let existingCollection = try container.viewContext.fetch(fetchRequest).first {
                return existingCollection
            } else {
                // Create new year collection
                let yearCollection = Collection(context: container.viewContext)
                yearCollection.id = UUID()
                yearCollection.name = yearString
                yearCollection.isAutomatic = true
                yearCollection.collectionType = "year"
                yearCollection.sortOrder = Int32(year)
                
                saveContext()
                return yearCollection
            }
        } catch {
            #if DEBUG
            print("❌ Error getting/creating year collection: \(error)")
            #endif
            return nil
        }
    }
}
