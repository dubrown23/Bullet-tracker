//
//  HabitDetailDashboardView.swift
//  Bullet Tracker
//
//  Detail page for one habit. bt-0023 fixes what the Dashboard pass found:
//  the heatmap now goes through the win rule (a Tried day is no longer full
//  colour; an avoidance habit's cells are its slips, bt-0024), Best is the
//  best run since the habit's clean start rather than inside the visible
//  range, the duplicate "Total Completions" row is gone, one range control
//  replaces the arrows + month menu + stepper and never starts before the
//  clean start (Weed read "0 of 84 days" when it did), and Edit is in the
//  toolbar.
//

import SwiftUI

// MARK: - Range

enum HabitDetailRange: String, CaseIterable, Identifiable {
    case fourWeeks = "4 weeks"
    case twelveWeeks = "12 weeks"
    case all = "All"

    var id: String { rawValue }

    /// Start of the range ending `today`, clamped to the habit's clean start.
    func start(today: Date, cleanStart: Date, calendar: Calendar = .current) -> Date {
        let todayStart = calendar.startOfDay(for: today)
        let clean = calendar.startOfDay(for: cleanStart)
        switch self {
        case .fourWeeks: return max(clean, calendar.date(byAdding: .day, value: -27, to: todayStart) ?? todayStart)
        case .twelveWeeks: return max(clean, calendar.date(byAdding: .day, value: -83, to: todayStart) ?? todayStart)
        case .all: return min(clean, todayStart)
        }
    }
}

// MARK: - Habit Detail Dashboard View

struct HabitDetailDashboardView: View {
    let habit: Habit?

    @State private var viewModel = HabitDetailViewModel()
    @State private var range: HabitDetailRange = .twelveWeeks
    @State private var showingEdit = false
    @ScaledMetric(relativeTo: .title2) private var tileSize: CGFloat = 44

    private let calendar = Calendar.current

    /// Falls back to the app accent (not iOS blue) when a habit has no colour.
    private var habitColor: Color {
        if let hex = habit?.color { return Color(hex: hex) }
        return AppTheme.accent
    }

    /// bt-0024 — avoidance: the page reads as a slip rate, no streaks.
    private var isSlipScored: Bool {
        guard let habit else { return false }
        return HabitWinRule.isSlipScored(style: habit.completionStyle)
    }

    private var rangeText: String {
        let days = viewModel.heatmapDates.count
        guard let first = viewModel.heatmapDates.first, let last = viewModel.heatmapDates.last else { return "" }
        let fmt = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(first.formatted(fmt)) – \(last.formatted(fmt)) · \(days) \(days == 1 ? "day" : "days")"
    }

