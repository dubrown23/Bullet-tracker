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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var viewModel = TodayViewModel()

    /// Progress ring scales with the user's text size (Dynamic Type).
    @ScaledMetric(relativeTo: .title2) private var ringSize: CGFloat = 64

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
                        // One habit per row folded, two per row unfolded / iPad
                        // (see `PairedRows`, bt-0009).
                        PairedRows(items: trackableHabits) { habit in
                            TodayHabitRowView(
                                habit: habit,
                                date: viewModel.selectedDate,
                                streak: viewModel.currentStreak(for: habit)
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(viewModel.dateDisplayString)
            // System toolbar groups (HIG → Toolbars). Each button is a titled
            // `Button(_:systemImage:)`, so the bar shows the symbol and VoiceOver
            // reads the title; the system handles sizing, spacing, glass and the
            // disabled look — no hand-built HStacks, 44pt frames or opacity.
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Previous day", systemImage: "chevron.left") {
                        viewModel.goToPreviousDay()
                    }
                    Button("Next day", systemImage: "chevron.right") {
                        viewModel.goToNextDay()
                    }
                    .disabled(viewModel.isToday)
                }

                if !viewModel.isToday {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") { viewModel.goToToday() }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Add Habit", systemImage: "plus") {
                        viewModel.showingAddHabitSheet = true
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

        // Ring beside the text normally; stacked at accessibility text sizes
        // so neither gets squeezed (Dynamic Type layout adaptation).
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))

        return layout {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 8)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress >= 1.0 ? Color.green : Color.accentColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

                Text("\(completedCount)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                    .animation(.default, value: completedCount)
            }
            .accessibilityHidden(true) // the text beside it says the same thing

            VStack(alignment: .leading, spacing: 4) {
                // One Text (concatenated) so it wraps as a sentence at large
                // sizes instead of the number drifting away from its words.
                (Text("\(completedCount)").fontDesign(.rounded).bold()
                 + Text(" of \(totalCount) complete"))
                    .font(.headline)
                    .contentTransition(.numericText())
                    .animation(.default, value: completedCount)

                Text(viewModel.progressMessage(from: habits))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
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
