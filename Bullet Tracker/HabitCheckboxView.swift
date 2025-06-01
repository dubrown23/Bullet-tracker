import SwiftUI
import CoreData

struct HabitCheckboxView: View {
    // MARK: - Properties
    
    @ObservedObject var habit: Habit
    let date: Date
    
    // MARK: - State Properties
    
    @State private var isChecked: Bool = false
    @State private var completionState: Int = 0 // 0: none, 1: success, 2: partial, 3: failure
    @State private var isAnimating: Bool = false
    @State private var hasDetails: Bool = false
    @State private var showingDetailView: Bool = false
    @State private var shouldPromptForDetails: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            toggleHabitWithState()
            
            // If we just completed a habit that should track details, show the detail view
            if isChecked && shouldTrackDetailsForHabit() && !hasDetails {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingDetailView = true
                }
            }
        }) {
            checkboxContent
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 44, height: 44)
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showingDetailView) {
            checkHabitStatus() // Refresh status when dismissing the detail view
        } content: {
            HabitCompletionDetailView(habit: habit, date: date)
        }
        .onLongPressGesture {
            showingDetailView = true
        }
        .onAppear {
            checkHabitStatus()
            shouldPromptForDetails = shouldTrackDetailsForHabit()
        }
    }
    
    // MARK: - View Components
    
    private var checkboxContent: some View {
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
                    .foregroundStyle(.white)
                    .font(.system(size: 12, weight: .bold))
                    .opacity(isAnimating ? 0.0 : 1.0)
            }
            
            // Show a note indicator if there are details
            if hasDetails && isChecked {
                detailIndicator
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
    }
    
    private var detailIndicator: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 12, height: 12)
            .overlay(
                Image(systemName: "note.text")
                    .font(.system(size: 8))
                    .foregroundStyle(getStateColor())
            )
            .offset(x: 12, y: -12)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        if isChecked {
            Button(action: {
                showingDetailView = true
            }) {
                Label("Add/Edit Details", systemImage: "square.and.pencil")
            }
            
            Button(action: {
                toggleHabit()
            }) {
                Label("Uncheck", systemImage: "circle")
            }
        } else {
            Button(action: {
                toggleHabit()
            }) {
                Label("Complete", systemImage: "checkmark.circle")
            }
            
            Button(action: {
                toggleHabit()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingDetailView = true
                }
            }) {
                Label("Complete With Details", systemImage: "checkmark.circle.fill")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Checks if details should be tracked for this habit
    private func shouldTrackDetailsForHabit() -> Bool {
        return (habit.value(forKey: "trackDetails") as? Bool) ?? false
    }
    
    /// Checks if multiple completion states are enabled
    private func useMultipleStates() -> Bool {
        return (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    /// Returns the appropriate color based on completion state
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
    
    /// Returns the appropriate icon based on completion state
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
    
    /// Checks the current habit completion status for the date
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
            #if DEBUG
            print("Error checking habit status: \(error)")
            #endif
            isChecked = false
            completionState = 0
            hasDetails = false
        }
    }
    
    /// Toggles the habit completion status
    private func toggleHabit() {
        // Check if date is in the future
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        
        guard checkDate <= today else {
            #if DEBUG
            print("Cannot complete habits in the future")
            #endif
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
    
    /// Toggles habit with multi-state support
    private func toggleHabitWithState() {
        // Check if date is in the future
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        
        guard checkDate <= today else {
            #if DEBUG
            print("Cannot complete habits in the future")
            #endif
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
    
    /// Creates or updates a habit entry with the specified completion state
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
            #if DEBUG
            print("Error creating/updating habit entry: \(error)")
            #endif
        }
    }
    
    /// Deletes the habit entry for the current date
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
            #if DEBUG
            print("Error deleting habit entry: \(error)")
            #endif
        }
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let habit = Habit(context: context)
    habit.name = "Sample Habit"
    habit.color = "#007AFF"
    
    return HabitCheckboxView(habit: habit, date: Date())
        .padding()
}
