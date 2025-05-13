//
//  HabitTrackerViewModel.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


//
//  HabitTrackerViewModel.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

class HabitTrackerViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    @Published var selectedDate = Date()
    @Published var visibleDates: [Date] = []
    @Published var habitEntries: [UUID: [Date: HabitEntry]] = [:]
    @Published var showingAddHabitSheet = false
    @Published var selectedHabit: Habit? = nil
    @Published var showingDeleteAlert = false
    
    // Number of days to display in the tracker
    let daysToShow = 4
    
    func loadHabits() {
        let context = CoreDataManager.shared.container.viewContext
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            habits = try context.fetch(request)
            print("Loaded \(habits.count) habits")
            loadHabitEntries()
        } catch {
            print("Error loading habits: \(error)")
        }
    }
    
    func updateVisibleDates() {
        let calendar = Calendar.current
        
        // Calculate the start date based on selected end date
        guard let startDate = calendar.date(byAdding: .day, value: -(daysToShow - 1), to: selectedDate) else {
            return
        }
        
        // Generate array of visible dates
        var dates: [Date] = []
        var currentDate = startDate
        
        while currentDate <= selectedDate {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        visibleDates = dates
    }
    
    func loadHabitEntries() {
        guard !habits.isEmpty && !visibleDates.isEmpty else { return }
        
        let context = CoreDataManager.shared.container.viewContext
        let request: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        
        // Create a predicate for all habits and the visible date range
        var habitPredicates: [NSPredicate] = []
        
        for habit in habits {
            if let habitId = habit.id {
                habitPredicates.append(NSPredicate(format: "habit == %@", habit))
            }
        }
        
        let habitsPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: habitPredicates)
        
        let calendar = Calendar.current
        let startOfFirstDay = calendar.startOfDay(for: visibleDates.first!)
        let endOfLastDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: visibleDates.last!))!
        
        let datePredicate = NSPredicate(format: "date >= %@ AND date < %@", startOfFirstDay as NSDate, endOfLastDay as NSDate)
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [habitsPredicate, datePredicate])
        
        do {
            let entries = try context.fetch(request)
            print("Loaded \(entries.count) habit entries")
            
            // Organize entries by habit ID and date
            var entriesDict: [UUID: [Date: HabitEntry]] = [:]
            
            for entry in entries {
                if let habit = entry.habit, let habitId = habit.id, let date = entry.date {
                    let dayStart = calendar.startOfDay(for: date)
                    
                    if entriesDict[habitId] == nil {
                        entriesDict[habitId] = [:]
                    }
                    
                    entriesDict[habitId]?[dayStart] = entry
                }
            }
            
            habitEntries = entriesDict
        } catch {
            print("Error loading habit entries: \(error)")
        }
    }
    
    func toggleHabit(_ habit: Habit, on date: Date) {
        guard let habitId = habit.id else { return }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Check if an entry already exists
        let entryExists = habitEntries[habitId]?[startOfDay] != nil
        
        let context = CoreDataManager.shared.container.viewContext
        
        if entryExists {
            // Delete existing entry
            if let entry = habitEntries[habitId]?[startOfDay] {
                context.delete(entry)
                habitEntries[habitId]?[startOfDay] = nil
            }
        } else {
            // Create new entry
            let entry = HabitEntry(context: context)
            entry.id = UUID()
            entry.date = startOfDay
            entry.completed = true
            entry.habit = habit
            
            if habitEntries[habitId] == nil {
                habitEntries[habitId] = [:]
            }
            
            habitEntries[habitId]?[startOfDay] = entry
        }
        
        do {
            try context.save()
            print("Habit toggled successfully")
        } catch {
            print("Error toggling habit: \(error)")
            // Reload to get back to a consistent state
            loadHabitEntries()
        }
    }
    
    func isHabitCompleted(_ habit: Habit, on date: Date) -> Bool {
        guard let habitId = habit.id else { return false }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        return habitEntries[habitId]?[startOfDay] != nil
    }
    
    func getCompletionRate(for habit: Habit) -> Double {
        return CoreDataManager.shared.getCompletionRateForHabit(habit)
    }
}
