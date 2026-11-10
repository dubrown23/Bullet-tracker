//
//  TodayHabitCardView.swift
//  Bullet Tracker
//
//  Native iOS list row for habit tracking in the Today view.
//
//  bt-0026 — one round control, six quiet dots (replaces bt-0013's week grid):
//
//      ◯  🏃 Workout                        ● ◐ ● ○ ● ●   🔥3
//            Auto · 45 min · 6,120 steps               [Back to Auto]
//
//  • The round control on the left is the ONLY way to mark the selected day
//    (simple toggles, multi-state cycles done → partial → tried → clear,
//    avoidance toggles "slipped"). 44 pt target, palette colours only — the
//    habit's colour lives on its glyph.
//  • Tapping the rest of the row opens Log Details.
//  • Six dots are the six days before the selected day, oldest first.
//    Display only (Dustin: too small to tap safely); a past day is edited in
//    Log Details or by stepping the day arrows.
//  • Flame + streak sit in a fixed trailing slot so the dots form columns.
//  • A graded habit (Diet / Workout) gets a caption line under the row for
//    every day from its go-live: the mode (Auto / Set by you / Set by voice)
//    and the day's numbers when known, plus "Back to Auto" when a hand grade
//    is in force. Same line every day, so rows keep their height.
//  • Rest / Back to Automatic / Edit / Delete stay on long-press; swipe
//    edits and deletes.
//  • At accessibility text sizes the dots drop under the name.
//

import SwiftUI
import SwiftData

// MARK: - Day windows (shared with the Journal / Dashboard date strips)

/// The seven-day window the date strips show (`DateStripBar`,
/// `DayJournalView`) and the Today row's own six-day look-back.
/// `hitHeight` is the row's 44 pt control height.
struct WeekGridMetrics {
    static let dayCount = 7
    static let hitHeight: CGFloat = 44

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

    /// bt-0026 — the `count` days before `selected`, **yesterday first**: the
    /// Today row's dots. The selected day itself is the round control, not a
    /// dot. Yesterday first (2026-10-30, Dustin's pick from a mock) so time
    /// runs one way across the row — the control, then yesterday beside the
    /// name, then back into the past towards the flame.
    static func previousDays(before selected: Date, count: Int = 6, calendar: Calendar) -> [Date] {
        let day = calendar.startOfDay(for: selected)
        return (1...max(count, 1)).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: day)
        }
    }
}

// MARK: - Row

struct TodayHabitRowView: View {
    let habit: Habit
    /// The selected day (today, or wherever the toolbar arrows went). The
    /// control shows this day; the dots show the six before it.
    let date: Date
    let streak: Int
    /// Asks the owner (TodayView) to confirm + delete. The confirmation alert
    /// must live on a stable ancestor: when a swipe action fires, List tears
    /// the row down, and any alert presented from row state vanishes with it.
    let onRequestDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var detailTarget: DetailTarget?
    @State private var showingEditSheet = false
    /// Bumped on every check / uncheck / cycle so `.sensoryFeedback` and the
    /// control's bounce fire exactly once per user action (and not when the
    /// row re-renders).
    @State private var feedbackTick = 0
    /// Live numbers for graded habits + "Back to Automatic" (bt-0018).
    @State private var engine = HabitSyncEngine.shared

    @ScaledMetric(relativeTo: .body) private var glyphWidth: CGFloat = 24

    /// The control's hit area (HIG minimum), the fixed streak slot, and the
    /// number of history dots.
    static let controlWidth: CGFloat = 44
    static let streakSlotWidth: CGFloat = 36
    static let dotCount = 6

    private struct DetailTarget: Identifiable {
        let date: Date
        var id: Date { date }
    }

    // MARK: - Data

    /// The six days before the selected day, yesterday first.
    private var dotDays: [Date] {
        WeekGridMetrics.previousDays(before: date, count: Self.dotCount, calendar: calendar)
    }

    /// One indexed range fetch for the visible window (dots + the selected
    /// day); every per-day read below comes from this dictionary.
    private var entriesInWindow: [Date: HabitEntry] {
        guard let oldest = dotDays.last else { return [:] }
        return HabitStore.entriesByDay(for: habit, from: oldest, to: calendar.startOfDay(for: date))
    }

    private func entry(on day: Date) -> HabitEntry? {
        entriesInWindow[calendar.startOfDay(for: day)]
    }

