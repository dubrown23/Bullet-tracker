//
//  HabitTrackerView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct HabitTrackerView: View {
    @StateObject private var viewModel = HabitTrackerViewModel()
    @State private var isEditMode: EditMode = .inactive
    @State private var lastDateCheck = Date()
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        contentView
            .navigationTitle("Habit Tracker")
            .navigationBarBackButtonHidden(true) // Hide default back button
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !viewModel.habits.isEmpty {
                        Button(action: {
                            withAnimation {
                                isEditMode = isEditMode == .active ? .inactive : .active
                            }
                        }) {
                            if isEditMode == .active {
                                Text("Done")
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "arrow.up.arrow.down")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Button(action: { viewModel.showingAddHabitSheet = true }) {
                        Image(systemName: "plus")
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
                viewModel.updateVisibleDates()
                viewModel.loadHabits()
                viewModel.loadHabitEntries()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Check if we're on a new day when app becomes active
                    let calendar = Calendar.current
                    if !calendar.isDate(lastDateCheck, inSameDayAs: Date()) {
                        viewModel.selectedDate = Date()
                        viewModel.updateVisibleDates()
                        viewModel.loadHabitEntries()
                        lastDateCheck = Date()
                    }
                }
            }
    }
    
    // Main content view
    private var contentView: some View {
        VStack(spacing: 0) {
            datePickerView
            
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
    
    // Date picker component
    private var datePickerView: some View {
        DatePicker("Date Range", selection: $viewModel.selectedDate, displayedComponents: .date)
            .datePickerStyle(CompactDatePickerStyle())
            .padding(.horizontal)
            .onChange(of: viewModel.selectedDate) { _, _ in
                viewModel.updateVisibleDates()
                viewModel.loadHabitEntries()
            }
    }
    
    // Reorder instruction banner
    private var reorderInstructionView: some View {
        HStack {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundColor(.blue)
            Text("Drag habits to reorder them")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "chart.bar")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("No Habits Yet")
                .font(.title2)
            
            Text("Add your first habit to start tracking your daily progress")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: {
                viewModel.showingAddHabitSheet = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Habit")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
    }
    
    // Main habits view with date headers and habit list
    private var habitsView: some View {
        VStack(spacing: 0) {
            // Date headers - don't show in edit mode
            if isEditMode == .inactive {
                dateHeadersView
            }
            
            // Habits list
            habitsList
        }
    }
    
    // Date headers section
    private var dateHeadersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top) {
                // Column for habit names
                VStack(alignment: .leading) {
                    Text("Habits")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 120, height: 40, alignment: .leading)
                        .padding(.leading, 8)
                }
                .frame(width: 120)
                
                // Date columns
                HStack(spacing: 12) {
                    ForEach(viewModel.visibleDates, id: \.self) { date in
                        dateColumn(for: date)
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // Extract date column for reusability
    @ViewBuilder
    private func dateColumn(for date: Date) -> some View {
        VStack {
            Text(DateFormatters.dateFormatter.string(from: date))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(DateFormatters.dayFormatter.string(from: date))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 44)
    }
    
    // Habits list with reordering support
    private var habitsList: some View {
        List {
            // Habits section
            Section {
                ForEach(viewModel.habits) { habit in
                    habitRow(for: habit)
                }
                .onMove(perform: viewModel.reorderHabits)
            }
            
            // Stats section when not in edit mode
            if isEditMode == .inactive {
                Section {
                    HabitStatsView(habits: viewModel.habits)
                }
            }
        }
        .listStyle(PlainListStyle())
        .environment(\.editMode, $isEditMode)
    }
    
    // Individual habit row based on edit mode
    private func habitRow(for habit: Habit) -> some View {
        Group {
            if isEditMode == .active {
                // Simplified view during reordering
                HabitRowReorderView(habit: habit)
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .listRowBackground(Color.clear)
            } else {
                // Normal view
                HabitRowWithEdit(habit: habit, dates: viewModel.visibleDates, viewModel: viewModel)
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .listRowBackground(Color.clear)
            }
        }
    }
}

// Date formatters as static instances for performance
private struct DateFormatters {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
    
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

// Helper view for displaying a single habit row with edit button and checkboxes
struct HabitRowWithEdit: View {
    @ObservedObject var habit: Habit
    let dates: [Date]
    let viewModel: HabitTrackerViewModel
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center) {
                    // Habit name and icon - removed pencil button for cleaner UI
                    HabitRowLabelView(habit: habit)
                        .frame(width: 120, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectedHabit = habit
                        }
                        // Move context menu to just the habit label area, not the whole row
                        .contextMenu {
                            Button(action: {
                                viewModel.selectedHabit = habit
                            }) {
                                Label("Edit Habit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                // Fixed: Use habitToDelete instead of selectedHabit
                                viewModel.habitToDelete = habit
                                viewModel.showingDeleteAlert = true
                            }) {
                                Label("Delete Habit", systemImage: "trash")
                            }
                        }
                    
                    // Checkboxes for each date - these have their own interaction
                    HStack(spacing: 12) {
                        ForEach(dates, id: \.self) { date in
                            HabitCheckboxView(habit: habit, date: date)
                                .highPriorityGesture(
                                    LongPressGesture(minimumDuration: 0.5)
                                        .onEnded { _ in
                                            // This will be handled in HabitCheckboxView
                                        }
                                )
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.leading, 8)
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        // Removed the context menu from the entire row
    }
}

// Simplified habit row specifically for reordering mode
struct HabitRowReorderView: View {
    @ObservedObject var habit: Habit
    
    var body: some View {
        HStack {
            Image(systemName: habit.icon ?? "circle")
                .foregroundColor(Color(hex: habit.color ?? "#007AFF"))
                .frame(width: 30)
            
            Text(habit.name ?? "")
                .font(.headline)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
