//
//  CoreDataManager+HabitDetails.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

//
//  CoreDataManager+HabitEntryDetails.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import Foundation
import CoreData

// This extension adds methods specifically for accessing and updating
// habit entry details (separate from the habit tracking methods)
extension CoreDataManager {
    // Get details for a habit entry on a specific date
    func getHabitEntryDetails(habit: Habit, date: Date) -> String? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@", habit, startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let results = try container.viewContext.fetch(fetchRequest)
            if let entry = results.first {
                return entry.value(forKey: "details") as? String
            }
            return nil
        } catch {
            print("Error fetching habit entry details: \(error)")
            return nil
        }
    }
    
    // Update details for a habit entry on a specific date
    func updateHabitEntryDetails(habit: Habit, date: Date, details: String) -> HabitEntry? {
        // Find the entry for this habit and date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@", habit, startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let results = try container.viewContext.fetch(fetchRequest)
            
            if let existingEntry = results.first {
                // Update the details
                existingEntry.setValue(details, forKey: "details")
                saveContext()
                return existingEntry
            } else {
                // Create a new entry if it doesn't exist
                let newEntry = HabitEntry(context: container.viewContext)
                newEntry.id = UUID()
                newEntry.date = date
                newEntry.completed = true
                newEntry.setValue(details, forKey: "details")
                newEntry.habit = habit
                
                saveContext()
                return newEntry
            }
        } catch {
            print("Error updating habit entry details: \(error)")
            return nil
        }
    }
}
