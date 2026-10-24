//
//  HabitDashboardView.swift
//  Bullet Tracker
//
//  Dashboard for viewing habit analytics over time
//

import SwiftUI
import SwiftData

struct HabitDashboardView: View {
    @Query(sort: [SortDescriptor(\Habit.order), SortDescriptor(\Habit.name)])
    private var habits: [Habit]

    @State private var viewModel = HabitDashboardViewModel()
    @State private var selectedHabit: Habit?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

                if habits.isEmpty {
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
                        // One habit per row folded, two per row unfolded / iPad
                        // (see `PairedRows`, bt-0009).
                        PairedRows(items: viewModel.habitStats) { stat in
                            habitCell(stat)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationDestination(item: $selectedHabit) { habit in
                HabitDetailDashboardView(habit: habit)
            }
            .navigationTitle("Dashboard")
            .onAppear { viewModel.loadData(habits: habits) }
            .onChange(of: viewModel.selectedPeriod) { _, _ in
                viewModel.loadData(habits: habits)
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

    // MARK: - Habit Cell

    /// Compact width: a standard `NavigationLink` row (system chevron + highlight).
    /// Regular width: two cells share one list row, and two `NavigationLink`s in
    /// one row fire together (verified on iPad sim, bt-0009). So wide cells are
    /// plain `Button`s that drive `navigationDestination(item:)` instead, with
    /// the chevron drawn in the label.
    @ViewBuilder
    private func habitCell(_ stat: HabitStatData) -> some View {
        let habit = habits.first { $0.id == stat.id }

        if horizontalSizeClass == .regular {
            Button {
                selectedHabit = habit
            } label: {
                habitStatRow(stat, showsChevron: true)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(destination: HabitDetailDashboardView(habit: habit)) {
                habitStatRow(stat, showsChevron: false)
            }
        }
    }

    // MARK: - Habit Stat Row

    private func habitStatRow(_ stat: HabitStatData, showsChevron: Bool) -> some View {
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

                if showsChevron {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
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
