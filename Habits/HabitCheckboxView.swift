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
    
    // MARK: - Computed Properties
    
    private var shouldTrackDetails: Bool {
        (habit.value(forKey: "trackDetails") as? Bool) ?? false
    }
    
    private var useMultipleStates: Bool {
        (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    private var isNegativeHabit: Bool {
        (habit.value(forKey: "isNegativeHabit") as? Bool) ?? false
    }
    
    private var isWorkoutHabit: Bool {
        let workoutKeywords = ["workout", "exercise", "gym", "fitness", "training", "movement"]
        let habitName = (habit.name ?? "").lowercased()
        let detailType = (habit.value(forKey: "detailType") as? String) ?? ""
        
        return workoutKeywords.contains { habitName.contains($0) } || detailType == "workout"
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: handleTap) {
            checkboxContent
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 44, height: 44)
        .contextMenu {
            contextMenuContent
        }
        .sheet(isPresented: $showingDetailView) {
            checkHabitStatus()
        } content: {
            HabitCompletionDetailView(habit: habit, date: date)
        }
        .onLongPressGesture {
            showingDetailView = true
        }
        .onAppear {
            checkHabitStatus()
        }
    }
    
    // MARK: - View Components
    
    private var checkboxContent: some View {
        ZStack {
            // Outer ring in habit color
            Circle()
                .strokeBorder(Color(hex: habit.color ?? "#007AFF"), lineWidth: isChecked ? 2 : 1)
                .frame(width: 32, height: 32)
            
            // Inner circle with state color
            Circle()
                .fill(isChecked ? getStateColor() : Color.clear)
                .frame(width: 24, height: 24)
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
                    .foregroundStyle(Color(hex: habit.color ?? "#007AFF"))
            )
            .offset(x: 12, y: -12)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        if isChecked {
            Button(action: { showingDetailView = true }) {
                Label("Add/Edit Details", systemImage: "square.and.pencil")
            }
            
            Button(action: toggleHabit) {
                Label("Uncheck", systemImage: "circle")
            }
        } else {
            Button(action: toggleHabit) {
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
    
    private func handleTap() {
        // If habit tracks details and is already checked, open detail view
        if shouldTrackDetails && isChecked {
            showingDetailView = true
        } else {
            // Normal behavior - cycle through states
            toggleHabitWithState()
            
            // If we just completed a habit that tracks details, show the detail view
            if isChecked && shouldTrackDetails && !hasDetails {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingDetailView = true
                }
            }
        }
    }
    
    private func getStateColor() -> Color {
        // For negative habits, being checked means failure (red)
        if isNegativeHabit {
            return .red
        }
        
        // For positive habits, use normal color scheme
        switch completionState {
        case 1: return .green     // Success
        case 2: return .yellow    // Partial
        case 3: return .red       // Attempted
        default: return .green    // Default
        }
    }
    
    private func getStateIcon() -> String {
        // For negative habits, show X when checked
        if isNegativeHabit {
            return "xmark"
        }
        
        // For positive habits, use normal icons
        switch completionState {
        case 1: return "checkmark"              // Success
        case 2: return "circle.lefthalf.filled" // Partial
        case 3: return "xmark"                  // Failed
        default: return "checkmark"             // Default
        }
    }
    
    private func checkHabitStatus() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit, startOfDay as NSDate, endOfDay as NSDate
        )
        fetchRequest.fetchLimit = 1
        
        do {
            let context = CoreDataManager.shared.container.viewContext
            let results = try context.fetch(fetchRequest)
            
            if let entry = results.first {
                isChecked = entry.completed
                completionState = (entry.value(forKey: "completionState") as? Int) ?? 1
                hasDetails = checkForMeaningfulDetails(in: entry)
            } else {
                isChecked = false
                completionState = 0
                hasDetails = false
            }
        } catch {
            // Silent failure - default to unchecked
            isChecked = false
            completionState = 0
            hasDetails = false
        }
    }
    
    private func checkForMeaningfulDetails(in entry: HabitEntry) -> Bool {
        guard let detailsString = entry.details, !detailsString.isEmpty else {
            return false
        }
        
        // Try to parse as JSON
        guard let data = detailsString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Plain text details
            return !detailsString.isEmpty
        }
        
        // For workout habits with multiple states
        if isWorkoutHabit && useMultipleStates {
            // Only show indicator for success state with actual data
            return completionState == 1 &&
                   (!((json["types"] as? [String])?.isEmpty ?? true) ||
                    !((json["duration"] as? String)?.isEmpty ?? true))
        }
        
        // For other habits, check if notes exist
        return !((json["notes"] as? String)?.isEmpty ?? true)
    }
    
    private func toggleHabit() {
        // Prevent future dates
        guard !isFutureDate else { return }
        
        // Trigger animation
        withAnimation {
            isAnimating = true
        }
        
        // Use CoreDataManager to toggle
        _ = CoreDataManager.shared.toggleHabitEntry(habit: habit, date: date)
        
        // Update UI state
        isChecked.toggle()
        completionState = isChecked ? 1 : 0
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private func toggleHabitWithState() {
        // Prevent future dates
        guard !isFutureDate else { return }
        
        // Trigger animation
        withAnimation {
            isAnimating = true
        }
        
        // For negative habits or non-multi-state, simple toggle
        if isNegativeHabit || !useMultipleStates {
            toggleHabit()
            return
        }
        
        // Cycle through states
        let nextState = getNextState()
        
        if nextState == 0 {
            // Delete entry
            deleteHabitEntry()
            isChecked = false
            completionState = 0
        } else {
            // Create or update entry
            createOrUpdateHabitEntry(state: nextState)
            isChecked = true
            completionState = nextState
        }
        
        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAnimating = false
        }
        
        // Haptic feedback
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    private var isFutureDate: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        return checkDate > today
    }
    
    private func getNextState() -> Int {
        if !isChecked {
            return 1 // Not checked -> Success
        }
        
        switch completionState {
        case 1: return 2  // Success -> Partial
        case 2: return 3  // Partial -> Failed
        case 3: return 0  // Failed -> None
        default: return 1 // Any other -> Success
        }
    }
    
    private func createOrUpdateHabitEntry(state: Int) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit,
            startOfDay as NSDate,
            calendar.date(byAdding: .day, value: 1, to: startOfDay)! as NSDate
        )
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            
            if let entry = results.first {
                entry.completed = true
                entry.setValue(state, forKey: "completionState")
            } else {
                let entry = HabitEntry(context: context)
                entry.id = UUID()
                entry.date = startOfDay
                entry.completed = true
                entry.setValue(state, forKey: "completionState")
                entry.habit = habit
            }
            
            try context.save()
        } catch {
            // Silent failure
        }
    }
    
    private func deleteHabitEntry() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "habit == %@ AND date >= %@ AND date < %@",
            habit,
            startOfDay as NSDate,
            calendar.date(byAdding: .day, value: 1, to: startOfDay)! as NSDate
        )
        fetchRequest.fetchLimit = 1
        
        do {
            if let entry = try context.fetch(fetchRequest).first {
                context.delete(entry)
                try context.save()
            }
        } catch {
            // Silent failure
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
