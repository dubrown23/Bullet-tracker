//
//  HabitTrackerView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


//
//  HabitTrackerView.swift
//  Bullet Tracker
//
//  Updated by Dustin Brown on 5/12/25.
//

import SwiftUI

struct HabitTrackerView: View {
    @StateObject private var viewModel = HabitTrackerViewModel()
    
    var body: some View {
        VStack {
            // Date selector for the end date of the range
            DatePicker("End Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
                .padding(.horizontal)
                .onChange(of: viewModel.selectedDate) { _ in
                    viewModel.updateVisibleDates()
                    viewModel.loadHabitEntries()
                }
            
            if viewModel.habits.isEmpty {
                // Empty state
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
            } else {
                // Habit Tracker Grid
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Date headers
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
                                        VStack {
                                            Text(formatDate(date))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text(formatDayOfWeek(date))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(width: 44)
                                    }
                                }
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.bottom, 8)
                        
                        // Habit rows with checkboxes
                        ForEach(viewModel.habits) { habit in
                            HabitRowWithEdit(habit: habit, dates: viewModel.visibleDates, viewModel: viewModel)
                        }
                        
                        // Stats section
                        if !viewModel.habits.isEmpty {
                            HabitStatsView(habits: viewModel.habits)
                                .padding(.top, 20)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Habit Tracker")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.showingAddHabitSheet = true
                }) {
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
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let habit = viewModel.selectedHabit {
                    CoreDataManager.shared.deleteHabit(habit)
                    viewModel.selectedHabit = nil
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
    }
    
    // Helper functions for formatting dates
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    private func formatDayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
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
                    // Habit name and icon with edit button
                    HStack(spacing: 4) {
                        HabitRowLabelView(habit: habit)
                            .frame(width: 100, alignment: .leading)
                        
                        Button(action: {
                            viewModel.selectedHabit = habit
                        }) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .frame(width: 120)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedHabit = habit
                    }
                    
                    // Checkboxes for each date
                    HStack(spacing: 12) {
                        ForEach(dates, id: \.self) { date in
                            HabitCheckboxView(habit: habit, date: date)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.leading, 8)
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .contextMenu {
            Button(action: {
                viewModel.selectedHabit = habit
            }) {
                Label("Edit", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: {
                viewModel.selectedHabit = habit
                viewModel.showingDeleteAlert = true
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
