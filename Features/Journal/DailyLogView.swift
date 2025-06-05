//
//  DailyLogView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import Observation

// MARK: - View Model

/// Handles Core Data operations and state management for the daily log view
@Observable
final class DailyLogViewModel {
    // MARK: - Properties
    
    var entries: [JournalEntry] = []
    var migratedFutureEntries: [JournalEntry] = []
    var selectedDate = Date()
    var showingNewEntrySheet = false
    var selectedEntry: JournalEntry? = nil
    
    // MARK: - Public Methods
    
    /// Loads journal entries for the selected date
    func loadEntries() {
        let allEntries = CoreDataManager.shared.fetchEntriesForDate(selectedDate)
        
        // Filter out special entries (reviews/outlooks) - they shouldn't appear in daily log
        let nonSpecialEntries = allEntries.filter { !$0.isSpecialEntry }
        
        // Separate entries that came from Future Log (they have scheduledDate but are no longer future entries)
        migratedFutureEntries = nonSpecialEntries.filter { entry in
            // An entry is from Future Log if it was migrated and has a scheduled date
            // but is no longer marked as a future entry
            return entry.hasMigrated &&
                   entry.scheduledDate != nil &&
                   entry.isFutureEntry == false
        }
        
        // All other entries go in the main list
        entries = nonSpecialEntries.filter { entry in
            // Include if it's NOT in the migrated future entries list
            return !migratedFutureEntries.contains(where: { $0.id == entry.id })
        }
    }
    
    /// Deletes journal entries at the specified indices
    /// - Parameter offsets: The index set of entries to delete
    func deleteEntry(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            CoreDataManager.shared.deleteJournalEntry(entry)
        }
        loadEntries()
    }
    
    /// Deletes a migrated future entry
    func deleteMigratedFutureEntry(_ entry: JournalEntry) {
        CoreDataManager.shared.deleteJournalEntry(entry)
        loadEntries()
    }
    
    /// Toggles the completion status of a task entry
    /// - Parameter entry: The journal entry to toggle (must be a task type)
    func toggleTaskStatus(_ entry: JournalEntry) {
        // Only toggle if it's a task
        guard entry.entryType == "task" else { return }
        
        // Toggle between completed and pending
        entry.taskStatus = (entry.taskStatus == "completed") ? "pending" : "completed"
        
        // Save the context
        let context = CoreDataManager.shared.container.viewContext
        do {
            try context.save()
            #if DEBUG
            print("Task status toggled successfully")
            #endif
        } catch {
            #if DEBUG
            print("Error toggling task status: \(error)")
            #endif
        }
        
        // Reload entries to refresh the view
        loadEntries()
    }
}

// MARK: - Main View

struct DailyLogView: View {
    // MARK: - State Properties
    
    @State private var viewModel = DailyLogViewModel()
    @EnvironmentObject private var migrationManager: MigrationManager
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                datePicker
                
                if viewModel.entries.isEmpty && viewModel.migratedFutureEntries.isEmpty {
                    emptyStateView
                } else {
                    entriesList
                }
            }
            .navigationTitle("Daily Log")
            .toolbar {
                toolbarContent
            }
            .onAppear {
                viewModel.loadEntries()
            }
            .sheet(isPresented: $viewModel.showingNewEntrySheet) {
                viewModel.loadEntries()
            } content: {
                NewEntryView(date: viewModel.selectedDate)
            }
            .sheet(item: $viewModel.selectedEntry) { entry in
                EditEntryView(entry: entry)
                    .onDisappear {
                        viewModel.loadEntries()
                    }
            }
        }
    }
    
    // MARK: - View Components
    
    /// Date picker for selecting the day to view
    private var datePicker: some View {
        DatePicker("Select Date", selection: $viewModel.selectedDate, displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding()
            .onChange(of: viewModel.selectedDate) { _, _ in
                viewModel.loadEntries()
            }
    }
    
    /// Empty state view shown when no entries exist for the selected date
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()
            
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
            
            Text("No entries for this day")
                .font(.headline)
            
            Text("Tap + to add an entry")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            
            Spacer()
        }
    }
    
    /// List view displaying journal entries
    private var entriesList: some View {
        List {
            // From Future Log section
            if !viewModel.migratedFutureEntries.isEmpty {
                Section {
                    ForEach(viewModel.migratedFutureEntries) { entry in
                        EntryRowView(entry: entry)
                            .listRowBackground(Color.blue.opacity(0.05))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedEntry = entry
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    viewModel.deleteMigratedFutureEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                } header: {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                        Text("From Future Log")
                            .font(.headline)
                    }
                    .foregroundStyle(.blue)
                }
            }
            
            // Regular entries section
            ForEach(viewModel.entries) { entry in
                EntryRowView(entry: entry)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedEntry = entry
                    }
                    .swipeActions(edge: .leading) {
                        if entry.entryType == "task" {
                            toggleTaskButton(for: entry)
                        }
                    }
            }
            .onDelete(perform: viewModel.deleteEntry)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Toolbar Components
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.showingNewEntrySheet = true
            } label: {
                Label("Add Entry", systemImage: "plus")
            }
        }
        
        #if DEBUG
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button("Reset Daily Migration") {
                    migrationManager.resetMigrationDateForTesting()
                    // Force migration to run again
                    migrationManager.performDailyMigration()
                    // Reload entries
                    viewModel.loadEntries()
                }
                
                Button("Force Month Migration") {
                    // Create some test entries for last month if needed
                    createTestEntriesForLastMonth()
                    // Force month-end migration
                    migrationManager.performMonthEndMigration()
                }
            } label: {
                Image(systemName: "ladybug")
                    .foregroundStyle(.orange)
            }
        }
        #endif
    }
    
    // MARK: - Helper Views
    
    /// Swipe action button for toggling task status
    /// - Parameter entry: The journal entry to create the button for
    private func toggleTaskButton(for entry: JournalEntry) -> some View {
        Button {
            viewModel.toggleTaskStatus(entry)
        } label: {
            Label(
                entry.taskStatus == "completed" ? "Mark Incomplete" : "Mark Complete",
                systemImage: entry.taskStatus == "completed" ? "circle" : "checkmark.circle"
            )
        }
        .tint(entry.taskStatus == "completed" ? .orange : .green)
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    private func createTestEntriesForLastMonth() {
        let calendar = Calendar.current
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else { return }
        
        // Create a few test entries
        _ = CoreDataManager.shared.createJournalEntry(
            content: "Test task from last month",
            entryType: "task",
            taskStatus: "completed",
            date: lastMonth,
            priority: false
        )
        
        _ = CoreDataManager.shared.createJournalEntry(
            content: "Test event from last month",
            entryType: "event",
            taskStatus: nil,
            date: lastMonth,
            priority: false
        )
        
        _ = CoreDataManager.shared.createJournalEntry(
            content: "Test note from last month",
            entryType: "note",
            taskStatus: nil,
            date: lastMonth,
            priority: false
        )
        
        print("📝 Created test entries for \(lastMonth.formatted(date: .abbreviated, time: .omitted))")
    }
    #endif
}

// MARK: - Preview

#Preview {
    DailyLogView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
        .environmentObject(MigrationManager.shared)
}
