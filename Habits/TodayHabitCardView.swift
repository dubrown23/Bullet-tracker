//
//  TodayHabitCardView.swift
//  Bullet Tracker
//
//  Native iOS list row for habit tracking in the Today view.
//
//  bt-0013 — week-grid row (the Everyday / Loop / HabitNow pattern):
//
//      🏃 Workout  🔥3            ▪ ▪ ▫ ▪ ▪ ▫ ◻
//                                 ──────────┬─
//                                   selected day (outlined until done)
//
//  • Seven real-sized cells ending on the selected day, newest on the right,
//    coloured by that day's state. **Every cell is a button**: tap a square to
//    flip that day (direct manipulation). Tapping the name flips the selected
//    day. The day arrows in the toolbar slide the whole window.
//  • Icon is a plain coloured glyph next to the name — identity only.
//  • Edit / Delete / Log Details live on long-press and swipe.
//  • At accessibility text sizes the name sits above the grid.
//

import SwiftUI
import SwiftData

// MARK: - Week grid geometry (shared with the day-letter header in TodayView)

/// One place for the cell/slot sizes so the header letters line up with the
/// squares exactly. Each square sits centred in a `slotWidth`-wide, 44pt-tall
/// hit area; slots touch, so the whole strip is tappable with no dead gaps.
struct WeekGridMetrics {
    let cellSize: CGFloat
    let slotWidth: CGFloat
    static let dayCount = 7
    static let hitHeight: CGFloat = 44

    /// - Parameters:
    ///   - scaledBase: a `@ScaledMetric` base (24 at default text size).
    ///   - isRegularWidth: unfolded Duo / iPad → slightly larger squares.
    init(scaledBase: CGFloat, isRegularWidth: Bool) {
        // Cap the Dynamic Type growth: at accessibility sizes the base would
        // reach ~58pt and seven cells no longer fit a folded-phone card (the
        // name moves above the grid at those sizes anyway).
        let base = min(scaledBase, 32)
        let size = isRegularWidth ? base * 1.2 : base
        cellSize = size
        // Compact: 4pt gaps keep a 7-day strip at 196pt so the habit name
        // keeps ~84pt beside it on a folded phone with default row insets.
        slotWidth = size + (isRegularWidth ? 8 : 4)
    }

    var stripWidth: CGFloat { slotWidth * CGFloat(Self.dayCount) }

    /// The 7 days to show for a selected day. The window stays anchored to
    /// today (today = rightmost square) and the arrows move the highlight
    /// across it; only when the selection leaves the last 7 days does the
    /// window slide so the selected day is the rightmost square.
    static func windowDays(for selected: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: selected)
        let daysBack = calendar.dateComponents([.day], from: selectedDay, to: today).day ?? 0
        let end = (0..<dayCount).contains(daysBack) ? today : selectedDay
        return (0..<dayCount).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: end)
        }
    }
}

// MARK: - Row

struct TodayHabitRowView: View {
    let habit: Habit
    /// The selected day (today, or wherever the toolbar arrows went). The
    /// grid stays anchored to today; this day is the highlighted cell.
    let date: Date
    let streak: Int
    /// Asks the owner (TodayView) to confirm + delete. The confirmation alert
    /// must live on a stable ancestor: when a swipe action fires, List tears
    /// the row down, and any alert presented from row state vanishes with it.
    let onRequestDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var detailTarget: DetailTarget?
    @State private var showingEditSheet = false
    /// Bumped on every check / uncheck / cycle so `.sensoryFeedback` fires
    /// exactly once per user action (and not when the row re-renders).
    @State private var feedbackTick = 0

    @ScaledMetric(relativeTo: .body) private var cellBase: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var glyphWidth: CGFloat = 24

    private struct DetailTarget: Identifiable {
        let date: Date
        var id: Date { date }
    }

    private var metrics: WeekGridMetrics {
        WeekGridMetrics(scaledBase: cellBase, isRegularWidth: horizontalSizeClass == .regular)
    }

    // MARK: - Data

    /// The seven visible days, oldest first (see `WeekGridMetrics.windowDays`).
    private var weekDays: [Date] {
        WeekGridMetrics.windowDays(for: date, calendar: calendar)
    }

    /// One indexed range fetch for the visible window; every per-day read
    /// below comes from this dictionary.
    private var entriesInWindow: [Date: HabitEntry] {
        guard let first = weekDays.first, let last = weekDays.last else { return [:] }
        return HabitStore.entriesByDay(for: habit, from: first, to: last)
    }

    private func entry(on day: Date) -> HabitEntry? {
        entriesInWindow[calendar.startOfDay(for: day)]
    }

    /// Raw completion state (0 = not done, 1 / 2 / 3) for a day in the window.
    private func state(on day: Date) -> Int {
        guard let entry = entry(on: day) else { return 0 }
        return Int(entry.effectiveCompletionState.rawValue)
    }

    private var selectedState: HabitCompletionState {
        HabitStore.completionState(for: habit, entry: entry(on: date))
    }

    private var isSelectedDayDone: Bool { selectedState.isCompleted }

    private var habitColorHex: String { habit.color ?? AppTheme.accentHex }
    private var habitColor: Color { Color(hex: habitColorHex) }

    private var shouldTrackDetails: Bool { habit.detailKind != nil }
    private var useMultipleStates: Bool { habit.completionStyle == .multiState }
    private var isNegativeHabit: Bool { habit.completionStyle == .avoidance }

    private func isFuture(_ day: Date) -> Bool {
        calendar.startOfDay(for: day) > calendar.startOfDay(for: Date())
    }

