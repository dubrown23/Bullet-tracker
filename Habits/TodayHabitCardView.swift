//
//  TodayHabitCardView.swift
//  Bullet Tracker
//
//  Native iOS list row for habit tracking in the Today view.
//
//  bt-0013 PROTOTYPE — week-grid row (the Everyday / Loop / HabitNow pattern):
//
//      🏃 Workout  🔥3            ▪ ▪ ▫ ▪ ▪ ▫ ◻
//                                 ──────────┬─
//                                        today (outlined until done)
//
//  • The whole row is the button (44pt+ target, HIG). Tap = complete today
//    (or cycle a multi-state habit). Logging and glancing are the same
//    gesture on the same pixels.
//  • Seven real-sized cells, newest on the right, coloured by that day's
//    state. Today's cell is outlined in the habit colour until it's done.
//  • Icon is a plain coloured glyph next to the name — identity only.
//  • Edit / Delete / Log Details live on long-press and swipe.
//  • One line (name truncates first); at accessibility text sizes the name
//    sits above the grid.
//

import SwiftUI
import SwiftData

struct TodayHabitRowView: View {
    let habit: Habit
    let date: Date
    let streak: Int
    /// Asks the owner (TodayView) to confirm + delete. The confirmation alert
    /// must live on a stable ancestor: when a swipe action fires, List tears
    /// the row down, and any alert presented from row state vanishes with it.
    let onRequestDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showingDetailView = false
    @State private var showingEditSheet = false
    /// Bumped on every check / uncheck / cycle so `.sensoryFeedback` fires
    /// exactly once per user action (and not when the row re-renders).
    @State private var feedbackTick = 0

    /// Grid cell and glyph sizes scale with the user's text size (Dynamic Type).
    @ScaledMetric(relativeTo: .body) private var cellSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var cellSpacing: CGFloat = 5
    @ScaledMetric(relativeTo: .body) private var glyphWidth: CGFloat = 24

    // MARK: - Data

    /// One indexed range fetch for the last 7 days (incl. today); every per-day
    /// read below comes from this dictionary.
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

    private var habitColorHex: String { habit.color ?? AppTheme.accentHex }
    private var habitColor: Color { Color(hex: habitColorHex) }

    private var shouldTrackDetails: Bool { habit.detailKind != nil }
    private var useMultipleStates: Bool { habit.completionStyle == .multiState }
    private var isNegativeHabit: Bool { habit.completionStyle == .avoidance }

    private var isFutureDate: Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
    }

    /// The seven days ending today, oldest first.
    private var weekDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    /// Raw completion state (0 = not done, 1 / 2 / 3) for a day in the window.
    private func state(on day: Date) -> Int {
        guard let entry = entriesLast7Days[calendar.startOfDay(for: day)] else { return 0 }
        return Int(entry.effectiveCompletionState.rawValue)
    }

    private var completedDaysOfSeven: Int {
        weekDays.filter { state(on: $0) != 0 }.count
    }

    // MARK: - Body

    var body: some View {
        Button(action: handleTap) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    // Large text: name above the grid.
                    VStack(alignment: .leading, spacing: 8) {
                        identity
                        weekGrid
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    // One line; the name truncates before the grid ever moves,
                    // so every row in the card has the same shape.
                    HStack(spacing: 12) {
                        identity
                        Spacer(minLength: 12)
                        weekGrid
                    }
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFutureDate)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(habit.name ?? "Habit")
        .accessibilityValue(accessibilityValueText)
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint("Double-tap to mark today")
        .contextMenu {
            if shouldTrackDetails {
                Button("Log Details", systemImage: "info.circle") { showingDetailView = true }
            }
            Button("Edit Habit", systemImage: "pencil") { showingEditSheet = true }
            Button("Delete Habit", systemImage: "trash", role: .destructive, action: onRequestDelete)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onRequestDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            Button {
                showingEditSheet = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Color.accentColor)
        }
        .sheet(isPresented: $showingDetailView) {
            HabitCompletionDetailView(habit: habit, date: date)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHabitView(habit: habit)
        }
        .animation(.default, value: isChecked)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTick)
    }

    // MARK: - Pieces

    /// Coloured glyph + name + streak. Identity only, no background shape.
    private var identity: some View {
        HStack(spacing: 10) {
            Image(systemName: habit.icon ?? "circle")
                .font(.body)
                .foregroundStyle(habitColor)
                .frame(width: glyphWidth)

            Text(habit.name ?? "")
                .font(.body)
                .foregroundStyle(isChecked ? .secondary : .primary)
                .lineLimit(1)
                .layoutPriority(-1) // give way to the grid, never push it

            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak)")
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
            }
        }
    }

    /// Last 7 days, oldest → newest. Today is the rightmost cell.
    private var weekGrid: some View {
        HStack(spacing: cellSpacing) {
            ForEach(weekDays, id: \.self) { day in
                dayCell(for: day, isToday: calendar.isDateInToday(day))
            }
        }
        .fixedSize()
    }

    @ViewBuilder
    private func dayCell(for day: Date, isToday: Bool) -> some View {
        let dayState = state(on: day)
        let shape = RoundedRectangle(cornerRadius: cellSize * 0.22, style: .continuous)

        if dayState != 0 {
            shape
                .fill(color(forState: dayState))
                .frame(width: cellSize, height: cellSize)
                .overlay {
                    if isToday {
                        Image(systemName: symbol(forState: dayState))
                            .font(.system(size: cellSize * 0.55, weight: .bold))
                            .foregroundStyle(AppTheme.readableForeground(onHex: hex(forState: dayState)))
                    }
                }
        } else if isToday {
            shape
                .strokeBorder(habitColor, lineWidth: 2)
                .frame(width: cellSize, height: cellSize)
        } else {
            shape
                .fill(Color(.systemGray5))
                .frame(width: cellSize, height: cellSize)
        }
    }

    // MARK: - Actions

    private func handleTap() {
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

    // MARK: - State appearance

    /// Cell colour for a day's state. Simple habits use their own colour;
    /// multi-state uses the brand success / partial / failed colours;
    /// avoidance (any state = slipped) uses failed.
    private func hex(forState state: Int) -> String {
        if isNegativeHabit { return AppTheme.failedHex }
        if !useMultipleStates { return habitColorHex }
        switch state {
        case 2: return AppTheme.partialHex
        case 3: return AppTheme.failedHex
        default: return AppTheme.successHex
        }
    }

    private func color(forState state: Int) -> Color { Color(hex: hex(forState: state)) }

    private func symbol(forState state: Int) -> String {
        if isNegativeHabit { return "xmark" }
        switch state {
        case 2: return "circle.lefthalf.filled"
        case 3: return "xmark"
        default: return "checkmark"
        }
    }

    /// Spoken value for the row.
    private var accessibilityValueText: String {
        let today: String
        if !isChecked { today = "Not done today" }
        else if isNegativeHabit { today = "Slipped today" }
        else {
            switch completionState.state {
            case 2: today = "Partial today"
            case 3: today = "Tried today"
            default: today = "Done today"
            }
        }
        return "\(today). \(completedDaysOfSeven) of the last 7 days."
    }
}
