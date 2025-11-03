//
//  HabitWidgetProvider.swift
//  BulletTrackerWidgets
//
//  Created by Dustin Brown on 10/30/25.
//

import WidgetKit
import SwiftUI
import CoreData

// MARK: - Widget Entry

struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habits: [WidgetHabit]
    let isEmpty: Bool
    
    static let placeholder = HabitWidgetEntry(
        date: Date(),
        habits: [
            WidgetHabit.placeholder(name: "Morning Exercise", isCompleted: true),
            WidgetHabit.placeholder(name: "Reading", isCompleted: false),
            WidgetHabit.placeholder(name: "Meditation", isCompleted: true),
            WidgetHabit.placeholder(name: "Drink Water", isCompleted: false)
        ],
        isEmpty: false
    )
}

// MARK: - Widget Habit Model

struct WidgetHabit: Identifiable {
    let id: UUID
    let name: String
    let icon: String
    let color: String
    let isCompleted: Bool
    let completionState: Int
    let needsDetails: Bool
    
    static func placeholder(name: String, isCompleted: Bool) -> WidgetHabit {
        WidgetHabit(
            id: UUID(),
            name: name,
            icon: "checkmark.circle",
            color: "#007AFF",
            isCompleted: isCompleted,
            completionState: isCompleted ? 1 : 0,
            needsDetails: false
        )
    }
}

// MARK: - Timeline Provider

struct HabitWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry.placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (HabitWidgetEntry) -> ()) {
        if context.isPreview {
            completion(HabitWidgetEntry.placeholder)
        } else {
            loadHabitsEntry { entry in
                completion(entry)
            }
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<HabitWidgetEntry>) -> ()) {
        loadHabitsEntry { entry in
            // Update timeline at midnight for new day
            let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
            let timeline = Timeline(entries: [entry], policy: .after(midnight))
            completion(timeline)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadHabitsEntry(completion: @escaping (HabitWidgetEntry) -> Void) {
        let context = WidgetCoreDataManager.shared.viewContext
        
        context.perform {
            let habits = fetchTodaysHabits(context: context)
            let widgetHabits = habits.map { habit in
                WidgetHabit(
                    id: habit.id ?? UUID(),
                    name: habit.name ?? "Unnamed Habit",
                    icon: habit.icon ?? "checkmark.circle",
                    color: habit.color ?? "#007AFF",
                    isCompleted: getCompletionState(for: habit) > 0,
                    completionState: getCompletionState(for: habit),
                    needsDetails: habit.useMultipleStates || habit.trackDetails
                )
            }
            
            let entry = HabitWidgetEntry(
                date: Date(),
                habits: Array(widgetHabits.prefix(5)), // Limit to 5 habits for medium widget
                isEmpty: widgetHabits.isEmpty
            )
            
            DispatchQueue.main.async {
                completion(entry)
            }
        }
    }
    
    private func fetchTodaysHabits(context: NSManagedObjectContext) -> [Habit] {
        let request: NSFetchRequest<Habit> = Habit.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        do {
            let allHabits = try context.fetch(request)
            let today = Date()
            
            // Filter habits that should be tracked today based on frequency
            return allHabits.filter { habit in
                shouldTrackHabitToday(habit, on: today)
            }
        } catch {
            print("Error fetching habits for widget: \(error)")
            return []
        }
    }
    
    private func shouldTrackHabitToday(_ habit: Habit, on date: Date) -> Bool {
        // Check if habit has started
        if let startDate = habit.startDate, date < startDate {
            return false
        }
        
        let weekday = Calendar.current.component(.weekday, from: date)
        let frequency = habit.frequency ?? "daily"
        
        switch frequency {
        case "daily":
            return true
        case "weekdays":
            return weekday >= 2 && weekday <= 6 // Monday = 2, Friday = 6
        case "weekends":
            return weekday == 1 || weekday == 7 // Sunday = 1, Saturday = 7
        case "weekly":
            // Check custom days
            guard let customDaysData = habit.customDays,
                  let customDays = try? JSONDecoder().decode([Int].self, from: customDaysData) else {
                return true // Default to daily if can't parse
            }
            return customDays.contains(weekday)
        default:
            return true
        }
    }
    
    private func getCompletionState(for habit: Habit) -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        
        // Try to find today's entry
        if let entries = habit.entries as? Set<HabitEntry> {
            for entry in entries {
                if let entryDate = entry.date,
                   Calendar.current.isDate(entryDate, inSameDayAs: today) {
                    return Int(entry.completionState)
                }
            }
        }
        
        return 0 // Not completed
    }
}