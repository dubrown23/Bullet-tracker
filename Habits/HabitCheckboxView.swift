import SwiftUI

struct HabitCheckboxView: View {
    // MARK: - Properties
    
    @ObservedObject var habit: Habit
    let date: Date
    
    // MARK: - Dependencies
    
    @EnvironmentObject private var dataRepository: HabitDataRepository
    
    // MARK: - State Properties
    
    @State private var isAnimating: Bool = false
    @State private var showingDetailView: Bool = false
    @State private var pendingOperation: PendingOperation?
    
    // MARK: - Types
    
    private enum PendingOperation: Equatable {
        case toggle
        case setState(Int)
        case delete
    }
    
    
    // MARK: - Computed Properties
    
    /// Gets the current completion state from the repository
    private var completionState: HabitCompletionState {
        dataRepository.getCompletionState(for: habit, on: date)
    }
    
    /// Whether the habit is currently checked/completed
    private var isChecked: Bool {
        completionState.isCompleted
    }
    
    /// Whether the habit has meaningful details
    private var hasDetails: Bool {
        completionState.hasDetails
    }
    
    private var shouldTrackDetails: Bool {
        (habit.value(forKey: "trackDetails") as? Bool) ?? false
    }
    
    private var useMultipleStates: Bool {
        (habit.value(forKey: "useMultipleStates") as? Bool) ?? false
    }
    
    private var isNegativeHabit: Bool {
        (habit.value(forKey: "isNegativeHabit") as? Bool) ?? false
    }
    
    private var isFutureDate: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let checkDate = calendar.startOfDay(for: date)
        return checkDate > today
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
            HabitCompletionDetailView(habit: habit, date: date)
        }
        .onLongPressGesture {
            showingDetailView = true
        }
        .onChange(of: pendingOperation) { _, operation in
            if let operation = operation {
                processPendingOperation(operation)
            }
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
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isAnimating)
            
            if isChecked {
                Image(systemName: getStateIcon())
                    .foregroundStyle(.white)
                    .font(.system(size: 12, weight: .bold))
                    .opacity(isAnimating ? 0.0 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isAnimating)
            }
            
            // Show a note indicator if there are details
            if hasDetails && isChecked {
                detailIndicator
            }
        }
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
            
            Button(action: { pendingOperation = .toggle }) {
                Label("Uncheck", systemImage: "circle")
            }
        } else {
            Button(action: { pendingOperation = .toggle }) {
                Label("Complete", systemImage: "checkmark.circle")
            }
            
            Button(action: {
                pendingOperation = .toggle
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
        guard !isFutureDate else { return }
        
        // If habit tracks details and is already checked, open detail view
        if shouldTrackDetails && isChecked {
            showingDetailView = true
        } else {
            // Normal behavior - cycle through states
            let nextState = getNextState()
            if nextState == 0 {
                pendingOperation = .delete
            } else {
                pendingOperation = .setState(nextState)
            }
            
            // If we just completed a habit that tracks details, show the detail view
            if nextState == 1 && shouldTrackDetails && !hasDetails {
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
        
        // Use the state color from completion state
        return completionState.stateColor
    }
    
    private func getStateIcon() -> String {
        // For negative habits, show X when checked
        if isNegativeHabit {
            return "xmark"
        }
        
        // Use the state icon from completion state
        return completionState.stateIcon
    }
    
    private func getNextState() -> Int {
        // For negative habits or non-multi-state, simple toggle
        if isNegativeHabit || !useMultipleStates {
            return isChecked ? 0 : 1
        }
        
        if !isChecked {
            return 1 // Not checked -> Success
        }
        
        switch completionState.state {
        case 1: return 2  // Success -> Partial
        case 2: return 3  // Partial -> Failed
        case 3: return 0  // Failed -> None
        default: return 1 // Any other -> Success
        }
    }
    
    
    private func processPendingOperation(_ operation: PendingOperation) {
        // Trigger animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isAnimating = true
        }
        
        // Process operation using repository
        switch operation {
        case .toggle:
            if isNegativeHabit || !useMultipleStates {
                // Simple toggle
                let newCompleted = !isChecked
                dataRepository.updateEntry(
                    for: habit,
                    on: date,
                    completed: newCompleted,
                    state: newCompleted ? 1 : 0
                )
            } else {
                // Multi-state toggle
                let nextState = getNextState()
                if nextState == 0 {
                    dataRepository.removeEntry(for: habit, on: date)
                } else {
                    dataRepository.updateEntry(for: habit, on: date, completed: true, state: nextState)
                }
            }
            
        case .setState(let state):
            dataRepository.updateEntry(for: habit, on: date, completed: true, state: state)
            
        case .delete:
            dataRepository.removeEntry(for: habit, on: date)
        }
        
        // Reset animation and pending operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isAnimating = false
            }
            pendingOperation = nil
            
            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
