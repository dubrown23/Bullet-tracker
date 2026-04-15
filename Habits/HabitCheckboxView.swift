import SwiftUI

struct HabitCheckboxView: View {
    // MARK: - Properties

    @ObservedObject var habit: Habit
    let date: Date

    // MARK: - Dependencies

    @Environment(HabitDataRepository.self) private var dataRepository

    // MARK: - Size Class Adaptation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Adaptive dimensions
    private var outerCircleSize: CGFloat {
        horizontalSizeClass == .regular ? 40 : 32
    }

    private var innerCircleSize: CGFloat {
        horizontalSizeClass == .regular ? 30 : 24
    }

    private var glowSize: CGFloat {
        horizontalSizeClass == .regular ? 48 : 38
    }

    private var checkmarkSize: CGFloat {
        horizontalSizeClass == .regular ? 15 : 12
    }

    private var tapAreaSize: CGFloat {
        horizontalSizeClass == .regular ? 56 : 44
    }

    // MARK: - State Properties

    @State private var isAnimating: Bool = false
    @State private var showCheckmarkPop: Bool = false
    @State private var showingDetailView: Bool = false

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
        checkboxContent
            .contentShape(Rectangle()) // Ensure entire area is tappable
            .onTapGesture {
                handleTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                showingDetailView = true
            }
            .contextMenu {
                contextMenuContent
            }
            .sheet(isPresented: $showingDetailView) {
                HabitCompletionDetailView(habit: habit, date: date)
                    .environment(dataRepository)
            }
    }

    // MARK: - View Components

    private var checkboxContent: some View {
        let habitColor = Color(hex: habit.color ?? "#FF8C42")
        let strokeWidth: CGFloat = horizontalSizeClass == .regular ? 3.0 : 2.5

        return ZStack {
            // Subtle glow when checked
            if isChecked {
                Circle()
                    .fill(getStateColor().opacity(0.2))
                    .frame(width: glowSize, height: glowSize)
                    .scaleEffect(isAnimating ? 1.3 : 1.0)
            }

            // Outer ring in habit color
            Circle()
                .strokeBorder(
                    isChecked ? getStateColor() : habitColor.opacity(0.5),
                    lineWidth: isChecked ? strokeWidth : strokeWidth - 1
                )
                .frame(width: outerCircleSize, height: outerCircleSize)

            // Inner circle with state color
            Circle()
                .fill(isChecked ? getStateColor() : Color.clear)
                .frame(width: innerCircleSize, height: innerCircleSize)
                .scaleEffect(isAnimating ? 1.15 : 1.0)

            // Checkmark with pop animation
            if isChecked {
                Image(systemName: getStateIcon())
                    .foregroundStyle(.white)
                    .font(.system(size: checkmarkSize, weight: .bold))
                    .scaleEffect(showCheckmarkPop ? 1.0 : 0.5)
                    .opacity(showCheckmarkPop ? 1.0 : 0.0)
            }

            // Show a note indicator if there are details
            if hasDetails && isChecked {
                detailIndicator
            }
        }
        .frame(width: tapAreaSize, height: tapAreaSize)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isChecked)
        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isAnimating)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: showCheckmarkPop)
    }

    private var detailIndicator: some View {
        let indicatorSize: CGFloat = horizontalSizeClass == .regular ? 14 : 12
        let iconSize: CGFloat = horizontalSizeClass == .regular ? 9 : 8
        let offset: CGFloat = horizontalSizeClass == .regular ? 16 : 12

        return Circle()
            .fill(Color.white)
            .frame(width: indicatorSize, height: indicatorSize)
            .overlay(
                Image(systemName: "note.text")
                    .font(.system(size: iconSize))
                    .foregroundStyle(Color(hex: habit.color ?? "#007AFF"))
            )
            .offset(x: offset, y: -offset)
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        if isChecked {
            Button(action: { showingDetailView = true }) {
                Label("Add/Edit Details", systemImage: "square.and.pencil")
            }

            Button(action: { performUncheck() }) {
                Label("Uncheck", systemImage: "circle")
            }
        } else {
            Button(action: { performCheck() }) {
                Label("Complete", systemImage: "checkmark.circle")
            }

            Button(action: {
                performCheck()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingDetailView = true
                }
            }) {
                Label("Complete With Details", systemImage: "checkmark.circle.fill")
            }
        }
    }

    // MARK: - Action Methods

    private func handleTap() {
        guard !isFutureDate else { return }

        // If habit tracks details and is already checked, open detail view
        if shouldTrackDetails && isChecked {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingDetailView = true
            return
        }

        // Toggle or cycle through states (haptics handled in each method)
        if isChecked {
            if useMultipleStates && !isNegativeHabit {
                cycleToNextState()
            } else {
                performUncheck()
            }
        } else {
            performCheck()
        }
    }

    private func performCheck() {
        // Stronger haptic for completion
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Animate the circle expansion
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            isAnimating = true
        }

        // Update data
        dataRepository.updateEntry(for: habit, on: date, completed: true, state: 1)

        // Pop in the checkmark slightly delayed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                showCheckmarkPop = true
            }
        }

        // Reset circle animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation {
                isAnimating = false
            }
        }

        // Show detail view if this habit tracks details
        if shouldTrackDetails {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showingDetailView = true
            }
        }
    }

    private func performUncheck() {
        // Light haptic for uncheck
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Animate checkmark out first
        withAnimation(.easeOut(duration: 0.1)) {
            showCheckmarkPop = false
        }

        // Then animate circle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                isAnimating = true
            }
        }

        // Remove entry
        dataRepository.removeEntry(for: habit, on: date)

        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation {
                isAnimating = false
            }
        }
    }

    private func cycleToNextState() {
        let currentState = completionState.state
        let nextState: Int

        switch currentState {
        case 1: nextState = 2  // Success -> Partial
        case 2: nextState = 3  // Partial -> Failed
        case 3: nextState = 0  // Failed -> None (uncheck)
        default: nextState = 1 // Any other -> Success
        }

        // Haptic feedback
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Animate
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            isAnimating = true
        }

        if nextState == 0 {
            withAnimation(.easeOut(duration: 0.1)) {
                showCheckmarkPop = false
            }
            dataRepository.removeEntry(for: habit, on: date)
        } else {
            dataRepository.updateEntry(for: habit, on: date, completed: true, state: nextState)
            // Quick pop for icon change
            showCheckmarkPop = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    showCheckmarkPop = true
                }
            }
        }

        // Reset animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation {
                isAnimating = false
            }
        }
    }

    // MARK: - Helper Methods

    private func getStateColor() -> Color {
        // For negative habits, being checked means failure (red)
        if isNegativeHabit {
            return AppTheme.failed
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
