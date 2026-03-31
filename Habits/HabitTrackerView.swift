//
//  HabitTrackerView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct HabitTrackerView: View {
    @StateObject private var viewModel = HabitTrackerViewModel()
    @State private var isEditMode: EditMode = .inactive
    @State private var lastDateCheck = Date()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Habits")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: AppTheme.Spacing.lg) {
                        // Reorder button
                        if !viewModel.habits.isEmpty {
                            Button(action: {
                                withAnimation {
                                    isEditMode = isEditMode == .active ? .inactive : .active
                                }
                            }) {
                                if isEditMode == .active {
                                    Text("Done")
                                        .font(AppTheme.Font.callout)
                                        .foregroundColor(AppTheme.accent)
                                } else {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .foregroundColor(AppTheme.accent)
                                }
                            }
                            .accessibilityLabel(isEditMode == .active ? "Done reordering" : "Reorder habits")
                        }

                        // Add habit button
                        Button(action: { viewModel.showingAddHabitSheet = true }) {
                            Image(systemName: "plus")
                                .foregroundColor(AppTheme.accent)
                        }
                        .accessibilityLabel("Add new habit")
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
                viewModel.loadHabitEntries()
            }) { habit in
                EditHabitView(habit: habit)
            }
            .alert("Delete Habit", isPresented: $viewModel.showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    viewModel.habitToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let habit = viewModel.habitToDelete {
                        CoreDataManager.shared.deleteHabit(habit)
                        viewModel.habitToDelete = nil
                        viewModel.loadHabits()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this habit? All tracking data will be lost.")
            }
            .onAppear {
                viewModel.loadHabits()
                viewModel.updateVisibleDates() // This already calls loadHabitEntries()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
        }
    }
    
    // Main content view
    private var contentView: some View {
        VStack(spacing: 0) {
            monthSelectorView

            if isEditMode == .active && !viewModel.habits.isEmpty {
                reorderInstructionView
            }

            if viewModel.habits.isEmpty {
                emptyStateView
            } else {
                habitsView
            }
        }
    }
    
    // Month selector component
    private var monthSelectorView: some View {
        HStack(spacing: 4) {
            // Previous month button
            Button(action: {
                if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: viewModel.selectedDate) {
                    viewModel.selectedDate = newDate
                    viewModel.updateVisibleDates() // Already calls loadHabitEntries()
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 36, height: 36)
            }

            // Current month/year display
            Text(monthYearString(from: viewModel.selectedDate))
                .font(AppTheme.Font.headline)
                .frame(minWidth: 140)

            // Next month button
            Button(action: {
                if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: viewModel.selectedDate) {
                    if newDate <= Date() {
                        viewModel.selectedDate = min(newDate, Date())
                        viewModel.updateVisibleDates() // Already calls loadHabitEntries()
                    }
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isCurrentMonth ? .gray.opacity(0.5) : AppTheme.accent)
                    .frame(width: 36, height: 36)
            }
            .disabled(isCurrentMonth)

            Spacer()

            // Today button - jump to current date
            if !isCurrentMonth {
                Button(action: {
                    viewModel.selectedDate = Date()
                    viewModel.updateVisibleDates() // Already calls loadHabitEntries()
                }) {
                    Text("Today")
                        .font(AppTheme.Font.callout)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.accent)
                        .cornerRadius(14)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.cardBackground.opacity(0.5))
    }

    // Helper to check if selected date is in current month
    private var isCurrentMonth: Bool {
        Calendar.current.isDate(viewModel.selectedDate, equalTo: Date(), toGranularity: .month)
    }

    // Format month and year
    private func monthYearString(from date: Date) -> String {
        DateFormatters.monthYear.string(from: date)
    }
    
    // Reorder instruction banner
    private var reorderInstructionView: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundColor(AppTheme.accent)
            Text("Drag habits to reorder them")
                .font(AppTheme.Font.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle")
                    .font(.system(size: 50))
                    .foregroundColor(AppTheme.accent)
            }

            Text("No Habits Yet")
                .font(AppTheme.Font.title)

            Text("Add your first habit to start tracking your daily progress")
                .font(AppTheme.Font.body)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 32)

            Button(action: {
                viewModel.showingAddHabitSheet = true
            }) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Habit")
                }
                .font(AppTheme.Font.headline)
                .padding(.horizontal, AppTheme.Spacing.xxl)
                .padding(.vertical, AppTheme.Spacing.md)
                .background(AppTheme.accent)
                .foregroundColor(.white)
                .cornerRadius(AppTheme.Radius.medium)
            }
            .padding(.top, AppTheme.Spacing.sm)

            Spacer()
        }
        .padding()
    }
    
    // Main habits view with habit headers and date rows
    private var habitsView: some View {
        VStack(spacing: 0) {
            if isEditMode == .inactive {
                // Synchronized scrolling layout
                synchronizedHabitGrid
            } else {
                // Edit mode - show habits list for reordering
                habitsEditList
            }
        }
    }

    // Main habit tracking grid
    private var synchronizedHabitGrid: some View {
        VStack(spacing: 0) {
            // Grid with dates vertical, habits horizontal
            HabitGridView(
                habits: viewModel.habits,
                dates: viewModel.visibleDates,
                dataRepository: viewModel.dataRepository,
                onHabitTap: { habit in
                    viewModel.selectedHabit = habit
                },
                onHabitLongPress: { habit in
                    viewModel.habitToDelete = habit
                    viewModel.showingDeleteAlert = true
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // Habits list for edit/reorder mode
    private var habitsEditList: some View {
        List {
            Section {
                ForEach(viewModel.habits) { habit in
                    HabitRowReorderView(habit: habit)
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                        .listRowBackground(Color.clear)
                }
                .onMove(perform: viewModel.reorderHabits)
            }
        }
        .listStyle(PlainListStyle())
        .environment(\.editMode, $isEditMode)
    }
    
    // MARK: - Helper Methods
    
    private func performManualRefresh() {
        // Clear cache and reload habits to ensure fresh data
        viewModel.dataRepository.clearCache()
        viewModel.loadHabits()
        viewModel.updateVisibleDates()
        viewModel.loadHabitEntries()
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        
        if newPhase == .active {
            // Check if we're on a new day when app becomes active
            let calendar = Calendar.current
            if !calendar.isDate(lastDateCheck, inSameDayAs: Date()) {
                viewModel.selectedDate = Date()
                // Clear cache before updating dates to force fresh data load
                viewModel.dataRepository.clearCache()
                viewModel.updateVisibleDates()
                viewModel.loadHabitEntries()
                lastDateCheck = Date()
            } else {
                // Clear cache and refresh to pick up widget changes
                viewModel.dataRepository.clearCache()
                viewModel.loadHabitEntries()
            }
        }
    }
    
}

// DateFormatters are now in Utilities/HabitCalculations.swift

// Simplified habit row specifically for reordering mode
struct HabitRowReorderView: View {
    @ObservedObject var habit: Habit

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: habit.color ?? "#FF8C42").opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: habit.icon ?? "circle")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: habit.color ?? "#FF8C42"))
            }

            Text(habit.name ?? "")
                .font(AppTheme.Font.headline)

            Spacer()
        }
        .padding(.vertical, AppTheme.Spacing.sm)
        .contentShape(Rectangle())
    }
}
