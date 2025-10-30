//
//  MigrationManager.swift
//  Bullet Tracker
//
//  Created on 6/5/2025.
//

import Foundation
import CoreData
import SwiftUI

/// Manages the migration of tasks and future entries in the bullet journal system
class MigrationManager: ObservableObject {
    // MARK: - Singleton
    
    static let shared = MigrationManager()
    
    // MARK: - Properties
    
    private let coreDataManager = CoreDataManager.shared
    private let lastMigrationKey = "lastMigrationDate"
    
    /// Published property to show alert for old tasks
    @Published var showOldTaskAlert = false
    @Published var oldTasksToReview: [JournalEntry] = []
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Main Migration Entry Point
    
    /// Performs daily migration when app comes to foreground
    func performDailyMigration() {
        // Check if we've already migrated today
        let lastMigration = UserDefaults.standard.object(forKey: lastMigrationKey) as? Date ?? Date.distantPast
        let calendar = Calendar.current
        
        if !calendar.isDateInToday(lastMigration) {
            // Perform migrations
            migrateIncompleteTasks()
            migrateFutureEntries()
            checkForOldTasks()
            
            // Check for month-end migration
            performMonthEndMigration()
            
            // Update last migration date
            UserDefaults.standard.set(Date(), forKey: lastMigrationKey)
        }
    }
    
    // MARK: - Task Migration
    
    /// Migrates incomplete tasks from previous days to today
    private func migrateIncompleteTasks() {
        let context = coreDataManager.container.viewContext
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Fetch all incomplete tasks from before today
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "entryType == %@ AND taskStatus == %@ AND date < %@ AND hasMigrated == false",
            EntryType.task.rawValue,
            TaskStatus.pending.rawValue,
            today as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        do {
            let incompleteTasks = try context.fetch(fetchRequest)
            
            if !incompleteTasks.isEmpty {
                // Process all tasks in single context operation for better performance
                for task in incompleteTasks {
                    migrateTask(task, to: today)
                }
                
                try context.save()
            }
        } catch {
            // Silent failure - migration will retry next time
        }
    }
    
    /// Migrates a single task to a new date
    private func migrateTask(_ task: JournalEntry, to date: Date) {
        let context = coreDataManager.container.viewContext
        
        // Mark the original task as migrated
        task.hasMigrated = true
        
        // Create new migrated task
        let newTask = JournalEntry(context: context)
        newTask.id = UUID()
        newTask.date = date
        newTask.entryType = task.entryType
        newTask.taskStatus = TaskStatus.pending.rawValue
        newTask.priority = task.priority
        newTask.collection = task.collection
        
        // Add migration prefix only if not already present
        let originalContent = task.content ?? ""
        if !originalContent.hasPrefix("→ ") {
            newTask.content = "→ \(originalContent)"
        } else {
            newTask.content = originalContent
        }
        
        // Track original date
        if let originalDate = task.originalDate {
            newTask.originalDate = originalDate
        } else {
            newTask.originalDate = task.date
        }
        
        // Copy tags
        if let tags = task.tags as? Set<Tag> {
            for tag in tags {
                newTask.addToTags(tag)
            }
        }
    }
    
    // MARK: - Future Entry Migration
    
    /// Migrates future entries that are due today or earlier
    private func migrateFutureEntries() {
        let context = coreDataManager.container.viewContext
        let calendar = Calendar.current
        let todayEnd = calendar.endOfDay(for: Date())
        
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "isFutureEntry == true AND scheduledDate <= %@ AND hasMigrated == false",
            todayEnd as NSDate
        )
        
