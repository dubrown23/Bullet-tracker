//
//  CoreDataManager+HabitDetails.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import Foundation
import CoreData

// MARK: - Habit Entry Details Management

extension CoreDataManager {
    // MARK: - Public Methods
    
    /// Gets the details string for a habit entry on a specific date
    /// - Parameters:
    ///   - habit: The habit to get details for
    ///   - date: The date to check
    /// - Returns: The details JSON string if found, nil otherwise
    func getHabitEntryDetails(habit: Habit, date: Date) -> String? {
        guard let entry = fetchHabitEntry(for: habit, on: date) else {
            return nil
        }
        
        return entry.value(forKey: "details") as? String
    }
    
    /// Updates or creates a habit entry with details for a specific date
    /// - Parameters:
    ///   - habit: The habit to update
    ///   - date: The date to update
    ///   - details: The details JSON string to save
    /// - Returns: The updated or created habit entry
    func updateHabitEntryDetails(habit: Habit, date: Date, details: String) -> HabitEntry? {
        if let existingEntry = fetchHabitEntry(for: habit, on: date) {
            // Update existing entry
            existingEntry.setValue(details, forKey: "details")
            saveContext()
            return existingEntry
        } else {
            // Create new entry with details
            return createHabitEntry(for: habit, on: date, with: details)
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Fetches a habit entry for a specific habit and date
    private func fetchHabitEntry(for habit: Habit, on date: Date) -> HabitEntry? {
        let (startOfDay, endOfDay) = dayBounds(for: date)
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.fetchLimit = 1
        
        do {
            return try container.viewContext.fetch(fetchRequest).first
        } catch {
            return nil
        }
    }
    
    /// Creates a new habit entry with details
    private func createHabitEntry(for habit: Habit, on date: Date, with details: String) -> HabitEntry {
        let newEntry = HabitEntry(context: container.viewContext)
        newEntry.id = UUID()
        newEntry.date = date
        newEntry.completed = true
        newEntry.setValue(details, forKey: "details")
        newEntry.habit = habit
        
        saveContext()
        return newEntry
    }
    
    /// Gets the start and end of day for a given date
    private func dayBounds(for date: Date) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return (startOfDay, endOfDay)
    }
}
