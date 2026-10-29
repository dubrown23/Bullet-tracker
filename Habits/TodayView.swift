//
//  TodayView.swift
//  Bullet Tracker
//
//  Daily habit checklist using native iOS patterns.
//
//  bt-0014 layout: the header is fixed and only the habit rows scroll — the
//  day summary lives in the navigation bar as a subtitle. bt-0026: the rows
//  are a Reminders-style checklist (round control, quiet history dots), in
//  two sections — the habits you do, then "Avoiding" — and the pinned
//  weekday-letter strip is gone with the week grid it labelled.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: [SortDescriptor(\Habit.order), SortDescriptor(\Habit.name)])
    private var habits: [Habit]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel = TodayViewModel()
    /// Pending delete, confirmed by the alert below. Held here (not in the
    /// row) so the alert survives the List tearing the swiped row down.
    @State private var habitToDelete: Habit?

    private var trackableHabits: [Habit] { viewModel.trackableHabits(from: habits) }

    var body: some View {
        NavigationStack {
            List {
                if trackableHabits.isEmpty {
                    Section {
                        emptyContent
                    }
                } else {
                    let positive = viewModel.positiveHabits(from: habits)
                    let avoiding = viewModel.avoidanceHabits(from: habits)

                    if !positive.isEmpty {
                        Section {
                            // One habit per row folded, two per row unfolded / iPad
                            // (see `PairedRows`, bt-0009).
                            PairedRows(items: positive) { habit in
                                row(for: habit)
                            }
                        }
                    }

                    // bt-0026 — avoidance habits in their own section: the
                    // control means the opposite thing here (tap = slipped),
                    // and the trailer counts slips only, never "clean".
                    if !avoiding.isEmpty {
                        Section {
                            PairedRows(items: avoiding) { habit in
                                row(for: habit)
                            }
                        } header: {
                            HStack {
                                Text("Avoiding")
                                Spacer()
                                if let slipped = viewModel.avoidingTrailerText(from: habits) {
                                    Text(slipped)
                                        .foregroundStyle(AppTheme.failed)
                                        .accessibilityLabel("Avoiding: \(slipped)")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            // bt-0018 — "pull down on Today to re-check": steps, facts, grades.
            // bt-0019 — forced, so it runs even right after an automatic one.
            .refreshable {
                await HabitSyncEngine.shared.refresh(in: modelContext, force: true)
            }
            .navigationTitle(viewModel.dateDisplayString)
            .navigationSubtitle(viewModel.summaryText(from: habits))
            // Large title + subtitle is the standard tab-root header; the bar is
            // told not to minimise on scroll.
            .keepNavigationBarVisible()
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
        // bt-0026 — the large title's accessibility label lagged a day behind
        // the text ("Yesterday" on screen, "Today" to VoiceOver). Rebuilding
        // the stack when the title changes gives the bar a fresh title view;
        // the view model (sheets, selected day) lives outside and survives.
        .id(viewModel.dateDisplayString)
    }

    // MARK: - Rows

    private func row(for habit: Habit) -> some View {
        TodayHabitRowView(
            habit: habit,
            date: viewModel.selectedDate,
            streak: viewModel.currentStreak(for: habit),
            onRequestDelete: { habitToDelete = habit }
        )
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
