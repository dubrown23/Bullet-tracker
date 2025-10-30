//
//  HabitDataRepository.swift
//  Bullet Tracker
//
//  Created by AI Assistant on 10/29/25.
//

import SwiftUI
import CoreData
import Combine

/// Centralized repository for habit data that efficiently manages Core Data operations
/// and provides optimized data access for habit tracking views
@MainActor
class HabitDataRepository: ObservableObject {
    // MARK: - Published Properties
    
    /// Dictionary mapping habit IDs to their entries organized by date
    @Published private(set) var habitEntries: [UUID: [Date: HabitEntry]] = [:]
    
    /// Currently loaded date range to avoid unnecessary reloads
    @Published private(set) var loadedDateRange: ClosedRange<Date>?
    
    /// Loading state for UI feedback
    @Published private(set) var isLoading = false
    
    // MARK: - Private Properties
    
    private var loadingTask: Task<Void, Never>?
    private let calendar = Calendar.current
    private let context = CoreDataManager.shared.container.viewContext
    
    // MARK: - Lifecycle
    
    deinit {
        loadingTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Loads habit entries for the specified habits and date range
    /// Uses efficient batch loading to minimize Core Data queries
    func loadEntries(for habits: [Habit], dateRange: ClosedRange<Date>) async {
        // Cancel any existing loading task
        loadingTask?.cancel()
        
        // Check if we already have this data loaded
        if let currentRange = loadedDateRange,
           currentRange.contains(dateRange.lowerBound) && currentRange.contains(dateRange.upperBound) {
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
        
        return HabitCompletionState(
            isCompleted: entry.completed,
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
            
            // Create predicate for batch loading all entries in date range
            let startDate = dateRange.lowerBound
            let endDate = self.calendar.date(byAdding: .day, value: 1, to: dateRange.upperBound)!
            
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
                print("Failed to load habit entries: \(error)")
            }
        }
    }
    
    private func processLoadedEntries(_ entries: [HabitEntry]) {
        // Clear existing data for reload
        var newEntries: [UUID: [Date: HabitEntry]] = [:]
        
        for entry in entries {
            guard let habit = entry.habit,
                  let habitId = habit.id,
                  let date = entry.date else { continue }
            
            let dayStart = calendar.startOfDay(for: date)
            
            if newEntries[habitId] == nil {
                newEntries[habitId] = [:]
            }
            newEntries[habitId]?[dayStart] = entry
        }
        
        habitEntries = newEntries
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
                    self.calendar.date(byAdding: .day, value: 1, to: date)! as NSDate
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
                print("Failed to update habit entry: \(error)")
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
                    self.calendar.date(byAdding: .day, value: 1, to: date)! as NSDate
                )
                fetchRequest.fetchLimit = 1
                
                if let entry = try self.context.fetch(fetchRequest).first {
                    self.context.delete(entry)
                    try self.context.save()
                }
            } catch {
                print("Failed to delete habit entry: \(error)")
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
        case 1: return .green     // Success
        case 2: return .yellow    // Partial
        case 3: return .red       // Attempted
        default: return .green    // Default
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