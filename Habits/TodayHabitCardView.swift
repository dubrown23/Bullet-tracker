//
//  TodayHabitCardView.swift
//  Bullet Tracker
//
//  Native iOS list row for habit tracking in the Today view.
//
//  bt-0012 row design — one shape per row (the Reminders pattern):
//
//      [tile]  Workout                 🔥3  ⓘ  ▪▪▫▪▪▫▫
//
//  • The icon tile IS the button (44pt). Not done → tinted tile with the
//    habit's icon. Done → tile fills with the state colour and a state symbol
//    (✓ / ◐ / ✕) replaces the icon.
//  • The last-7-days strip is the trailing-most element, so every row's strip
//    lines up and the list reads as a 7-day grid.
//  • Numbers are primary text; colour lives in icons (contrast audit).
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

    /// Tile and strip scale with the user's text size (Dynamic Type).
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var daySquare: CGFloat = 8

    // MARK: - Data

    /// Wave 4.5 prefetch: one indexed range fetch returning up to 7 entries
    /// for this habit's last 7 days. Both `completionState` (today's render)
    /// and `last7Days` (strip) read from this dict instead of issuing
    /// per-day single-row queries.
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

    /// Last 7 days completion for the strip — derived from `entriesLast7Days`.
    private var last7Days: [Bool] {
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { daysAgo in
            guard let d = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return false }
            let dayStart = calendar.startOfDay(for: d)
            guard let entry = entriesLast7Days[dayStart] else { return false }
            return entry.effectiveCompletionState != .notDone
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Accessibility text sizes: stack so nothing is squeezed off the card.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        tileButton
                        nameText
                    }
                    HStack(spacing: 12) {
                        streakBadge
                        detailsButton
                        Spacer()
                        weekStrip
                    }
                }
            } else {
                HStack(spacing: 14) {
                    tileButton
                    nameText   // expands to fill; no separate Spacer needed
                    streakBadge
                    detailsButton
                    weekStrip
                }
            }
        }
        // Edit / delete (bt-0012): before this there was no way to reach
        // EditHabitView from the UI at all. Three standard routes — tap the
        // name, long-press for a context menu, or swipe (compact width).
        .contextMenu {
            Button("Edit Habit", systemImage: "pencil") { showingEditSheet = true }
            Button("Delete Habit", systemImage: "trash", role: .destructive, action: onRequestDelete)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onRequestDelete) {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red) // the app-wide accent tint otherwise overrides the destructive red
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

    /// The tile is the control: a real Button with a name, a value and the
    /// toggle trait for VoiceOver.
    private var tileButton: some View {
        Button(action: handleTileTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isChecked ? stateColor : habitColor.opacity(0.16))

                if isChecked {
                    Image(systemName: stateSymbol)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.readableForeground(onHex: stateColorHex))
                        .symbolEffect(.bounce, value: isChecked)
                } else {
                    Image(systemName: habit.icon ?? "circle")
                        .font(.title3)
                        .foregroundStyle(habitColor)
                }
            }
            .frame(width: tileSize, height: tileSize)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isFutureDate)
        .accessibilityLabel(habit.name ?? "Habit")
        .accessibilityValue(accessibilityStateDescription)
        .accessibilityAddTraits(.isToggle)
    }

    /// Tapping the name opens the habit's settings (edit / delete).
    private var nameText: some View {
        Button {
            showingEditSheet = true
        } label: {
            Text(habit.name ?? "")
                .font(.body)
                .foregroundStyle(isChecked ? .secondary : .primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens habit settings")
    }

    /// Flame icon in orange, count in primary text (icon carries the colour,
    /// text carries the contrast).
    @ViewBuilder
    private var streakBadge: some View {
        if streak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text("\(streak)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day streak")
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

    /// Last 7 days, oldest → newest, as small squares. Trailing-most element so
    /// every row's strip is right-aligned into a grid.
    private var weekStrip: some View {
        HStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(last7Days[index] ? habitColor : Color(.systemGray4))
                    .frame(width: daySquare, height: daySquare)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last 7 days: \(last7Days.filter { $0 }.count) of 7 completed")
    }

    // MARK: - Actions

    private func handleTileTap() {
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

    /// Fill colour of a completed tile. Simple habits use their own colour;
    /// multi-state uses the brand success / partial / failed colours;
    /// avoidance (checked = slipped) uses failed.
    private var stateColorHex: String {
        if isNegativeHabit { return AppTheme.failedHex }
        if !useMultipleStates { return habitColorHex }
        switch completionState.state {
        case 2: return AppTheme.partialHex
        case 3: return AppTheme.failedHex
        default: return AppTheme.successHex
        }
    }

    private var stateColor: Color { Color(hex: stateColorHex) }

    private var stateSymbol: String {
        if isNegativeHabit { return "xmark" }
        switch completionState.state {
        case 2: return "circle.lefthalf.filled"
        case 3: return "xmark"
        default: return "checkmark"
        }
    }

    /// Spoken value for the tile.
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
