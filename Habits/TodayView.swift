//
//  TodayView.swift
//  Bullet Tracker
//
//  Daily habit checklist using native iOS patterns
//

import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                // Progress section
                Section {
                    progressRow
                }

                // Habits section
                if viewModel.trackableHabits.isEmpty {
                    Section {
                        emptyContent
                    }
                } else {
                    Section {
                        ForEach(viewModel.trackableHabits) { habit in
                            TodayHabitRowView(
                                habit: habit,
                                date: viewModel.selectedDate,
                                streak: viewModel.currentStreak(for: habit)
                            )
                            .environment(viewModel.dataRepository)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    } header: {
                        Text(viewModel.isToday ? "" : viewModel.fullDateString)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(viewModel.dateDisplayString)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 4) {
                        Button(action: { viewModel.goToPreviousDay() }) {
                            Image(systemName: "chevron.left")
                        }
                        if !viewModel.isToday {
                            Button(action: { viewModel.goToNextDay() }) {
                                Image(systemName: "chevron.right")
                            }
                        }
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
            .sheet(isPresented: $viewModel.showingAddHabitSheet, onDismiss: {
                viewModel.loadHabits()
            }) {
                AddHabitView()
            }
            .sheet(item: $viewModel.selectedHabit, onDismiss: {
                viewModel.loadHabits()
            }) { habit in
                EditHabitView(habit: habit)
            }
            .onAppear {
                viewModel.loadHabits()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    let today = Calendar.current.startOfDay(for: Date())
                    if viewModel.selectedDate != today {
                        viewModel.goToToday()
                    }
                    viewModel.dataRepository.clearCache()
                    viewModel.loadHabits()
                }
            }
        }
    }

    // MARK: - Progress Row

    private var progressRow: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 8)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: viewModel.completionProgress)
                    .stroke(
                        viewModel.completionProgress >= 1.0
                            ? Color.green
                            : Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.completionProgress)

                Text("\(viewModel.completedCount)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                    .animation(.default, value: viewModel.completedCount)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("\(viewModel.completedCount)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                    Text(" of \(viewModel.totalCount) complete")
                        .font(.headline)
                }
                .animation(.default, value: viewModel.completedCount)

                Text(viewModel.progressMessage)
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
            if viewModel.habits.isEmpty {
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
