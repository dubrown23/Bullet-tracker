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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showingDetailView = false
    /// Bumped on every check / uncheck / cycle so `.sensoryFeedback` fires
    /// exactly once per user action (and not when the row re-renders).
    @State private var feedbackTick = 0

    /// Icon tile and checkbox scale with the user's text size (Dynamic Type).
    @ScaledMetric(relativeTo: .body) private var iconTileSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var dotSize: CGFloat = 6

    /// Wave 4.5 prefetch: one indexed range fetch returning up to 7 entries
    /// for this habit's last 7 days. Both `completionState` (today's render)
    /// and `last7Days` (mini-dots) read from this dict instead of issuing
    /// per-day single-row queries. Goes from ~10 fetches per card body down to
    /// ~1 effective fetch (SwiftData's row cache makes repeat accesses cheap).
    private var entriesLast7Days: [Date: HabitEntry] {
        let today = calendar.startOfDay(for: Date())
        guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return [:] }
        return HabitStore.entriesByDay(for: habit, from: weekAgo, to: today)
    }

    private var completionState: HabitCompletionState {
        let entryDate = calendar.startOfDay(for: date)
        return HabitStore.completionState(for: habit, entry: entriesLast7Days[entryDate])
    }

    private var isChecked: Bool { completionState.isCompleted }

    private var habitColor: Color { Color(hex: habit.color ?? "#FF8C42") }

    private var shouldTrackDetails: Bool { habit.detailKind != nil }
    private var useMultipleStates: Bool { habit.completionStyle == .multiState }
    private var isNegativeHabit: Bool { habit.completionStyle == .avoidance }

    private var isFutureDate: Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
    }

    /// Last 7 days completion for mini dots — derived from `entriesLast7Days`
    /// rather than 7 single-row predicate fetches.
    private var last7Days: [Bool] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { daysAgo in
            guard let d = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return false }
            let dayStart = calendar.startOfDay(for: d)
            guard let entry = entriesLast7Days[dayStart] else { return false }
            return entry.effectiveCompletionState != .notDone
        }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Accessibility text sizes: stack so nothing is squeezed off the
                // card (Dynamic Type layout adaptation).
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        checkboxButton
                        iconTile
                        nameText
                    }
                    HStack(spacing: 10) {
                        historyRow
                        Spacer()
                        detailsButton
                    }
                }
            } else {
                HStack(spacing: 14) {
                    checkboxButton
                    iconTile

                    VStack(alignment: .leading, spacing: 4) {
                        nameText
                        historyRow
                    }

                    Spacer()

                    detailsButton
                }
            }
        }
        .sheet(isPresented: $showingDetailView) {
            HabitCompletionDetailView(habit: habit, date: date)
        }
        .animation(.default, value: isChecked)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTick)
    }

    // MARK: - Pieces

    /// A real Button so VoiceOver gets a name, a value and the toggle trait
    /// (it used to be an Image with a tap gesture).
    private var checkboxButton: some View {
        Button(action: handleCheckboxTap) {
            checkboxView
        }
        .buttonStyle(.plain)
        .disabled(isFutureDate)
        .accessibilityLabel(habit.name ?? "Habit")
        .accessibilityValue(accessibilityStateDescription)
        .accessibilityAddTraits(.isToggle)
    }

    /// Habit icon — decorative, the name is right next to it.
    private var iconTile: some View {
        Image(systemName: habit.icon ?? "circle")
            .font(.subheadline)
            .foregroundStyle(habitColor)
            .frame(width: iconTileSize, height: iconTileSize)
            .background(habitColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }

    private var nameText: some View {
        Text(habit.name ?? "")
            .font(.body)
            .foregroundStyle(isChecked ? .secondary : .primary)
    }

    /// Last-7-days dots + streak badge.
    private var historyRow: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    Circle()
                        .fill(last7Days[index] ? habitColor : Color(.systemGray4))
                        .frame(width: dotSize, height: dotSize)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Last 7 days: \(last7Days.filter { $0 }.count) of 7 completed")

            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(streak)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
                .fixedSize()
                .foregroundStyle(isChecked ? Color.secondary : Color.orange)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(streak) day streak")
            }
        }
    }

    @ViewBuilder
    private var detailsButton: some View {
        if shouldTrackDetails {
            Button("Log details", systemImage: "info.circle") {
                showingDetailView = true
            }
            .labelStyle(.iconOnly)
            .font(.body)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Checkbox

    private var checkboxView: some View {
        ZStack {
            if isChecked {
                Image(systemName: stateIconFilled)
                    .font(.title)
                    .foregroundStyle(stateColor)
                    .symbolEffect(.bounce, value: isChecked)
            } else {
                Image(systemName: "circle")
                    .font(.title)
                    .foregroundStyle(habitColor.opacity(0.4))
            }
        }
        .frame(width: iconTileSize, height: iconTileSize)
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
        feedbackTick += 1
        HabitStore.setCompletion(for: habit, on: date, state: 1, in: modelContext)

        if shouldTrackDetails {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                showingDetailView = true
            }
        }
    }

    private func performUncheck() {
        feedbackTick += 1
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

        feedbackTick += 1
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

    /// Spoken value for the checkbox.
    private var accessibilityStateDescription: String {
        if !isChecked { return "Not done" }
        if isNegativeHabit { return "Slipped" }
        switch completionState.state {
        case 2: return "Partial"
        case 3: return "Tried"
        default: return "Done"
        }
    }
}
