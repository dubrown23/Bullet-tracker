//
//  HabitDashboardView.swift
//  Bullet Tracker
//
//  Dashboard for viewing habit analytics over time
//

import SwiftUI
import CoreData

struct HabitDashboardView: View {
    @StateObject private var viewModel = HabitDashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xl) {
                    // Time period selector
                    periodSelector

                    if viewModel.habits.isEmpty {
                        emptyState
                    } else {
                        // Overall summary card
                        overallSummaryCard

                        // Per-habit breakdown - tap to see details
                        habitsBreakdownCard
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Only load on first appear, not every tab switch
                if !hasLoadedOnce {
                    viewModel.loadData()
                    hasLoadedOnce = true
                }
            }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.loadData()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Reload when app becomes active (to catch widget changes)
                if newPhase == .active {
                    viewModel.loadData()
                }
            }
        }
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(DashboardTimePeriod.allCases) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "chart.bar")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.accent)
            }

            Text("No Habits Yet")
                .font(AppTheme.Font.title)

            Text("Add habits in the Habits tab to see your analytics here.")
                .font(AppTheme.Font.body)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(40)
    }

    // MARK: - Overall Summary Card

    private var overallSummaryCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.accent)
                Text("Overall Progress")
                    .font(AppTheme.Font.headline)
            }

            HStack(spacing: AppTheme.Spacing.xl) {
                StatBox(
                    title: "Completion",
                    value: "\(viewModel.overallCompletionRate)%",
                    color: AppTheme.accent
                )

                StatBox(
                    title: "Best Streak",
                    value: "\(viewModel.bestStreak) days",
                    color: AppTheme.partial
                )

                StatBox(
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak) days",
                    color: AppTheme.success
                )
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.medium)
        .shadow(color: AppTheme.Shadow.small.color, radius: AppTheme.Shadow.small.radius, x: AppTheme.Shadow.small.x, y: AppTheme.Shadow.small.y)
    }

    // MARK: - Calendar Heatmap Card

    private var calendarHeatmapCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.success)
                Text("Activity")
                    .font(AppTheme.Font.headline)
            }

            CalendarHeatmapView(
                dates: viewModel.heatmapDates,
                completionData: viewModel.dailyCompletionRates
            )
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.medium)
        .shadow(color: AppTheme.Shadow.small.color, radius: AppTheme.Shadow.small.radius, x: AppTheme.Shadow.small.x, y: AppTheme.Shadow.small.y)
    }

    // MARK: - Habits Breakdown Card

    private var habitsBreakdownCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "list.bullet")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.accentLight)
                Text("By Habit")
                    .font(AppTheme.Font.headline)

                Spacer()

                Text("Tap for details")
                    .font(AppTheme.Font.caption)
                    .foregroundColor(AppTheme.textTertiary)
            }

            ForEach(viewModel.habitStats) { stat in
                NavigationLink(destination: HabitDetailDashboardView(
                    habit: viewModel.habits.first { $0.id == stat.id },
                    period: viewModel.selectedPeriod
                )) {
                    HabitStatRow(stat: stat)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.medium)
        .shadow(color: AppTheme.Shadow.small.color, radius: AppTheme.Shadow.small.radius, x: AppTheme.Shadow.small.x, y: AppTheme.Shadow.small.y)
    }
}

#Preview {
    HabitDashboardView()
}
