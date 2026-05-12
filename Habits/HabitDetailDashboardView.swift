//
//  HabitDetailDashboardView.swift
//  Bullet Tracker
//
//  Detail view for individual habit statistics
//

import SwiftUI
import CoreData

// MARK: - Habit Detail Dashboard View

struct HabitDetailDashboardView: View {
    let habit: Habit?

    @State private var viewModel = HabitDetailViewModel()
    @State private var rangeEnd: Date = Calendar.current.startOfDay(for: Date())
    @State private var rangeStart: Date = Calendar.current.date(
        byAdding: .day, value: -83,
        to: Calendar.current.startOfDay(for: Date())
    )!

    private let calendar = Calendar.current

    private var weekCount: Int {
        let days = calendar.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 0
        return max(1, (days + 7) / 7)
    }

    private var dateRangeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: rangeStart)) – \(fmt.string(from: rangeEnd))"
    }

    private var isAtToday: Bool {
        rangeEnd >= calendar.startOfDay(for: Date())
    }

    var body: some View {
        Group {
            if let habit = habit {
                List {
                    Section {
                        HStack(spacing: 14) {
                            Image(systemName: habit.icon ?? "circle")
                                .font(.title2)
                                .foregroundStyle(Color(hex: habit.color ?? "#007AFF"))
                                .frame(width: 44, height: 44)
                                .background(Color(hex: habit.color ?? "#007AFF").opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

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

                    Section("Statistics") {
                        LabeledContent("Completion Rate") {
                            Text("\(viewModel.completionRate)%")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(Color(hex: habit.color ?? "#007AFF"))
                        }
                        LabeledContent("Days Completed") {
                            Text("\(viewModel.completedDays) of \(viewModel.totalDays)")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Streaks") {
                        Label {
                            HStack {
                                Text("Current")
                                Spacer()
                                Text("\(viewModel.currentStreak) days")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                        } icon: {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                        }

                        Label {
                            HStack {
                                Text("Best")
                                Spacer()
                                Text("\(viewModel.bestStreak) days")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                        } icon: {
                            Image(systemName: "trophy.fill")
                                .foregroundStyle(.yellow)
                        }

                        Label {
                            HStack {
                                Text("Total Completions")
                                Spacer()
                                Text("\(viewModel.completedDays)")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    Section("Activity") {
                        // Navigation + month picker
                        HStack {
                            Button {
                                rangeStart = calendar.date(byAdding: .day, value: -7, to: rangeStart)!
                                rangeEnd = calendar.date(byAdding: .day, value: -7, to: rangeEnd)!
                            } label: {
                                Image(systemName: "chevron.left")
                            }
                            .buttonStyle(.borderless)

                            Spacer()

                            Menu {
                                Button("Today") {
                                    let today = calendar.startOfDay(for: Date())
                                    let duration = calendar.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 83
                                    rangeEnd = today
                                    rangeStart = calendar.date(byAdding: .day, value: -duration, to: today)!
                                }
                                Divider()
                                ForEach(0..<12, id: \.self) { i in
                                    let monthDate = calendar.date(byAdding: .month, value: -i, to: Date())!
                                    Button(monthDisplayName(for: monthDate)) {
                                        selectMonth(monthDate)
                                    }
                                }
                            } label: {
                                Text(dateRangeText)
                                    .font(.subheadline)
                                    .foregroundStyle(isAtToday ? .secondary : .primary)
                            }

                            Spacer()

                            Button {
                                let today = calendar.startOfDay(for: Date())
                                let newEnd = min(calendar.date(byAdding: .day, value: 7, to: rangeEnd)!, today)
                                rangeStart = calendar.date(byAdding: .day, value: 7, to: rangeStart)!
                                rangeEnd = newEnd
                            } label: {
                                Image(systemName: "chevron.right")
                            }
                            .buttonStyle(.borderless)
                            .disabled(isAtToday)
                        }

                        // Week count stepper
                        Stepper("\(weekCount) weeks") {
                            if weekCount < 52 {
                                rangeStart = calendar.date(byAdding: .day, value: -7, to: rangeStart)!
                            }
                        } onDecrement: {
                            if weekCount > 2 {
                                rangeStart = calendar.date(byAdding: .day, value: 7, to: rangeStart)!
                            }
                        }

                        // Heatmap
                        ContributionHeatmapView(
                            dates: viewModel.heatmapDates,
                            completionData: viewModel.dailyCompletion,
                            habitColor: Color(hex: habit.color ?? "#007AFF")
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
        .onAppear { reloadData() }
        .onChange(of: rangeStart) { reloadData() }
        .onChange(of: rangeEnd) { reloadData() }
    }

    private func reloadData() {
        if let habit = habit {
            viewModel.loadData(for: habit, from: rangeStart, to: rangeEnd)
        }
    }

    // MARK: - Month Selection

    private func monthDisplayName(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date)
    }

    private func selectMonth(_ monthDate: Date) {
        let comps = calendar.dateComponents([.year, .month], from: monthDate)
        guard let monthStart = calendar.date(from: comps),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
              let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth) else { return }

        let today = calendar.startOfDay(for: Date())
        rangeStart = monthStart
        rangeEnd = min(monthEnd, today)
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
    var isLoading: Bool = false

    private let calculationService = HabitCalculationService.shared

    func loadData(for habit: Habit, from startDate: Date, to endDate: Date) {
        isLoading = true

        let habitObjectID = habit.objectID

        Task {
            let bgContext = CoreDataManager.shared.container.newBackgroundContext()
            let service = HabitCalculationService.shared

            let results: (rate: Int, completed: Int, total: Int, streak: Int, best: Int, dates: [Date], completion: [Date: Double]) = await bgContext.perform {
                guard let bgHabit = try? bgContext.existingObject(with: habitObjectID) as? Habit else {
                    return (0, 0, 0, 0, 0, [], [:])
                }

                let calendar = Calendar.current
                let heatmapStart = calendar.startOfDay(for: startDate)
                let endDay = calendar.startOfDay(for: endDate)

                var dates: [Date] = []
                var currentDate = heatmapStart
                while currentDate <= endDay {
                    dates.append(currentDate)
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                    currentDate = nextDate
                }

                let today = calendar.startOfDay(for: Date())
                let streakStart = calendar.date(byAdding: .day, value: -365, to: today) ?? heatmapStart
                let fetchStart = min(streakStart, heatmapStart)
                let entries = service.fetchEntries(for: bgHabit, from: fetchStart, to: endDate, using: bgContext)

                let completionResult = service.calculateCompletionRate(
                    for: bgHabit, using: entries, from: heatmapStart, to: endDay
                )
                let total = completionResult.expected
                let completed = completionResult.completed
                let rate = total > 0 ? Int(completionResult.rate * 100) : 0

                var completion: [Date: Double] = [:]
                for date in dates {
                    let dayStart = calendar.startOfDay(for: date)
                    if let entry = entries[dayStart], entry.completionState > 0 {
                        completion[dayStart] = 1.0
                    } else {
                        completion[dayStart] = 0.0
                    }
                }

                let streak = service.calculateCurrentStreak(for: bgHabit, using: entries)
                let best = service.calculateBestStreak(for: bgHabit, using: entries, from: heatmapStart, to: endDay)

                return (rate, completed, total, streak, best, dates, completion)
            }

            self.completionRate = results.rate
            self.completedDays = results.completed
            self.totalDays = results.total
            self.currentStreak = results.streak
            self.bestStreak = results.best
            self.heatmapDates = results.dates
            self.dailyCompletion = results.completion
            self.isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        HabitDetailDashboardView(habit: nil)
    }
}