    /// Raw completion state (0 = not done, 1 / 2 / 3 / 4) for a day in the window.
    private func state(on day: Date) -> Int {
        guard let entry = entry(on: day) else { return 0 }
        return Int(entry.effectiveCompletionState.rawValue)
    }

    private func mark(on day: Date) -> DayMark {
        DayMark(state: entry(on: day)?.effectiveCompletionState, isAvoidance: isNegativeHabit)
    }

    private var selectedMark: DayMark { mark(on: date) }
    private var dotMarks: [DayMark] { dotDays.map(mark(on:)) }

    private var selectedState: HabitCompletionState {
        HabitStore.completionState(for: habit, entry: entry(on: date))
    }

    private var isSelectedDayDone: Bool { selectedState.isCompleted }

    private var habitColor: Color { Color(hex: habit.color ?? AppTheme.accentHex) }

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

    private let restState = Int(CompletionState.rest.rawValue)

    /// The selected day is a Rest day.
    private var isSelectedDayRest: Bool { state(on: date) == restState }

    /// bt-0021 / bt-0026 — the caption under a graded row, for every day
    /// from the habit's go-live: who set it (Auto / Set by you / Set by
    /// voice) and the day's numbers when known. Today's numbers are the
    /// engine's live ones; a past day's come from the `health` block the
    /// sync stored on the row.
    private var captionText: String? {
        guard habit.isAutoGraded, habit.isWithinGrading(date) else { return nil }
        let entry = entry(on: date)
        let source: EntrySource = (entry?.isOverride == true) ? (entry?.source ?? .auto) : .auto
        let mode = GradeWording.mode(source)
        let numbers: String?
        if calendar.isDateInToday(date) {
            numbers = engine.caption(for: habit)
        } else {
            numbers = entry?.health.flatMap { Self.numbers(from: $0, habit: habit) }
        }
        return [mode, numbers].compactMap { $0 }.joined(separator: " · ")
    }

    /// A stored day's numbers in the same words as the engine's live caption.
    static func numbers(from health: HealthSnapshot, habit: Habit) -> String? {
        let targets = habit.gradingTargets
        switch habit.gradingKind {
        case .diet?:
            guard health.totalProtein != nil || health.totalCalories != nil else { return nil }
            let protein = "\(Int(health.totalProtein ?? 0)) / \(Int(targets.proteinFloorGrams)) g"
            let calories = "\((health.totalCalories ?? 0).formatted(.number.precision(.fractionLength(0)))) cal"
            return "\(protein) · \(calories)"
        case .workout?:
            var parts: [String] = []
            if !health.sessions.isEmpty { parts.append("\(Int(health.totalMinutes)) min") }
            if let steps = health.steps { parts.append("\(steps.formatted()) steps") }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        case nil:
            return nil
        }
    }

    /// "Back to Automatic" is offered only on or after the go-live day
    /// (Dustin's rule: old rows count as hand, and history is never re-graded)
    /// and only when the day's row is a hand / voice row with a grade.
    private var canRevertToAutomatic: Bool {
        guard habit.isWithinGrading(date), let entry = entry(on: date) else { return false }
        return entry.isOverride
    }

    // MARK: - Body

