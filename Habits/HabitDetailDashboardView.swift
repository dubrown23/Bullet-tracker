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
    let period: DashboardTimePeriod

    @State private var viewModel = HabitDetailViewModel()

    var body: some View {
        Group {
            if let habit = habit {
                List {
                    // Habit header
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

                    // Stats
                    Section("Statistics") {
                        LabeledContent("Completion Rate") {
                            Text("\(viewModel.completionRate)%")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(hex: habit.color ?? "#007AFF"))
                        }
                        LabeledContent("Days Completed") {
                            Text("\(viewModel.completedDays) of \(viewModel.totalDays)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Streaks
                    Section("Streaks") {
                        Label {
                            HStack {
                                Text("Current")
                                Spacer()
                                Text("\(viewModel.currentStreak) days")
                                    .fontWeight(.semibold)
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
                                    .fontWeight(.semibold)
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
                                    .fontWeight(.semibold)
                            }
                        } icon: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }

                    // Calendar heatmap
                    Section("Activity") {
                        CalendarHeatmapView(
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
        .onAppear {
            if let habit = habit {
                viewModel.loadData(for: habit, period: period)
            }
        }
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

    func loadData(for habit: Habit, period: DashboardTimePeriod) {
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
                let endDate = Date()
                let startDate = period.startDate(from: endDate)

                var dates: [Date] = []
                var currentDate = calendar.startOfDay(for: startDate)
                let endDay = calendar.startOfDay(for: endDate)
                while currentDate <= endDay {
                    dates.append(currentDate)
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                    currentDate = nextDate
                }

                let today = calendar.startOfDay(for: Date())
                let streakStart = calendar.date(byAdding: .day, value: -365, to: today) ?? startDate
                let fetchStart = min(streakStart, startDate)
                let entries = service.fetchEntries(for: bgHabit, from: fetchStart, to: endDate, using: bgContext)

                let completionResult = service.calculateCompletionRate(
                    for: bgHabit, using: entries, from: startDate, to: endDate
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
                let best = service.calculateBestStreak(for: bgHabit, using: entries, from: startDate, to: endDate)

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
        HabitDetailDashboardView(habit: nil, period: .month)
    }
}
