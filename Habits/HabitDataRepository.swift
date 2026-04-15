//
//  HabitDataRepository.swift
//  Bullet Tracker
//
//  Created by AI Assistant on 10/29/25.
//

import SwiftUI
import CoreData
import WidgetKit

/// Centralized repository for habit data that efficiently manages Core Data operations
/// and provides optimized data access for habit tracking views
@MainActor
@Observable
class HabitDataRepository {
    // MARK: - Properties

    /// Dictionary mapping habit IDs to their entries organized by date
    private(set) var habitEntries: [UUID: [Date: HabitEntry]] = [:]

    /// Currently loaded date range to avoid unnecessary reloads
    private(set) var loadedDateRange: ClosedRange<Date>?

    /// Loading state for UI feedback
    private(set) var isLoading = false

    // MARK: - Private Properties

    private var loadingTask: Task<Void, Never>?
    private let calendar = Calendar.current
    private let context = CoreDataManager.shared.container.viewContext
    private let notificationCenter = NotificationCenter.default

    // MARK: - Lifecycle

    init() {
        // Listen for Core Data remote changes (from CloudKit sync or widget)
        notificationCenter.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.contextDidSave(notification)
            }
        }
    }

    // MARK: - Notification Handlers

    private func contextDidSave(_ notification: Notification) {
        // Check if this is a save from a different context (like the widget)
        guard let savedContext = notification.object as? NSManagedObjectContext,
              savedContext != context else {
            return // Ignore saves from our own context
        }

        // Merge the changes into our context
        context.mergeChanges(fromContextDidSave: notification)
        
        // Check if any HabitEntry objects were changed
        let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? Set()
        let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? Set()
        let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? Set()
        
        let allChangedObjects = insertedObjects.union(updatedObjects).union(deletedObjects)
        let hasHabitEntryChanges = allChangedObjects.contains { $0 is HabitEntry }
        
        if hasHabitEntryChanges {
            Task { @MainActor in
                // Clear cache to force reload on next access
                self.loadedDateRange = nil
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads habit entries for the specified habits and date range
    /// Uses efficient batch loading to minimize Core Data queries
    func loadEntries(for habits: [Habit], dateRange: ClosedRange<Date>) async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Check if we already have this data loaded
        // Always load if cache is empty (app launch scenario)
        let shouldSkipLoad: Bool
        if habitEntries.isEmpty {
            shouldSkipLoad = false // Always load on first run
        } else if let currentRange = loadedDateRange {
            // Only skip if the new range is completely contained within the loaded range
            shouldSkipLoad = currentRange.contains(dateRange.lowerBound) && currentRange.contains(dateRange.upperBound)
        } else {
            shouldSkipLoad = false
        }
        
        if shouldSkipLoad {
            return // Already loaded
        }
        
        // Extract habit ObjectIDs to pass safely to background context
        let habitObjectIDs = habits.compactMap { $0.objectID }
        
        loadingTask = Task {
            await performBatchLoad(habitObjectIDs: habitObjectIDs, dateRange: dateRange)
        }
        
        await loadingTask?.value
    }
    
    /// Gets a habit entry for a specific habit and date
    func getEntry(for habit: Habit, on date: Date) -> HabitEntry? {
        guard let habitId = habit.id else { return nil }
        let dayStart = calendar.startOfDay(for: date)
        return habitEntries[habitId]?[dayStart]
    }
    
    /// Gets the completion state for a habit on a specific date
    func getCompletionState(for habit: Habit, on date: Date) -> HabitCompletionState {
        guard let entry = getEntry(for: habit, on: date) else {
            return HabitCompletionState(isCompleted: false, state: 0, hasDetails: false)
        }
        
        let state = (entry.value(forKey: "completionState") as? Int) ?? 1
        let hasDetails = checkForMeaningfulDetails(in: entry, habit: habit, state: state)
        
        // Fix: isCompleted should be true when state > 0, regardless of entry.completed
        let isCompleted = state > 0
        
        return HabitCompletionState(
            isCompleted: isCompleted,
            state: state,
            hasDetails: hasDetails
        )
    }
    
    /// Updates or creates a habit entry with optimistic UI updates
    func updateEntry(for habit: Habit, on date: Date, completed: Bool, state: Int) {
        guard let habitId = habit.id else { return }
        let dayStart = calendar.startOfDay(for: date)
        
        // Optimistic update for immediate UI feedback
        if habitEntries[habitId] == nil {
            habitEntries[habitId] = [:]
        }
        
        // Update local cache immediately
        if let existingEntry = habitEntries[habitId]?[dayStart] {
            existingEntry.completed = completed
            existingEntry.setValue(state, forKey: "completionState")
        } else if completed {
            // Create temporary entry for optimistic update
            let tempEntry = HabitEntry(context: context)
            tempEntry.id = UUID()
            tempEntry.date = dayStart
            tempEntry.completed = completed
            tempEntry.setValue(state, forKey: "completionState")
            tempEntry.habit = habit
            
            habitEntries[habitId]?[dayStart] = tempEntry
        }
        
        // Perform actual Core Data update
        let habitObjectID = habit.objectID
        Task {
            await performCoreDataUpdate(habitObjectID: habitObjectID, on: dayStart, completed: completed, state: state)
            
            // Only refresh widget for today's date to avoid excessive refreshes
            if Calendar.current.isDate(dayStart, inSameDayAs: Date()) {
                WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
            }
        }
    }

    /// Removes a habit entry
    func removeEntry(for habit: Habit, on date: Date) {
        guard let habitId = habit.id else { return }
        let dayStart = calendar.startOfDay(for: date)

        // Optimistic update
        habitEntries[habitId]?[dayStart] = nil

        // Perform actual Core Data deletion
        let habitObjectID = habit.objectID
        Task {
            await performCoreDataDeletion(habitObjectID: habitObjectID, on: dayStart)

            // Only refresh widget for today's date to avoid excessive refreshes
            if Calendar.current.isDate(dayStart, inSameDayAs: Date()) {
                WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
            }
        }
    }
    
    /// Invalidates cached data for a specific habit and date
    func invalidateCache(for habit: Habit, on date: Date) {
        guard let habitId = habit.id else { return }
        let dayStart = calendar.startOfDay(for: date)
        habitEntries[habitId]?[dayStart] = nil
    }
    
    /// Clears all cached data
    func clearCache() {
        habitEntries.removeAll()
        loadedDateRange = nil
    }
    
    /// Forces a refresh of data for the currently loaded habits and date range
    func forceRefresh(for habits: [Habit], dateRange: ClosedRange<Date>) async {
        loadedDateRange = nil // Clear the loaded range to force reload
        await loadEntries(for: habits, dateRange: dateRange)
    }
    
    // MARK: - Private Methods
    
    private func performBatchLoad(habitObjectIDs: [NSManagedObjectID], dateRange: ClosedRange<Date>) async {
        isLoading = true
        defer { isLoading = false }
        
        await context.perform {
            // Convert ObjectIDs back to Habit objects in this context
            let habits = habitObjectIDs.compactMap { objectID in
                try? self.context.existingObject(with: objectID) as? Habit
            }
            
            guard !habits.isEmpty else { return }
            
            let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
            
            // Use robust date handling for the query
            // Ensure we're using start of day for both bounds
            let startDate = self.calendar.startOfDay(for: dateRange.lowerBound)
            guard let nextDay = self.calendar.date(byAdding: .day, value: 1, to: dateRange.upperBound) else { return }
            let endDate = self.calendar.startOfDay(for: nextDay)
            
            fetchRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND habit IN %@",
                startDate as NSDate,
                endDate as NSDate,
                habits
            )
            
            // Optimize fetch request
            fetchRequest.relationshipKeyPathsForPrefetching = ["habit"]
            fetchRequest.returnsObjectsAsFaults = false
            
            do {
                let entries = try self.context.fetch(fetchRequest)
                
                // Update main thread
                Task { @MainActor in
                    self.processLoadedEntries(entries)
                    self.loadedDateRange = dateRange
                }
            } catch {
                debugLog("Failed to load habit entries: \(error.localizedDescription)")
            }
        }
    }
    
    private func processLoadedEntries(_ entries: [HabitEntry]) {
        // Merge new entries with existing cache instead of clearing everything
        var updatedEntries = habitEntries
        
        for entry in entries {
            guard let habit = entry.habit,
                  let habitId = habit.id,
                  let date = entry.date else { continue }
            
            let dayStart = calendar.startOfDay(for: date)
            
            if updatedEntries[habitId] == nil {
                updatedEntries[habitId] = [:]
            }
            updatedEntries[habitId]?[dayStart] = entry
        }
        
        habitEntries = updatedEntries
    }
    
    private func performCoreDataUpdate(habitObjectID: NSManagedObjectID, on date: Date, completed: Bool, state: Int) async {
        await context.perform {
            do {
                guard let habit = try? self.context.existingObject(with: habitObjectID) as? Habit else { return }
                
                let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "habit == %@ AND date >= %@ AND date < %@",
                    habit,
                    date as NSDate,
                    (self.calendar.date(byAdding: .day, value: 1, to: date) ?? date) as NSDate
                )
                fetchRequest.fetchLimit = 1
                
                let results = try self.context.fetch(fetchRequest)
                
                if completed {
                    let entry = results.first ?? HabitEntry(context: self.context)
                    if results.isEmpty {
                        entry.id = UUID()
                        entry.date = date
                        entry.habit = habit
                    }
                    entry.completed = true
                    entry.setValue(state, forKey: "completionState")
                } else {
                    // Remove entry if uncompleted
                    if let entry = results.first {
                        self.context.delete(entry)
                    }
                }
                
                try self.context.save()
            } catch {
                debugLog("Failed to update habit entry: \(error.localizedDescription)")
            }
        }
    }
    
    private func performCoreDataDeletion(habitObjectID: NSManagedObjectID, on date: Date) async {
        await context.perform {
            do {
                guard let habit = try? self.context.existingObject(with: habitObjectID) as? Habit else { return }
                
                let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "habit == %@ AND date >= %@ AND date < %@",
                    habit,
                    date as NSDate,
                    (self.calendar.date(byAdding: .day, value: 1, to: date) ?? date) as NSDate
                )
                fetchRequest.fetchLimit = 1
                
                if let entry = try self.context.fetch(fetchRequest).first {
                    self.context.delete(entry)
                    try self.context.save()
                }
            } catch {
                debugLog("Failed to delete habit entry: \(error.localizedDescription)")
            }
        }
    }
    
    private func checkForMeaningfulDetails(in entry: HabitEntry, habit: Habit, state: Int) -> Bool {
        guard let detailsString = entry.details, !detailsString.isEmpty else {
            return false
        }
        
        // Try to parse as JSON
        guard let data = detailsString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Plain text details
            return !detailsString.isEmpty
        }
        
        let isWorkoutHabit = checkIsWorkoutHabit(habit)
        let useMultipleStates = (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
        
        // For workout habits with multiple states
        if isWorkoutHabit && useMultipleStates {
            // Only show indicator for success state with actual data
            return state == 1 &&
                   (!((json["types"] as? [String])?.isEmpty ?? true) ||
                    !((json["duration"] as? String)?.isEmpty ?? true))
        }
        
        // For other habits, check if notes exist
        return !((json["notes"] as? String)?.isEmpty ?? true)
    }
    
    private func checkIsWorkoutHabit(_ habit: Habit) -> Bool {
        let workoutKeywords = ["workout", "exercise", "gym", "fitness", "training", "movement"]
        let habitName = (habit.name ?? "").lowercased()
        let detailType = (habit.value(forKey: "detailType") as? String) ?? ""
        
        return workoutKeywords.contains { habitName.contains($0) } || detailType == "workout"
    }
}

// MARK: - Supporting Types

/// Represents the completion state of a habit on a specific date
struct HabitCompletionState {
    let isCompleted: Bool
    let state: Int // 0: none, 1: success, 2: partial, 3: failure
    let hasDetails: Bool
    
    var stateColor: Color {
        guard isCompleted else { return .clear }

        switch state {
        case 1: return Color(hex: "#4CAF50")   // Success - warm green
        case 2: return Color(hex: "#FFB300")   // Partial - warm yellow
        case 3: return Color(hex: "#EF5350")   // Attempted - soft red
        default: return Color(hex: "#4CAF50")  // Default
        }
    }
    
    var stateIcon: String {
        switch state {
        case 1: return "checkmark"              // Success
        case 2: return "circle.lefthalf.filled" // Partial
        case 3: return "xmark"                  // Failed
        default: return "checkmark"             // Default
        }
    }
}
