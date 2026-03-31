//  HabitTrackerViewModel.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
@preconcurrency import CoreData

// MARK: - View Model

@MainActor
class HabitTrackerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var habits: [Habit] = []
    @Published var selectedDate = Date()
    @Published var visibleDates: [Date] = []
    @Published var showingAddHabitSheet = false
    @Published var selectedHabit: Habit? = nil
    @Published var habitToDelete: Habit? = nil
    @Published var showingDeleteAlert = false
    
    // MARK: - Dependencies
    
    let dataRepository = HabitDataRepository()
    
    // MARK: - Constants

    // (daysToShow removed - now dynamically calculated based on month)
    
    // MARK: - Private Properties
    
    private let calendar = Calendar.current
    private var loadTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    
    deinit {
        loadTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Loads all habits from Core Data
    func loadHabits() {
        loadTask?.cancel()
        
        loadTask = Task {
            await loadHabitsAsync()
        }
    }
    
    /// Updates the visible date range to show all days from the 1st of the month up to today (never future)
    func updateVisibleDates() {
        // Get the first day of the month for the selected date
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else {
            return
        }

        // Never show dates past today
        let today = calendar.startOfDay(for: Date())

        // If viewing a past month, show the whole month; otherwise show up to today
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else { return }
        let effectiveEndDate: Date
        if endOfMonth < today {
            // Past month - show entire month
            effectiveEndDate = endOfMonth
        } else {
            // Current or future month - show up to today only
            effectiveEndDate = min(today, endOfMonth)
        }

        // Calculate how many days from start of month to effective end date
        let components = calendar.dateComponents([.day], from: startOfMonth, to: effectiveEndDate)
        let daysToShow = (components.day ?? 0) + 1

        // Build array of dates from 1st of month to effective end date
        visibleDates = (0..<daysToShow).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfMonth)
        }

        loadHabitEntries()
    }
    
    /// Loads habit entries for the visible date range using the repository
    func loadHabitEntries() {
        guard !habits.isEmpty, !visibleDates.isEmpty else { return }
        
        guard let first = visibleDates.first, let last = visibleDates.last else { return }
        let dateRange = first...last
        
        loadTask?.cancel()
        loadTask = Task {
            await dataRepository.loadEntries(for: habits, dateRange: dateRange)
        }
    }
    
    /// Reorders habits
    func reorderHabits(from source: IndexSet, to destination: Int) {
        habits.move(fromOffsets: source, toOffset: destination)
        
        // Update sort order in Core Data
        Task {
            await updateHabitSortOrder()
        }
    }
    
    /// Gets the completion rate for a habit
    func getCompletionRate(for habit: Habit) -> Double {
        CoreDataManager.shared.getCompletionRateForHabit(habit)
    }
    
    // MARK: - Private Methods
    
    private func loadHabitsAsync() async {
        let context = CoreDataManager.shared.container.viewContext
        
        let habitsResult = await context.perform {
            let request: NSFetchRequest<Habit> = Habit.fetchRequest()
            
            // Sort by order first, then by name for habits with same order
            request.sortDescriptors = [
                NSSortDescriptor(key: "order", ascending: true),
                NSSortDescriptor(key: "name", ascending: true)
            ]
            
            do {
                let fetchedHabits = try context.fetch(request)
                
                // Ensure all habits have an order value
                var needsOrderUpdate = false
                for (index, habit) in fetchedHabits.enumerated() where habit.order == 0 {
                    habit.order = Int32(index)
                    needsOrderUpdate = true
                }
                
                // Save if we updated any order values
                if needsOrderUpdate {
                    try context.save()
                }
                
                return fetchedHabits
            } catch {
                return []
            }
        }
        
        habits = habitsResult
        loadHabitEntries()
    }
    
    private func updateHabitSortOrder() async {
        let context = CoreDataManager.shared.container.viewContext
        
        // Get ObjectIDs for thread safety
        let habitObjectIDs = habits.map { $0.objectID }
        
        await context.perform {
            // Update order values using ObjectIDs
            for (index, objectID) in habitObjectIDs.enumerated() {
                if let habit = try? context.existingObject(with: objectID) as? Habit {
                    habit.order = Int32(index)
                }
            }
            
            do {
                try context.save()
            } catch {
                debugLog("Failed to update habit order: \(error.localizedDescription)")
            }
        }
    }
}