    var body: some View {
        Group {
            if let habit = habit {
                List {
                    Section {
                        HStack(spacing: 14) {
                            HabitIconTile(
                                systemImage: habit.icon ?? "circle",
                                colorHex: habit.color ?? AppTheme.accentHex,
                                size: tileSize,
                                font: .title2
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name ?? "")
                                    .font(.headline)
                                Text(habit.frequency?.capitalized ?? "Daily")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // One range control; the footer shows the clamp.
                    Section {
                        Picker("Range", selection: $range) {
                            ForEach(HabitDetailRange.allCases) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)
                    } footer: {
                        Text(rangeText)
                    }

                    // bt-0024 — an avoidance habit is scored by its slips: a
                    // slip rate and the slip days, no streaks.
                    if isSlipScored {
                        Section("Statistics") {
                            LabeledContent("Slip Rate") {
                                Text("\(viewModel.completionRate)% slipped")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                            }
                            LabeledContent("Slipped") {
                                Text("\(viewModel.completedDays) of \(viewModel.totalDays) days")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Section("Statistics") {
                            LabeledContent("Completion Rate") {
                                Text("\(viewModel.completionRate)%")
                                    .font(.system(.body, design: .rounded, weight: .bold))
                            }
                            LabeledContent("Days Completed") {
                                Text("\(viewModel.completedDays) of \(viewModel.totalDays)")
                                    .font(.system(.body, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Section {
                            Label {
                                HStack {
                                    Text("Current")
                                    Spacer()
                                    Text(Self.dayCount(viewModel.currentStreak))
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                }
                            } icon: {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(AppTheme.accent)
                            }

                            Label {
                                HStack {
                                    Text("Best")
                                    Spacer()
                                    Text(Self.dayCount(viewModel.bestStreak))
                                        .font(.system(.body, design: .rounded, weight: .semibold))
                                }
                            } icon: {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(AppTheme.partial)
                            }
                        } header: {
                            Text("Streaks")
                        } footer: {
                            Text("Best is the longest run since \(viewModel.cleanStart.formatted(.dateTime.month(.abbreviated).day())), whatever the range above.")
                        }
                    }

                    Section("Activity") {
                        // Heatmap through the win rule — an avoidance habit's
                        // cells are its slips in the failed red (bt-0024).
                        ContributionHeatmapView(
                            dates: viewModel.heatmapDates,
                            completionData: viewModel.dailyCompletion,
                            habitColor: isSlipScored ? AppTheme.failed : habitColor,
                            countedDaysWord: isSlipScored ? "slipped" : "completed"
                        )
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView("Habit Not Found", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(habit?.name ?? "Details")
        .navigationBarTitleDisplayMode(.inline)
        // Edit is the only way in, so the bar never minimises away
        // (found on the Duo simulator render: scrolled, the button was gone).
        .keepNavigationBarVisible()
        .toolbar {
            if habit != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showingEdit = true }
                }
            }
        }
        .sheet(isPresented: $showingEdit, onDismiss: reloadData) {
            if let habit { EditHabitView(habit: habit) }
        }
        .onAppear { reloadData() }
        .onChange(of: range) { reloadData() }
    }

    private func reloadData() {
        if let habit = habit {
            viewModel.loadData(for: habit, range: range)
        }
    }

    /// "1 day" / "6 days".
    static func dayCount(_ n: Int) -> String {
        "\(n) \(n == 1 ? "day" : "days")"
    }
}

// MARK: - Habit Detail View Model

@MainActor
@Observable
class HabitDetailViewModel {
    var completionRate: Int = 0
    var completedDays: Int = 0
    var totalDays: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var heatmapDates: [Date] = []
    var dailyCompletion: [Date: Double] = [:]
    var cleanStart: Date = Date()

    private let calendar = Calendar.current
    private let calculationService = HabitCalculationService.shared

    func loadData(for habit: Habit, range: HabitDetailRange, today: Date = Date()) {
        let endDay = calendar.startOfDay(for: today)
        let clean = HistoryMigration.cleanStart(for: habit, calendar: calendar)
        cleanStart = clean
        let rangeStart = range.start(today: endDay, cleanStart: clean, calendar: calendar)

        // Heatmap day list.
        var dates: [Date] = []
        var currentDate = rangeStart
        while currentDate <= endDay {
            dates.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        // One fetch from the clean start: the range, Best and the streak
        // lookback all live inside it.
        let entries = HabitStore.entriesByDay(for: habit, from: min(clean, rangeStart), to: endDay)

        let completionResult = calculationService.calculateCompletionRate(
            for: habit, using: entries, from: rangeStart, to: endDay
        )

        dailyCompletion = Self.heatmap(for: habit, entries: entries, dates: dates, today: endDay, calendar: calendar)
        completionRate = completionResult.expected > 0 ? Int(completionResult.rate * 100) : 0
        completedDays = completionResult.completed
        totalDays = completionResult.expected
        currentStreak = calculationService.calculateCurrentStreak(for: habit, using: entries, allowingOpenToday: true, floor: clean)
        bestStreak = calculationService.calculateBestStreak(for: habit, using: entries, from: clean, to: endDay)
        heatmapDates = dates
    }

    /// bt-0023 — the cell value through the win rule: a positive habit's win
    /// is full colour, a Rest day a light tint, a Tried or empty day grey; an
    /// avoidance habit's slips are full colour and nothing else is (bt-0024).
    static func heatmap(for habit: Habit, entries: [Date: HabitEntry], dates: [Date], today: Date,
                        calendar: Calendar = .current) -> [Date: Double] {
        var completion: [Date: Double] = [:]
        let todayStart = calendar.startOfDay(for: today)
        for date in dates {
            let dayStart = calendar.startOfDay(for: date)
            let state = entries[dayStart]?.effectiveCompletionState
            if HabitWinRule.isSlipScored(style: habit.completionStyle) {
                completion[dayStart] = HabitWinRule.isSlip(style: habit.completionStyle, state: state) ? 1.0 : 0.0
            } else if HabitWinRule.isWin(style: habit.completionStyle, state: state, isFuture: dayStart > todayStart) {
                completion[dayStart] = 1.0
            } else if HabitWinRule.isNeutral(state: state) {
                completion[dayStart] = 0.4
            } else {
                completion[dayStart] = 0.0
            }
        }
        return completion
    }
}

#Preview {
    NavigationStack {
        HabitDetailDashboardView(habit: nil)
    }
}
