//
//  DailyLogView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

// View Model to handle Core Data operations
class DailyLogViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var selectedDate = Date()
    @Published var showingNewEntrySheet = false
    @Published var selectedEntry: JournalEntry? = nil
    
    func loadEntries() {
        entries = CoreDataManager.shared.fetchEntriesForDate(selectedDate)
    }
    
    func deleteEntry(at offsets: IndexSet) {
        for index in offsets {
            let entry = entries[index]
            CoreDataManager.shared.deleteJournalEntry(entry)
        }
        loadEntries()
    }
    
    func toggleTaskStatus(_ entry: JournalEntry) {
        // Only toggle if it's a task
        if entry.entryType == "task" {
            // Toggle between completed and pending
            if entry.taskStatus == "completed" {
                entry.taskStatus = "pending"
            } else {
                entry.taskStatus = "completed"
            }
            
            // Save the context
            let context = CoreDataManager.shared.container.viewContext
            do {
                try context.save()
                print("Task status toggled successfully")
            } catch {
                print("Error toggling task status: \(error)")
            }
            
            // Reload entries to refresh the view
            loadEntries()
        }
    }
}

struct DailyLogView: View {
    @StateObject private var viewModel = DailyLogViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker("Select Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                    .onChange(of: viewModel.selectedDate) { _ in
                        viewModel.loadEntries()
                    }
                
                if viewModel.entries.isEmpty {
                    Spacer()
                    Text("No entries for this day")
                        .font(.headline)
                    Text("Tap + to add an entry")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.entries) { entry in
                            // Use your existing EntryRowView here
                            Text(entry.content ?? "")
                                .onTapGesture {
                                    viewModel.selectedEntry = entry
                                }
                        }
                        .onDelete(perform: viewModel.deleteEntry)
                    }
                }
            }
            .navigationTitle("Daily Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showingNewEntrySheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear {
                viewModel.loadEntries()
            }
            .sheet(isPresented: $viewModel.showingNewEntrySheet, onDismiss: {
                viewModel.loadEntries()
            }) {
                NewEntryView(date: viewModel.selectedDate)
            }
            .sheet(item: $viewModel.selectedEntry) { entry in
                // Use your existing EditEntryView here
                EditEntryView(entry: entry)
            }
        }
    }
}
