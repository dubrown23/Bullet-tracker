//
//  TodayHabitCardView.swift
//  Bullet Tracker
//
//  Native iOS list row for habit tracking in the Today view
//

import SwiftUI

struct TodayHabitRowView: View {
    let habit: Habit
    let date: Date
    let streak: Int

    @Environment(HabitDataRepository.self) private var dataRepository

    @State private var showingDetailView = false
    @State private var checkScale: CGFloat = 1.0

    private var completionState: HabitCompletionState {
        dataRepository.getCompletionState(for: habit, on: date)
    }

    private var isChecked: Bool {
        completionState.isCompleted
    }

    private var habitColor: Color {
        Color(hex: habit.color ?? "#FF8C42")
    }

    private var shouldTrackDetails: Bool {
        habit.trackDetails
    }

    private var useMultipleStates: Bool {
        habit.useMultipleStates
    }

    private var isNegativeHabit: Bool {
        habit.isNegativeHabit
    }

    private var isFutureDate: Bool {
        Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        HStack(spacing: 14) {
            // Checkbox
            checkboxView
                .onTapGesture { handleCheckboxTap() }

            // Habit info
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name ?? "")
                    .font(.body)
                    .foregroundStyle(isChecked ? .secondary : .primary)

                if streak > 0 {
                    Text("\(streak) day streak")
                        .font(.caption)
                        .foregroundStyle(isChecked ? Color.secondary : Color.orange)
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
                .environment(dataRepository)
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
        dataRepository.updateEntry(for: habit, on: date, completed: true, state: 1)

        if shouldTrackDetails {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                showingDetailView = true
            }
        }
    }

    private func performUncheck() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dataRepository.removeEntry(for: habit, on: date)
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

        if nextState == 0 {
            dataRepository.removeEntry(for: habit, on: date)
        } else {
            dataRepository.updateEntry(for: habit, on: date, completed: true, state: nextState)
        }
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
