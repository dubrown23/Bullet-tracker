//
//  TodayView.swift
//  Bullet Tracker
//
//  Daily habit checklist using native iOS patterns.
//
//  bt-0014 layout: the header is fixed and only the habit rows scroll —
//  the day summary lives in the navigation bar as a subtitle, the weekday
//  letters are a `safeAreaBar` pinned under it, and the List holds habits only.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: [SortDescriptor(\Habit.order), SortDescriptor(\Habit.name)])
    private var habits: [Habit]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.calendar) private var calendar

    @State private var viewModel = TodayViewModel()
    /// Pending delete, confirmed by the alert below. Held here (not in the
    /// row) so the alert survives the List tearing the swiped row down.
    @State private var habitToDelete: Habit?

    /// Same base as the row's cells so the day letters line up with the squares.
    @ScaledMetric(relativeTo: .body) private var weekCellBase: CGFloat = 24

    /// The List's safe-area insets, read from its background. The inset-grouped
    /// card margin is `max(20, safeAreaInset)` per side, so where a side already
    /// has a safe-area inset (the Duo's toolbar rail) the card margin is 0 and
    /// the pinned letters must use the same rule to line up with the squares.
    @State private var listSafeAreaInsets = EdgeInsets()

    /// Card margin + the default inset-grouped row inset (20 on iOS).
    private var headerLeadingPadding: CGFloat { max(20 - listSafeAreaInsets.leading, 0) + 20 }
    private var headerTrailingPadding: CGFloat { max(20 - listSafeAreaInsets.trailing, 0) + 20 }

    private var trackableHabits: [Habit] { viewModel.trackableHabits(from: habits) }

    var body: some View {
        NavigationStack {
            List {
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
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { listSafeAreaInsets = geo.safeAreaInsets }
                        .onChange(of: geo.safeAreaInsets) { _, new in listSafeAreaInsets = new }
                }
            }
            // Weekday letters pinned under the navigation bar; the list scrolls
            // beneath them with the system scroll-edge treatment.
            // Weekday letters: a thin pinned strip right over the squares, like
            // a table's column header. Just the letters — the summary is the
            // navigation subtitle, where Apple puts that line.
            .safeAreaBar(edge: .top) {
                if !trackableHabits.isEmpty && !dynamicTypeSize.isAccessibilitySize {
                    weekdayHeader
                        .padding(.leading, headerLeadingPadding)
                        .padding(.trailing, headerTrailingPadding)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Pull the first card up under the letters (the grouped list's
            // default top gap is sized for a section header we don't have).
            .contentMargins(.top, 6, for: .scrollContent)
            .navigationTitle(viewModel.dateDisplayString)
            .navigationSubtitle(viewModel.summaryText(from: habits))
            // Large title + subtitle is the standard tab-root header; the bar is
            // told not to minimise on scroll (it used to vanish instead of
            // collapsing to inline when a safeAreaBar sat under it).
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
    }

    // MARK: - Weekday header

    private var weekMetrics: WeekGridMetrics {
        WeekGridMetrics(scaledBase: weekCellBase, isRegularWidth: horizontalSizeClass == .regular)
    }

    /// Shared letters component over the visible window (same rule as the rows).
    private var weekdayLetterStrip: some View {
        WeekdayLetterStrip(
            days: WeekGridMetrics.windowDays(for: viewModel.selectedDate, calendar: calendar),
            slotWidth: weekMetrics.slotWidth
        )
    }

    /// Mirrors `PairedRows` geometry in regular width (two columns, 16pt gap,
    /// divider) so each column's letters line up with its own grid.
    @ViewBuilder
    private var weekdayHeader: some View {
        if horizontalSizeClass == .regular {
            HStack(spacing: 16) {
                weekdayLetterStrip
                    .frame(maxWidth: .infinity, alignment: .trailing)
                // Stand-in for PairedRows' Divider (same ~hairline width). A
                // real Divider here proposes infinite height and the pinned
                // bar would fill the screen.
                Color.clear.frame(width: 1 / 3, height: 1)
                weekdayLetterStrip
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            weekdayLetterStrip
                .frame(maxWidth: .infinity, alignment: .trailing)
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