    var body: some View {
        // A row can be asked to render in the same turn its habit is deleted
        // (the delete and an observable change landing together). Reading a
        // deleted model's fields asserts; draw nothing until @Query drops it.
        // `isDeleted` is only true while the delete is PENDING; once saved the
        // model is detached and its `modelContext` is nil, so check both.
        if habit.isDeleted || habit.modelContext == nil {
            EmptyView()
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        controlButton
                        detailsButton(showHistory: false)
                    }
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        DayDotStrip(days: dotDays, marks: dotMarks)
                        streakSlot
                    }
                }
            } else {
                HStack(spacing: 12) {
                    controlButton
                    detailsButton(showHistory: true)
                }
            }
            if let captionText {
                captionLine(captionText)
            }
        }
        .contextMenu {
            Button("Log Details", systemImage: "info.circle") {
                detailTarget = DetailTarget(date: date)
            }
            // bt-0018 — Rest is never reached by tapping; it lives here and
            // in Log Details, Workout-graded habits only.
            if habit.offersRest && isEditable(date) {
                Button(isSelectedDayRest ? "Clear Rest Day" : "Rest Day", systemImage: "zzz") {
                    toggleRest(on: date)
                }
            }
            if canRevertToAutomatic {
                Button("Back to Automatic", systemImage: "arrow.uturn.backward") {
                    Task { await engine.revertToAutomatic(habit: habit, day: date, in: modelContext) }
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
        .animation(.default, value: selectedMark)
        .sensoryFeedback(.impact(weight: .light), trigger: feedbackTick)
    }

    // MARK: - Pieces

    /// The round control: the one way to mark the selected day.
    private var controlButton: some View {
        Button {
            toggle(on: date)
        } label: {
            DayControl(mark: selectedMark, isAvoidance: isNegativeHabit, changeTick: feedbackTick)
                .frame(width: Self.controlWidth, height: WeekGridMetrics.hitHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isEditable(date) ? 1 : 0.35)
        .disabled(!isEditable(date))
        .accessibilityLabel(habit.name ?? "Habit")
        .accessibilityValue(selectedMark.spokenText(isAvoidance: isNegativeHabit))
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint("Marks the selected day")
    }

    /// Glyph + name (+ dots + streak): the rest of the row. Tapping it opens
    /// Log Details, the way a Reminders row opens the reminder.
    private func detailsButton(showHistory: Bool) -> some View {
        Button {
            detailTarget = DetailTarget(date: date)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: habit.icon ?? "circle")
                    .font(.body)
                    .foregroundStyle(habitColor)
                    .frame(width: glyphWidth)

                // Two lines before truncating, like a Reminders title: on the
                // folded Duo the dots + flame leave ~98 pt beside the glyph.
                Text(habit.name ?? "")
                    .font(.body)
                    .foregroundStyle(isSelectedDayDone ? .secondary : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showHistory {
                    DayDotStrip(days: dotDays, marks: dotMarks)
                    streakSlot
                }
            }
            .frame(maxWidth: .infinity, minHeight: WeekGridMetrics.hitHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(habit.name ?? "Habit") details")
        .accessibilityValue(historyValueText)
        .accessibilityHint("Opens Log Details")
    }

    /// Flame + count in a fixed-width slot, so the dots line up in columns
    /// whether or not the row has a streak.
    private var streakSlot: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            if streak > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(AppTheme.accent)
                    Text("\(streak)")
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
                .accessibilityLabel("\(streak) day streak")
            }
        }
        .frame(width: Self.streakSlotWidth)
    }

    /// bt-0018 / bt-0021 — the graded habit's line under the row, full
    /// width, with the way back to automatic on the row itself.
    private func captionLine(_ caption: String) -> some View {
        HStack(spacing: 8) {
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.numericText())
                .accessibilityLabel("\(calendar.isDateInToday(date) ? "Today" : "This day"): \(caption)")
            if canRevertToAutomatic {
                Spacer(minLength: 0)
                Button("Back to Auto") {
                    Task { await engine.revertToAutomatic(habit: habit, day: date, in: modelContext) }
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.mini)
                .tint(habitColor)
                .accessibilityHint("Clears your grade so the automatic one comes back")
            }
        }
        .padding(.leading, Self.controlWidth + 12 + glyphWidth + 10)
    }

    // MARK: - Actions

    /// Flip (or cycle) a day. Simple habits toggle, multi-state cycles
    /// done → partial → tried → clear, avoidance toggles "slipped".
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
            // An Active day (bt-0029) taps on to Tried, as Partial does.
            case 2, 5: next = 3
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

    /// Rest Day on / off (bt-0018). A hand write like any tap.
    private func toggleRest(on day: Date) {
        guard isEditable(day), habit.offersRest else { return }
        feedbackTick += 1
        if state(on: day) == restState {
            HabitStore.removeEntry(for: habit, on: day, in: modelContext)
        } else {
            HabitStore.setCompletion(for: habit, on: day, state: restState, in: modelContext)
        }
    }

    // MARK: - Accessibility

    /// The six dots, spoken as one value on the details button.
    private var historyValueText: String {
        let marks = dotMarks
        if isNegativeHabit {
            let slips = marks.filter { $0 == .missed }.count
            return "\(slips) slip\(slips == 1 ? "" : "s") in the \(marks.count) days before."
        }
        let done = marks.filter { $0 == .done || $0 == .partial }.count
        return "\(done) of the \(marks.count) days before done."
    }
}