        do {
            let dueEntries = try context.fetch(fetchRequest)
            
            if !dueEntries.isEmpty {
                for entry in dueEntries {
                    migrateFutureEntry(entry)
                }
                
                try context.save()
            }
        } catch {
            // Silent failure - migration will retry next time
        }
    }
    
    /// Migrates a single future entry to its scheduled date
    private func migrateFutureEntry(_ entry: JournalEntry) {
        // Mark as migrated (but keep in Future Log)
        entry.hasMigrated = true
        
        // Create copy in daily log
        let context = coreDataManager.container.viewContext
        let dailyEntry = JournalEntry(context: context)
        dailyEntry.id = UUID()
        dailyEntry.content = entry.content
        dailyEntry.entryType = entry.entryType
        dailyEntry.taskStatus = entry.taskStatus
        dailyEntry.priority = entry.priority
        dailyEntry.collection = entry.collection
        dailyEntry.date = entry.scheduledDate ?? Date()
        dailyEntry.isFutureEntry = false
        
        // Copy tags
        if let tags = entry.tags as? Set<Tag> {
            for tag in tags {
                dailyEntry.addToTags(tag)
            }
        }
    }
    
    // MARK: - Old Task Detection
    
    /// Checks for tasks older than 5 days and prompts user
    private func checkForOldTasks() {
        let context = coreDataManager.container.viewContext
        let calendar = Calendar.current
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: Date())!
        
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "entryType == %@ AND taskStatus == %@ AND date < %@",
            EntryType.task.rawValue,
            TaskStatus.pending.rawValue,
            fiveDaysAgo as NSDate
        )
        
        do {
            let oldTasks = try context.fetch(fetchRequest)
            
            if !oldTasks.isEmpty {
                DispatchQueue.main.async {
                    self.oldTasksToReview = oldTasks
                    self.showOldTaskAlert = true
                }
            }
        } catch {
            // Silent failure
        }
    }
    
    // MARK: - Month-End Migration
    
    /// Performs month-end migration when a new month begins
    func performMonthEndMigration() {
        let calendar = Calendar.current
        let now = Date()
        let currentMonth = calendar.component(.month, from: now)
        let currentYear = calendar.component(.year, from: now)
        
        // Check if we've already done this month's migration
        let lastMonthMigrationKey = "lastMonthMigration"
        let lastMigration = UserDefaults.standard.string(forKey: lastMonthMigrationKey) ?? ""
        let currentMonthKey = "\(currentYear)-\(currentMonth)"
        
        if lastMigration == currentMonthKey {
            return
        }
        
        // Get the previous month
        guard let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: now) else { return }
        let previousMonth = calendar.component(.month, from: previousMonthDate)
        let previousMonthYear = calendar.component(.year, from: previousMonthDate)
        
        // Perform the migration
        migrateMonthEntries(year: previousMonthYear, month: previousMonth)
        
        // Update last migration date
        UserDefaults.standard.set(currentMonthKey, forKey: lastMonthMigrationKey)
    }
    
    /// Migrates all entries from a specific month to the year archive
    private func migrateMonthEntries(year: Int, month: Int) {
        let context = coreDataManager.container.viewContext
        let calendar = Calendar.current
        
        // Get month date range
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        
        guard let monthStart = calendar.date(from: components),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return
        }
        
        // Fetch all entries from the month
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@ AND isFutureEntry == false",
            monthStart as NSDate,
            calendar.endOfDay(for: monthEnd) as NSDate
        )
        
        do {
            let monthEntries = try context.fetch(fetchRequest)
            
            if monthEntries.isEmpty {
                return
            }
            
            // Get or create the month collection in the year
            let monthCollection = getOrCreateMonthArchiveCollection(year: year, month: month)
            
            // Copy entries to the archive collection
            for entry in monthEntries {
                // Don't migrate if already in an archive
                if let collectionName = entry.collection?.name,
                   collectionName.contains("/") {
                    continue
                }
                
                // Create a copy for the archive
                let archiveEntry = JournalEntry(context: context)
                archiveEntry.id = UUID()
                archiveEntry.content = entry.content
                archiveEntry.entryType = entry.entryType
                archiveEntry.taskStatus = entry.taskStatus
                archiveEntry.priority = entry.priority
                archiveEntry.date = entry.date
                archiveEntry.collection = monthCollection
                archiveEntry.originalDate = entry.originalDate
                archiveEntry.hasMigrated = entry.hasMigrated
                archiveEntry.isFutureEntry = false
                
                // Copy tags
                if let tags = entry.tags as? Set<Tag> {
                    for tag in tags {
                        archiveEntry.addToTags(tag)
                    }
                }
            }
            
            try context.save()
            
        } catch {
            // Silent failure
        }
    }
    
    /// Gets or creates a month archive collection
    private func getOrCreateMonthArchiveCollection(year: Int, month: Int) -> Collection {
        let context = coreDataManager.container.viewContext
        let monthName = Calendar.current.monthSymbols[month - 1]
        let collectionName = "\(year)/\(monthName)"
        
        // Check if it already exists
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND isAutomatic == true", collectionName)
        fetchRequest.fetchLimit = 1
        
        do {
            if let existing = try context.fetch(fetchRequest).first {
                return existing
            }
        } catch {
            // Continue to create new
        }
        
        // Create new month archive collection
        let collection = Collection(context: context)
        collection.id = UUID()
        collection.name = collectionName
        collection.isAutomatic = true
        collection.collectionType = "month_archive"
        collection.sortOrder = Int32(month)
        
        return collection
    }
    
    // MARK: - Public Methods for UI
    
    /// Moves old tasks to Future Log
    func moveTasksToFutureLog(_ tasks: [JournalEntry]) {
        let context = coreDataManager.container.viewContext
        
        for task in tasks {
            // Convert to future entry
            task.isFutureEntry = true
            task.scheduledDate = nil  // No specific date
            task.hasMigrated = false
            
            // Remove migration prefix if present
            if let content = task.content, content.hasPrefix("→ ") {
                task.content = String(content.dropFirst(2))
            }
        }
        
        do {
            try context.save()
        } catch {
            // Silent failure
        }
    }
    
    /// Reschedules a task to a specific date
    func rescheduleTask(_ task: JournalEntry, to date: Date) {
        task.date = date
        task.originalDate = nil  // Reset age tracking
        
        // Remove migration prefix if present
        if let content = task.content, content.hasPrefix("→ ") {
            task.content = String(content.dropFirst(2))
        }
        
        do {
            try coreDataManager.container.viewContext.save()
        } catch {
            // Silent failure
        }
    }
    
    // MARK: - Debug Methods
    
    /// Force reset migration date for testing
    func resetMigrationDateForTesting() {
        UserDefaults.standard.removeObject(forKey: lastMigrationKey)
        UserDefaults.standard.removeObject(forKey: "lastMonthMigration")
    }
}

// MARK: - Helper Extensions

extension Array {
    /// Splits array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension Calendar {
    /// Returns the end of day for a given date
    func endOfDay(for date: Date) -> Date {
        var components = dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return self.date(from: components) ?? date
    }
}