    /// Days before the habit existed can't be logged (matches `shouldTrack`,
    /// which hides the habit on those days when you navigate to them).
    private func isBeforeStart(_ day: Date) -> Bool {
        guard let start = habit.startDate else { return false }
        return calendar.startOfDay(for: day) < calendar.startOfDay(for: start)
    }

    private func isEditable(_ day: Date) -> Bool {
        !isFuture(day) && !isBeforeStart(day)
    }

    private var completedDaysOfSeven: Int {
        weekDays.filter { state(on: $0) != 0 }.count
    }

    // MARK: - Body

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    identityButton
                    weekGrid
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(spacing: 8) {
                    identityButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                    weekGrid
                }
            }
        }
        .contextMenu {
            if shouldTrackDetails {
                Button("Log Details", systemImage: "info.circle") {
                    detailTarget = DetailTarget(date: date)
                }
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
        .sheet(item: $detailTarget) { target in
            HabitCompletionDetailView(habit: habit, date: target.date)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditHabitView(habit: habit)
        }
        .animation(.default, value: isSelectedDayDone)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTick)
    }

    // MARK: - Pieces

    /// Coloured glyph + name + streak. Tapping it flips the selected day —
    /// the big, easy target for the common case.
    private var identityButton: some View {
        Button {
            toggle(on: date)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: habit.icon ?? "circle")
                    .font(.body)
                    .foregroundStyle(habitColor)
                    .frame(width: glyphWidth)

                // The grid is `fixedSize`, so the name takes whatever is left
                // and truncates only when there genuinely isn't room.
                Text(habit.name ?? "")
                    .font(.body)
                    .foregroundStyle(isSelectedDayDone ? .secondary : .primary)
                    .lineLimit(1)

                if streak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(AppTheme.accent)
                        Text("\(streak)")
                    }
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, minHeight: WeekGridMetrics.hitHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEditable(date))
        .accessibilityLabel(habit.name ?? "Habit")
        .accessibilityValue(accessibilityValueText)
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint("Marks the selected day")
    }

    /// Seven tappable day cells, oldest → newest.
    private var weekGrid: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                dayCellButton(for: day)
            }
        }
        .fixedSize()
    }

    private func dayCellButton(for day: Date) -> some View {
        let dayState = state(on: day)
        let isSelected = calendar.isDate(day, inSameDayAs: date)

        // Avoidance: a past tracked day with no slip is a win → filled.
        let isCleanAvoidanceWin = isNegativeHabit && dayState == 0 && !isSelected && isEditable(day)

        return Button {
            toggle(on: day)
        } label: {
            dayCell(state: dayState, isSelected: isSelected, isCleanAvoidanceWin: isCleanAvoidanceWin)
                .opacity(isEditable(day) ? 1 : 0.35)
                .frame(width: metrics.slotWidth, height: WeekGridMetrics.hitHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEditable(day))
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
        .accessibilityValue(accessibilityStateText(for: dayState))
        .accessibilityAddTraits(isSelected ? [.isToggle, .isSelected] : .isToggle)
    }

    /// Shared `DaySquare` (bt-0015): same square family as the Journal strip.
    @ViewBuilder
    private func dayCell(state dayState: Int, isSelected: Bool, isCleanAvoidanceWin: Bool) -> some View {
        let size = metrics.cellSize

        if isCleanAvoidanceWin {
            DaySquare(size: size, style: .filled(habitColor))
        } else if dayState != 0 {
            DaySquare(size: size, style: .filled(color(forState: dayState))) {
                if isSelected {
                    Image(systemName: symbol(forState: dayState))
                        .font(.system(size: size * 0.55, weight: .bold))
                        .foregroundStyle(AppTheme.readableForeground(onHex: hex(forState: dayState)))
                }
            }
        } else if isSelected {
            DaySquare(size: size, style: .outlined(habitColor))
        } else {
            DaySquare(size: size, style: .empty)
        }
    }

    // MARK: - Actions

    /// Flip (or cycle) a day. Same rules for every cell: simple habits toggle,
    /// multi-state cycles done → partial → tried → clear, avoidance toggles
    /// "slipped".
    private func toggle(on day: Date) {
        guard isEditable(day) else { return }
        let current = state(on: day)

        feedbackTick += 1

        if current == 0 {
            // Avoidance writes `.failure` (the model's documented "slipped"
            // shape); everything else starts at `.success`.
            let firstState = isNegativeHabit ? 3 : 1
            HabitStore.setCompletion(for: habit, on: day, state: firstState, in: modelContext)
            if shouldTrackDetails {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    detailTarget = DetailTarget(date: day)
                }
            }
        } else if useMultipleStates && !isNegativeHabit {
            let next: Int
            switch current {
            case 1: next = 2
            case 2: next = 3
            default: next = 0
            }
            if next == 0 {
                HabitStore.removeEntry(for: habit, on: day, in: modelContext)
            } else {
                HabitStore.setCompletion(for: habit, on: day, state: next, in: modelContext)
            }
        } else {
            HabitStore.removeEntry(for: habit, on: day, in: modelContext)
        }
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

    private func accessibilityStateText(for state: Int) -> String {
        if state == 0 { return "Not done" }
        if isNegativeHabit { return "Slipped" }
        switch state {
        case 2: return "Partial"
        case 3: return "Tried"
        default: return "Done"
        }
    }

    /// Spoken value for the name button.
    private var accessibilityValueText: String {
        if isNegativeHabit {
            let slips = weekDays.filter { state(on: $0) != 0 }.count
            let todayText = state(on: date) != 0 ? "Slipped" : "Clean so far"
            return "\(todayText). \(slips) slip\(slips == 1 ? "" : "s") in the last 7 days."
        }
        return "\(accessibilityStateText(for: state(on: date))). \(completedDaysOfSeven) of the last 7 days."
    }
}
