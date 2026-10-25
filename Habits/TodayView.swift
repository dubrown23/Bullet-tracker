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
    /// Pending delete, confirmed by the alert below. Held here (not in the
    /// row) so the alert survives the List tearing the swiped row down.
    @State private var habitToDelete: Habit?

    /// Progress ring scales with the user's text size (Dynamic Type).
    @ScaledMetric(relativeTo: .headline) private var ringSize: CGFloat = 44

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
                                streak: viewModel.currentStreak(for: habit),
                                onRequestDelete: { habitToDelete = habit }
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
            // Editing lives on the row now (tap name / context menu / swipe) —
            // the old `selectedHabit` sheet here was never triggered (bt-0012).
            .alert(
                Text("Delete \u{201C}\(habitToDelete?.name ?? "this habit")\u{201D}?"),
                isPresented: isConfirmingDelete,
                presenting: habitToDelete
            ) { habit in
                Button("Cancel", role: .cancel) { }
                Button("Delete Habit", role: .destructive) { deleteHabit(habit) }
            } message: { _ in
                Text("All tracking data for this habit will be lost.")
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

    // MARK: - Delete

    private var isConfirmingDelete: Binding<Bool> {
        Binding(
            get: { habitToDelete != nil },
            set: { if !$0 { habitToDelete = nil } }
        )
    }

    private func deleteHabit(_ habit: Habit) {
        // Habit.entries has a .cascade delete rule, so the entries go with it.
        modelContext.delete(habit)
        do { try modelContext.save() } catch {
            debugLog("TodayView: delete failed — \(error.localizedDescription)")
        }
        habitToDelete = nil
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
            // Slimmer ring (bt-0012): the count lives in the text beside it.
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 6)
                    .frame(width: ringSize, height: ringSize)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        progress >= 1.0 ? AppTheme.success : Color.accentColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
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
        .padding(.vertical, 2)
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
