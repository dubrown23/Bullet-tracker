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
        
        // Filter out special entries and separate migrated future entries in one pass
        var regularEntries: [JournalEntry] = []
        var migratedEntries: [JournalEntry] = []
        
        for entry in allEntries where !entry.isSpecialEntry {
            if entry.hasMigrated && entry.scheduledDate != nil && !entry.isFutureEntry {
                migratedEntries.append(entry)
            } else {
                regularEntries.append(entry)
            }
        }
        
        entries = regularEntries
        migratedFutureEntries = migratedEntries
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
        } catch {
            // Silent failure - view will show previous state
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showingNewEntrySheet = true
                    } label: {
                        Label("Add Entry", systemImage: "plus")
                    }
                }
            }
            .onAppear {
                viewModel.loadEntries()
            }
            .sheet(isPresented: $viewModel.showingNewEntrySheet) {
                NewEntryView(date: viewModel.selectedDate)
                    .onDisappear {
                        viewModel.loadEntries()
                    }
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
}

// MARK: - Preview

#Preview {
    DailyLogView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
        .environmentObject(MigrationManager.shared)
}
