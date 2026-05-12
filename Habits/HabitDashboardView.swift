//
//  HabitDashboardView.swift
//  Bullet Tracker
//
//  Dashboard for viewing habit analytics over time
//

import SwiftUI
import CoreData

struct HabitDashboardView: View {
    @State private var viewModel = HabitDashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasLoadedOnce = false

    var body: some View {
        NavigationStack {
            List {
                // Time period selector
                Section {
                    Picker("Period", selection: $viewModel.selectedPeriod) {
                        ForEach(DashboardTimePeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                if viewModel.habits.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Habits Yet", systemImage: "chart.bar")
                        } description: {
                            Text("Add habits in the Today tab to see your analytics here.")
                        }
                        .listRowBackground(Color.clear)
                    }
                } else {
                    // Overall summary
                    Section("Overall Progress") {
                        HStack(spacing: 0) {
                            summaryStatView(
                                icon: "chart.bar.fill",
                                value: "\(viewModel.overallCompletionRate)%",
                                label: "Completion",
                                color: .accentColor
                            )
                            summaryStatView(
                                icon: "trophy.fill",
                                value: "\(viewModel.bestStreak)",
                                label: "Best Streak",
                                color: .orange
                            )
                            summaryStatView(
                                icon: "flame.fill",
                                value: "\(viewModel.currentStreak)",
                                label: "Current",
                                color: .green
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    }

                    // Per-habit breakdown
                    Section("By Habit") {
                        ForEach(viewModel.habitStats) { stat in
                            NavigationLink(destination: HabitDetailDashboardView(
                                habit: viewModel.habits.first { $0.id == stat.id }
                            )) {
                                habitStatRow(stat)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dashboard")
            .onAppear {
                if !hasLoadedOnce {
                    viewModel.loadData()
                    hasLoadedOnce = true
                }
            }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.loadData()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.loadData()
                }
            }
        }
    }

    // MARK: - Summary Stat

    private func summaryStatView(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Habit Stat Row

    private func habitStatRow(_ stat: HabitStatData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stat.icon)
                    .font(.body)
                    .foregroundStyle(Color(hex: stat.color))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: stat.color).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(stat.name)
                    .font(.body)

                Spacer()

                Text("\(stat.completionRate)%")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: stat.color))
                        .frame(width: geometry.size.width * CGFloat(stat.completionRate) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HabitDashboardView()
}
