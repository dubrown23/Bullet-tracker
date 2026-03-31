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

    @StateObject private var viewModel = HabitDetailViewModel()

    var body: some View {
        ScrollView {
            if let habit = habit {
                VStack(spacing: 20) {
                    // Habit header
                    habitHeader(habit)

                    // Stats cards
                    statsCards

                    // Calendar heatmap for this habit
                    habitHeatmapCard

                    // Streak info
                    streakCard
                }
                .padding()
            } else {
                Text("Habit not found")
                    .foregroundColor(.secondary)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(habit?.name ?? "Habit Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let habit = habit {
                viewModel.loadData(for: habit, period: period)
            }
        }
    }

    private func habitHeader(_ habit: Habit) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: habit.color ?? "#007AFF").opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: habit.icon ?? "circle")
                    .font(.system(size: 28))
                    .foregroundColor(Color(hex: habit.color ?? "#007AFF"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name ?? "")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(habit.frequency?.capitalized ?? "Daily")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    private var statsCards: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Completion",
                value: "\(viewModel.completionRate)%",
                subtitle: "\(viewModel.completedDays)/\(viewModel.totalDays) days",
                color: Color(hex: habit?.color ?? "#007AFF")
            )

            StatCard(
                title: "Current Streak",
                value: "\(viewModel.currentStreak)",
                subtitle: "days",
                color: .green
            )

            StatCard(
                title: "Best Streak",
                value: "\(viewModel.bestStreak)",
                subtitle: "days",
                color: .orange
            )
        }
    }

    private var habitHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: habit?.color ?? "#007AFF"))
                Text("Completion Calendar")
                    .font(.headline)
            }

            CalendarHeatmapView(
                dates: viewModel.heatmapDates,
                completionData: viewModel.dailyCompletion,
                habitColor: Color(hex: habit?.color ?? "#007AFF")
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "flame")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                Text("Streak History")
                    .font(.headline)
            }

            VStack(spacing: 8) {
                HStack {
                    Label("Current Streak", systemImage: "flame.fill")
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(viewModel.currentStreak) days")
                        .fontWeight(.semibold)
                }

                Divider()

                HStack {
                    Label("Best Streak", systemImage: "trophy.fill")
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("\(viewModel.bestStreak) days")
                        .fontWeight(.semibold)
                }

                Divider()

                HStack {
                    Label("Total Completions", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Text("\(viewModel.completedDays)")
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Habit Detail View Model

@MainActor
class HabitDetailViewModel: ObservableObject {
    @Published var completionRate: Int = 0
    @Published var completedDays: Int = 0
    @Published var totalDays: Int = 0
    @Published var currentStreak: Int = 0
    @Published var bestStreak: Int = 0
    @Published var heatmapDates: [Date] = []
    @Published var dailyCompletion: [Date: Double] = [:]
    @Published var isLoading: Bool = false

    private let calculationService = HabitCalculationService.shared

    func loadData(for habit: Habit, period: DashboardTimePeriod) {
        isLoading = true

        // Capture for background
        let habitObjectID = habit.objectID

        Task.detached {
            let bgContext = CoreDataManager.shared.container.newBackgroundContext()
            let service = HabitCalculationService.shared

            let results: (rate: Int, completed: Int, total: Int, streak: Int, best: Int, dates: [Date], completion: [Date: Double]) = await bgContext.perform {
                guard let bgHabit = try? bgContext.existingObject(with: habitObjectID) as? Habit else {
                    return (0, 0, 0, 0, 0, [], [:])
                }

                let calendar = Calendar.current
                let endDate = Date()
                let startDate = period.startDate(from: endDate)

                // Build dates array
                var dates: [Date] = []
                var currentDate = calendar.startOfDay(for: startDate)
                let endDay = calendar.startOfDay(for: endDate)
                while currentDate <= endDay {
                    dates.append(currentDate)
                    guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                    currentDate = nextDate
                }

                // Single batch fetch covering both period stats and streak lookback
                let today = calendar.startOfDay(for: Date())
                let streakStart = calendar.date(byAdding: .day, value: -365, to: today) ?? startDate
                let fetchStart = min(streakStart, startDate)
                let entries = service.fetchEntries(for: bgHabit, from: fetchStart, to: endDate, using: bgContext)

                // Completion rate
                let completionResult = service.calculateCompletionRate(
                    for: bgHabit, using: entries, from: startDate, to: endDate
                )
                let total = completionResult.expected
                let completed = completionResult.completed
                let rate = total > 0 ? Int(completionResult.rate * 100) : 0

                // Daily completion map
                var completion: [Date: Double] = [:]
                for date in dates {
                    let dayStart = calendar.startOfDay(for: date)
                    if let entry = entries[dayStart], entry.completionState > 0 {
                        completion[dayStart] = 1.0
                    } else {
                        completion[dayStart] = 0.0
                    }
                }

                // Streaks
                let streak = service.calculateCurrentStreak(for: bgHabit, using: entries)
                let best = service.calculateBestStreak(for: bgHabit, using: entries, from: startDate, to: endDate)

                return (rate, completed, total, streak, best, dates, completion)
            }

            await MainActor.run {
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
}

#Preview {
    NavigationStack {
        HabitDetailDashboardView(habit: nil, period: .month)
    }
}
