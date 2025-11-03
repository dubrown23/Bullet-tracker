//
//  CompleteHabitIntent.swift
//  BulletTrackerWidgets
//
//  Created by Dustin Brown on 10/30/25.
//

import AppIntents
import CoreData
import Foundation

// MARK: - Complete Habit Intent

struct CompleteHabitIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Habit"
    static var description = IntentDescription("Mark a habit as completed")
    
    @Parameter(title: "Habit ID")
    var habitID: String
    
    @Parameter(title: "Habit Name")
    var habitName: String
    
    init() {
        self.habitID = ""
        self.habitName = ""
    }
    
    init(habitID: String, habitName: String) {
        self.habitID = habitID
        self.habitName = habitName
    }
    
    func perform() async throws -> some IntentResult {
        let context = WidgetCoreDataManager.shared.viewContext
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    try self.toggleHabitCompletion(habitID: self.habitID, context: context)
                    
                    DispatchQueue.main.async {
                        continuation.resume(returning: .result())
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func toggleHabitCompletion(habitID: String, context: NSManagedObjectContext) throws {
        guard let habitUUID = UUID(uuidString: habitID) else {
            throw IntentError.invalidHabitID
        }
        
        // Find the habit
        let habitRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        habitRequest.predicate = NSPredicate(format: "id == %@", habitUUID as CVarArg)
        
        guard let habit = try context.fetch(habitRequest).first else {
            throw IntentError.habitNotFound
        }
        
        let today = Calendar.current.startOfDay(for: Date())
        
        // Find or create today's habit entry
        let entryRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        entryRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@",
                                           habit,
                                           today as CVarArg,
                                           Calendar.current.date(byAdding: .day, value: 1, to: today)! as CVarArg)
        
        let existingEntry = try context.fetch(entryRequest).first
        
        if let entry = existingEntry {
            // Toggle completion state
            let currentState = Int(entry.completionState)
            let nextState = getNextCompletionState(current: currentState, habit: habit)
            entry.completionState = Int16(nextState)
        } else {
            // Create new entry with success state
            let newEntry = HabitEntry(context: context)
            newEntry.id = UUID()
            newEntry.habit = habit
            newEntry.date = Date()
            newEntry.completionState = 1 // Success
            newEntry.details = nil
        }
        
        try context.save()
        
        // Reload widget timeline
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitTrackerWidget")
    }
    
    private func getNextCompletionState(current: Int, habit: Habit) -> Int {
        // For negative habits, only toggle between 0 (none) and 3 (attempted/relapse)
        if habit.isNegativeHabit {
            return current == 0 ? 3 : 0
        }
        
        // For habits without multiple states, toggle between 0 and 1
        if !habit.useMultipleStates {
            return current == 0 ? 1 : 0
        }
        
        // For habits with multiple states, cycle through: 0 -> 1 -> 2 -> 3 -> 0
        switch current {
        case 0: return 1 // None -> Success
        case 1: return 2 // Success -> Partial
        case 2: return 3 // Partial -> Attempted
        case 3: return 0 // Attempted -> None
        default: return 1 // Fallback to Success
        }
    }
}

// MARK: - Intent Errors

enum IntentError: Error, LocalizedError {
    case invalidHabitID
    case habitNotFound
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidHabitID:
            return "Invalid habit ID"
        case .habitNotFound:
            return "Habit not found"
        case .saveFailed:
            return "Failed to save changes"
        }
    }
}

// MARK: - Widget Center Import

import WidgetKit