//
//  TodayHabitCardView.swift
//  Bullet Tracker
//
//  Native iOS list row for habit tracking in the Today view.
//

import SwiftUI
import SwiftData

struct TodayHabitRowView: View {
    let habit: Habit
    let date: Date
    let streak: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar

    @State private var showingDetailView = false
    @State private var checkScale: CGFloat = 1.0

    private var completionState: HabitCompletionState {
        HabitStore.completionState(for: habit, on: date)
    }

    private var isChecked: Bool { completionState.isCompleted }

    private var habitColor: Color { Color(hex: habit.color ?? "#FF8C42") }

    private var shouldTrackDetails: Bool { habit.trackDetails }
    private var useMultipleStates: Bool { habit.useMultipleStates }
    private var isNegativeHabit: Bool { habit.isNegativeHabit }

    private var isFutureDate: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }

    /// Last 7 days completion for mini dots
    private var last7Days: [Bool] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { daysAgo in
            guard let d = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return false }
            return HabitStore.completionState(for: habit, on: d).isCompleted
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            checkboxView
                .onTapGesture { handleCheckboxTap() }

            // Habit icon
            Image(systemName: habit.icon ?? "circle")
                .font(.system(size: 14))
                .foregroundStyle(habitColor)
                .frame(width: 32, height: 32)
                .background(habitColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Habit info
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name ?? "")
                    .font(.body)
                    .foregroundStyle(isChecked ? .secondary : .primary)

                HStack(spacing: 6) {
                    // Last 7 days mini dots
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { index in
                            Circle()
                                .fill(last7Days[index] ? habitColor : Color(.systemGray4))
                                .frame(width: 6, height: 6)
                        }
                    }

                    if streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 10))
                            Text("\(streak)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(isChecked ? Color.secondary : Color.orange)
                    }
                }
            }

            Spacer()

            // Detail disclosure
            if shouldTrackDetails {
                Button(action: { showingDetailView = true }) {
                    Image(systemName: "info.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingDetailView) {
            HabitCompletionDetailView(habit: habit, date: date)
        }
        .animation(.default, value: isChecked)
    }

    // MARK: - Checkbox

    private var checkboxView: some View {
        ZStack {
            if isChecked {
                Image(systemName: stateIconFilled)
                    .font(.system(size: 26))
                    .foregroundStyle(stateColor)
                    .symbolEffect(.bounce, value: isChecked)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(habitColor.opacity(0.4))
            }
        }
        .scaleEffect(checkScale)
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    private func handleCheckboxTap() {
        guard !isFutureDate else { return }

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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        HabitStore.setCompletion(for: habit, on: date, state: 1, in: modelContext)

        if shouldTrackDetails {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                showingDetailView = true
            }
        }
    }

    private func performUncheck() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        HabitStore.removeEntry(for: habit, on: date, in: modelContext)
    }

    private func cycleToNextState() {
        let currentState = completionState.state
        let nextState: Int
        switch currentState {
        case 1: nextState = 2
        case 2: nextState = 3
        case 3: nextState = 0
        default: nextState = 1
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        HabitStore.setCompletion(for: habit, on: date, state: nextState, in: modelContext)
    }

    // MARK: - Helpers

    private var stateColor: Color {
        if isNegativeHabit { return .red }
        switch completionState.state {
        case 1: return .green
        case 2: return .orange
        case 3: return .red
        default: return .green
        }
    }

    private var stateIconFilled: String {
        if isNegativeHabit { return "xmark.circle.fill" }
        switch completionState.state {
        case 1: return "checkmark.circle.fill"
        case 2: return "circle.lefthalf.filled"
        case 3: return "xmark.circle.fill"
        default: return "checkmark.circle.fill"
        }
    }
}
