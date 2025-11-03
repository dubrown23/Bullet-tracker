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
    
    /// Number of days to display in the tracker
    let daysToShow = 4
    
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
    
    /// Updates the visible date range and loads entries
    func updateVisibleDates() {
        guard let startDate = calendar.date(byAdding: .day, value: -(daysToShow - 1), to: selectedDate) else {
            return
        }
        
        visibleDates = (0..<daysToShow).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startDate)
        }
        
        loadHabitEntries()
    }
    
    /// Loads habit entries for the visible date range using the repository
    func loadHabitEntries() {
        guard !habits.isEmpty, !visibleDates.isEmpty else { return }
        
        let dateRange = visibleDates.first!...visibleDates.last!
        
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
                print("Failed to update habit order: \(error)")
            }
        }
    }
}