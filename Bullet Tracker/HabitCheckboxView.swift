//
//  HabitCheckboxView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct HabitCheckboxView: View {
    @ObservedObject var habit: Habit
    let date: Date
    @State private var isChecked: Bool = false
    @State private var completionState: Int = 0 // 0: none, 1: success, 2: partial, 3: failure
    @State private var isAnimating: Bool = false
    @State private var hasDetails: Bool = false
    @State private var showingDetailView: Bool = false
    
    var body: some View {
        Button(action: {
            // Toggle with multi-state if enabled
            toggleHabitWithState()
        }) {
            ZStack {
                Circle()
                    .strokeBorder(getStateColor(), lineWidth: isChecked ? 0 : 1)
                    .background(
                        Circle()
                            .fill(isChecked ? getStateColor() : Color.clear)
                    )
                    .frame(width: 28, height: 28)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
                
                if isChecked {
                    Image(systemName: getStateIcon())
                        .foregroundColor(.white)
                        .font(.system(size: 12, weight: .bold))
                        .opacity(isAnimating ? 0.0 : 1.0)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 44, height: 44)
        .contextMenu {
            if isChecked {
                Button(action: {
                    // Uncheck
                    toggleHabit()
                }) {
                    Label("Uncheck", systemImage: "circle")
                }
            } else {
                Button(action: {
                    // Check
                    toggleHabit()
                }) {
                    Label("Complete", systemImage: "checkmark.circle")
                }
            }
        }
        .onAppear {
            checkHabitStatus()
        }
    }
    
    // Helper method to check if multiple states are used
    private func useMultipleStates() -> Bool {
        return (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    private func getStateColor() -> Color {
        if !useMultipleStates() || completionState == 1 {
            return Color(hex: habit.color ?? "#007AFF") // Default or success
        } else if completionState == 2 {
            return Color.orange // Partial
        } else if completionState == 3 {
            return Color.red // Failed
        }
        return Color(hex: habit.color ?? "#007AFF") // Default
    }
    
    private func getStateIcon() -> String {
        if !useMultipleStates() || completionState == 1 {
            return "checkmark" // Default or success
        } else if completionState == 2 {
            return "circle.lefthalf.filled" // Partial
        } else if completionState == 3 {
            return "xmark" // Failed
        }
        return "checkmark" // Default
    }
    
    private func checkHabitStatus() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@",
                                          habit, startOfDay as NSDate, endOfDay as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let context = CoreDataManager.shared.container.viewContext
            let results = try context.fetch(fetchRequest)
            
            if let entry = results.first {
                isChecked = entry.completed
                
                // Try to get completion state, default to 1 (success) if not found
                if let state = entry.value(forKey: "completionState") as? Int {
                    completionState = state
                } else {
                    completionState = 1 // Default to success
                }
                
                // Check for details
                hasDetails = entry.details != nil && !(entry.details?.isEmpty ?? true)
            } else {
                isChecked = false
                completionState = 0
                hasDetails = false
            }
        } catch {
            print("Error checking habit status: \(error)")
            isChecked = false
            completionState = 0
            hasDetails = false
        }
    }
    
    private func toggleHabit() {
        // Check if date is in the future
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        
        if checkDate > today {
            print("Cannot complete habits in the future")
            return
        }
        
        // Trigger animation
        isAnimating = true
        
        // Use CoreDataManager to toggle the habit entry
        _ = CoreDataManager.shared.toggleHabitEntry(habit: habit, date: date)
        
        // Update UI state
        isChecked.toggle()
        completionState = isChecked ? 1 : 0 // Set to success if checked
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func toggleHabitWithState() {
        // Check if date is in the future
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        
        if checkDate > today {
            print("Cannot complete habits in the future")
            return
        }
        
        // Trigger animation
        isAnimating = true
        
        if !useMultipleStates() {
            // If multiple states not enabled, just toggle
            toggleHabit()
            return
        }
        
        // If using multiple states, cycle through states
        if !isChecked {
            // If not checked, check with success state
            createOrUpdateHabitEntry(state: 1)
            isChecked = true
            completionState = 1
        } else {
            // If already checked, cycle to next state
            let nextState: Int
            switch completionState {
            case 1: nextState = 2 // Success -> Partial
            case 2: nextState = 3 // Partial -> Failed
            case 3: nextState = 0 // Failed -> None
            default: nextState = 1 // Any other state -> Success
            }
            
            if nextState == 0 {
                // If cycling to none, delete the entry
                deleteHabitEntry()
                isChecked = false
                completionState = 0
            } else {
                // Otherwise update with new state
                createOrUpdateHabitEntry(state: nextState)
                completionState = nextState
            }
        }
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    // Create or update habit entry with state
    private func createOrUpdateHabitEntry(state: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@",
                                          habit, startOfDay as NSDate, calendar.date(byAdding: .day, value: 1, to: startOfDay)! as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            
            if let entry = results.first {
                // Update existing entry
                entry.completed = true
                entry.setValue(state, forKey: "completionState")
            } else {
                // Create new entry
                let entry = HabitEntry(context: context)
                entry.id = UUID()
                entry.date = startOfDay
                entry.completed = true
                entry.setValue(state, forKey: "completionState")
                entry.habit = habit
            }
            
            try context.save()
        } catch {
            print("Error creating/updating habit entry: \(error)")
        }
    }
    
    // Delete habit entry
    private func deleteHabitEntry() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@",
                                          habit, startOfDay as NSDate, calendar.date(byAdding: .day, value: 1, to: startOfDay)! as NSDate)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            
            if let entry = results.first {
                context.delete(entry)
                try context.save()
            }
        } catch {
            print("Error deleting habit entry: \(error)")
        }
    }
}
