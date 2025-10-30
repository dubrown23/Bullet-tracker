//
//  DailyLogView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
@preconcurrency import CoreData
import Observation

// MARK: - View Model

/// Handles Core Data operations and state management for the daily log view
@Observable
final class DailyLogViewModel: ObservableObject {
    // MARK: - Properties
    
    var entries: [JournalEntry] = []
    var migratedFutureEntries: [JournalEntry] = []
    var selectedDate = Date()
    var showingNewEntrySheet = false
    var selectedEntry: JournalEntry? = nil
    var isLoading = false
    
    // MARK: - Cached Properties
    
    private var lastLoadedDate: Date?
    private var cachedEntriesCount: Int = 0
    private var cachedMigratedCount: Int = 0
    
    // MARK: - Computed Properties
    
    var hasEntries: Bool {
        cachedEntriesCount > 0 || cachedMigratedCount > 0
    }
    
    var totalEntriesCount: Int {
        cachedEntriesCount + cachedMigratedCount
    }
    
    // MARK: - Public Methods
    
    /// Loads journal entries for the selected date
    func loadEntries() {
        // Skip if we already loaded for this date
        if let lastDate = lastLoadedDate,
           Calendar.current.isDate(lastDate, inSameDayAs: selectedDate) {
            return
        }
        
        isLoading = true
        
        Task { @MainActor in
            await loadEntriesAsync()
        }
    }
    
    /// Force reload entries (used after modifications)
    func reloadEntries() {
        lastLoadedDate = nil
        loadEntries()
    }
    
    /// Deletes journal entries at the specified indices
    /// - Parameter offsets: The index set of entries to delete
    func deleteEntry(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            CoreDataManager.shared.deleteJournalEntry(entry)
        }
        
        // Update cache counts
        cachedEntriesCount -= offsets.count
        
        // Remove from array without reloading
        entries.remove(atOffsets: offsets)
    }
    
    /// Deletes a migrated future entry
    func deleteMigratedFutureEntry(_ entry: JournalEntry) {
        CoreDataManager.shared.deleteJournalEntry(entry)
        
        // Update cache and array
        if let index = migratedFutureEntries.firstIndex(of: entry) {
            migratedFutureEntries.remove(at: index)
            cachedMigratedCount -= 1
        }
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
            
            // Trigger view update without full reload
            if let index = entries.firstIndex(of: entry) {
                // Force SwiftUI to recognize the change
                entries[index] = entry
            }
        } catch {
            // Revert on failure
            entry.taskStatus = (entry.taskStatus == "completed") ? "pending" : "completed"
        }
    }
    
    // MARK: - Private Methods
    
    /// Asynchronously loads entries with optimized filtering
    @MainActor
    private func loadEntriesAsync() async {
        let context = CoreDataManager.shared.container.viewContext
        let selectedDate = self.selectedDate
        
        let (regular, migrated) = await context.perform { () -> ([JournalEntry], [JournalEntry]) in
            let allEntries = CoreDataManager.shared.fetchEntriesForDate(selectedDate)
            
            // Filter and separate in one pass
            var regularEntries: [JournalEntry] = []
            var migratedEntries: [JournalEntry] = []
            
            regularEntries.reserveCapacity(allEntries.count)
            
            for entry in allEntries where !entry.isSpecialEntry {
                if entry.hasMigrated && entry.scheduledDate != nil && !entry.isFutureEntry {
                    migratedEntries.append(entry)
                } else {
                    regularEntries.append(entry)
                }
            }
            
            return (regularEntries, migratedEntries)
        }
        
        // Update on main thread
        self.entries = regular
        self.migratedFutureEntries = migrated
        self.cachedEntriesCount = regular.count
        self.cachedMigratedCount = migrated.count
        self.lastLoadedDate = selectedDate
        self.isLoading = false
    }
}

// MARK: - Main View

struct DailyLogView: View {
    // MARK: - State Properties
    
    @StateObject private var viewModel = DailyLogViewModel()
    @EnvironmentObject private var migrationManager: MigrationManager
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                datePicker
                
                if viewModel.isLoading {
                    loadingView
                } else if !viewModel.hasEntries {
                    emptyStateView
                } else {
                    entriesList
                }
            }
            .navigationTitle("Daily Log")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addButton
                }
            }
            .onAppear {
                viewModel.loadEntries()
            }
            .sheet(isPresented: $viewModel.showingNewEntrySheet) {
                NewEntryView(date: viewModel.selectedDate)
                    .onDisappear {
                        viewModel.reloadEntries()
                    }
            }
            .sheet(item: $viewModel.selectedEntry) { entry in
                EditEntryView(entry: entry)
                    .onDisappear {
                        viewModel.reloadEntries()
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
    
    /// Loading indicator
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
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
    
    /// Add button with entry count badge
    private var addButton: some View {
        Button {
            viewModel.showingNewEntrySheet = true
        } label: {
            if viewModel.totalEntriesCount > 0 {
                Label("\(viewModel.totalEntriesCount)", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
            } else {
                Label("Add Entry", systemImage: "plus")
            }
        }
    }
    
    /// List view displaying journal entries
    private var entriesList: some View {
        List {
            // From Future Log section
            if !viewModel.migratedFutureEntries.isEmpty {
                Section {
                    ForEach(viewModel.migratedFutureEntries) { entry in
                        migratedEntryRow(entry)
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
                regularEntryRow(entry)
            }
            .onDelete(perform: viewModel.deleteEntry)
        }
        .listStyle(.plain)
    }
    
    // MARK: - Row Views
    
    /// Row view for migrated future entries
    private func migratedEntryRow(_ entry: JournalEntry) -> some View {
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
    
    /// Row view for regular entries
    private func regularEntryRow(_ entry: JournalEntry) -> some View {
        EntryRowView(entry: entry)
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectedEntry = entry
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if entry.entryType == "task" {
                    toggleTaskButton(for: entry)
                }
            }
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
