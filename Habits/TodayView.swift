//
//  TodayView.swift
//  Bullet Tracker
//
//  Daily habit checklist using native iOS patterns.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: [SortDescriptor(\Habit.order), SortDescriptor(\Habit.name)])
    private var habits: [Habit]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = TodayViewModel()

    private var trackableHabits: [Habit] { viewModel.trackableHabits(from: habits) }

    var body: some View {
        NavigationStack {
            List {
                // Progress section
                Section {
                    progressRow
                }

                // Habits section
                if trackableHabits.isEmpty {
                    Section {
                        emptyContent
                    }
                } else {
                    Section {
                        ForEach(trackableHabits) { habit in
                            TodayHabitRowView(
                                habit: habit,
                                date: viewModel.selectedDate,
                                streak: viewModel.currentStreak(for: habit)
                            )
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(viewModel.dateDisplayString)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 16) {
                        Button(action: { viewModel.goToPreviousDay() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }

                        Button(action: { viewModel.goToNextDay() }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .disabled(viewModel.isToday)
                        .opacity(viewModel.isToday ? 0.3 : 1.0)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !viewModel.isToday {
                            Button("Today") { viewModel.goToToday() }
                        }
                        Button(action: { viewModel.showingAddHabitSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingAddHabitSheet) {
                AddHabitView()
            }
            .sheet(item: $viewModel.selectedHabit) { habit in
                EditHabitView(habit: habit)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    let today = Calendar.current.startOfDay(for: Date())
                    if viewModel.selectedDate != today {
                        viewModel.goToToday()
                    }
                }
            }
        }
    }

    // MARK: - Progress Row

    private var progressRow: some View {
        let completedCount = viewModel.completedCount(from: habits)
        let totalCount = viewModel.totalCount(from: habits)
        let progress = viewModel.completionProgress(from: habits)

        return HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 8)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress >= 1.0 ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                Text("\(completedCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.default, value: completedCount)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("\(completedCount)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                    Text(" of \(totalCount) complete")
                        .font(.headline)
                }
                .animation(.default, value: completedCount)

                Text(viewModel.progressMessage(from: habits))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Empty Content

    private var emptyContent: some View {
        VStack(spacing: 12) {
            if habits.isEmpty {
                ContentUnavailableView {
                    Label("No Habits", systemImage: "checkmark.circle")
                } description: {
                    Text("Add your first habit to start tracking.")
                } actions: {
                    Button("Add Habit") {
                        viewModel.showingAddHabitSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView {
                    Label("Nothing Scheduled", systemImage: "moon.zzz")
                } description: {
                    Text("No habits are scheduled for this day.")
                }
            }
        }
        .listRowBackground(Color.clear)
    }
}
