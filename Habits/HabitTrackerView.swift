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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        contentView
            .navigationTitle("Habit Tracker")
            .navigationBarBackButtonHidden(true) // Hide default back button
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                    }
                }
                
                // Separate toolbar items to avoid constraint conflicts
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { viewModel.showingAddHabitSheet = true }) {
                        Image(systemName: "plus")
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button(action: {
                        withAnimation {
                            isEditMode = isEditMode == .active ? .inactive : .active
                        }
                    }) {
                        Group {
                            if isEditMode == .active {
                                Text("Done")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                        }
                        .foregroundColor(viewModel.habits.isEmpty ? .gray : .blue)
                        .frame(minWidth: 44, alignment: .center)
                    }
                    .disabled(viewModel.habits.isEmpty)
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
                handleScenePhaseChange(newPhase)
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
    
    private func processWidgetCommands() {
        guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.db23.Bullet-Tracker") else {
            return
        }
        
        let commandsURL = appGroupURL.appendingPathComponent("widget_commands.json")
        
        guard FileManager.default.fileExists(atPath: commandsURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: commandsURL)
            guard let commands = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return
            }
            
            let context = CoreDataManager.shared.container.viewContext
            
            for command in commands {
                guard let action = command["action"] as? String,
                      let habitIDString = command["habitID"] as? String,
                      let _ = command["habitName"] as? String,
                      let _ = command["timestamp"] as? Double else {
                    continue
                }
                
                if action == "toggle_habit" {
                    processToggleHabitCommand(habitID: habitIDString, context: context)
                }
            }
            
            // Clear the commands file
            try "[]".write(to: commandsURL, atomically: true, encoding: .utf8)
            
            // Save any changes
            if context.hasChanges {
                try context.save()
            }
            
            // Refresh the data
            performManualRefresh()
            
        } catch {
            // Silently handle widget command processing errors
        }
    }
    
    private func processToggleHabitCommand(habitID: String, context: NSManagedObjectContext) {
        guard let habitUUID = UUID(uuidString: habitID) else {
            return
        }
        
        // Find the habit
        let habitRequest: NSFetchRequest<Habit> = Habit.fetchRequest()
        habitRequest.predicate = NSPredicate(format: "id == %@", habitUUID as CVarArg)
        
        do {
            guard let habit = try context.fetch(habitRequest).first else {
                return
            }
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: today)!
            
            // Find existing entry for today
            let entryRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
            entryRequest.predicate = NSPredicate(format: "habit == %@ AND date >= %@ AND date < %@",
                                               habit,
                                               today as CVarArg,
                                               endOfDay as CVarArg)
            
            let existingEntry = try context.fetch(entryRequest).first
            
            if let entry = existingEntry {
                // Cycle through completion states or delete
                let currentState = Int(entry.completionState)
                let nextState = getNextCompletionState(current: currentState, habit: habit)
                
                if nextState == 0 {
                    // Delete the entry
                    context.delete(entry)
                } else {
                    // Update the state
                    entry.completionState = Int16(nextState)
                }
            } else {
                // Create new entry with success state
                let newEntry = HabitEntry(context: context)
                newEntry.id = UUID()
                newEntry.habit = habit
                newEntry.date = today
                newEntry.completionState = 1 // Success
                newEntry.details = nil
            }
            
        } catch {
            // Silently handle errors in background processing
        }
    }
    
    private func getNextCompletionState(current: Int, habit: Habit) -> Int {
        // For negative habits, only toggle between 0 (none) and 3 (attempted/relapse)
        if habit.isNegativeHabit {
            return current == 0 ? 3 : 0
        }
        
        // For habits without multiple states, toggle between 0 and 1
        if !habit.useMultipleStates {
            return current == 0 ? 1 : 0
        }
        
        // For habits with multiple states, cycle through: 0 -> 1 -> 2 -> 3 -> 0
        switch current {
        case 0: return 1 // None -> Success
        case 1: return 2 // Success -> Partial  
        case 2: return 3 // Partial -> Attempted
        case 3: return 0 // Attempted -> None
        default: return 1 // Fallback to Success
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
                                .environmentObject(viewModel.dataRepository)
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
