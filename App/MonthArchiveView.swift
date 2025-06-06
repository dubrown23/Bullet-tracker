//
//  MonthArchiveView.swift
//  Bullet Tracker
//
//  Created on 6/5/2025.
//

import SwiftUI
import CoreData

struct MonthArchiveView: View {
    // MARK: - Properties
    
    let monthCollection: Collection
    let year: String
    let month: String
    
    // MARK: - State Properties
    
    @State private var entries: [JournalEntry] = []
    @State private var specialEntries: [JournalEntry] = []
    @State private var regularEntries: [JournalEntry] = []
    @State private var selectedEntry: JournalEntry?
    @State private var groupedEntries: [Date: [JournalEntry]] = [:]
    
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if entries.isEmpty {
                emptyStateView
            } else {
                entryList
            }
        }
        .navigationTitle("\(month) \(year)")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadEntries()
        }
        .sheet(item: $selectedEntry) { entry in
            if entry.isSpecialEntry {
                SpecialEntryDetailView(entry: entry)
            } else {
                EditEntryView(entry: entry)
            }
        }
        .onChange(of: selectedEntry) { _, _ in
            loadEntries()
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No entries archived yet")
                .font(.headline)
            
            Text("Entries will be archived here at the end of \(month)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var entryList: some View {
        List {
            // Special Entries Section (Reviews & Outlooks) at the top
            if !specialEntries.isEmpty {
                Section {
                    ForEach(specialEntries) { entry in
                        EntryRowView(entry: entry)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(entry.specialEntryType == "review"
                                          ? Color.purple.opacity(0.05)
                                          : Color.green.opacity(0.05))
                            )
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                } header: {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.orange)
                        Text("Monthly Reflections")
                            .font(.headline)
                    }
                }
            }
            
            // Summary Header
            Section {
                monthSummaryHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            // Regular Entries by Date
            ForEach(sortedDates(), id: \.self) { date in
                Section {
                    if let dayEntries = groupedEntries[date] {
                        ForEach(dayEntries) { entry in
                            EntryRowView(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                        }
                    }
                } header: {
                    Text(date, format: .dateTime.weekday(.wide).month().day())
                        .font(.headline)
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - View Summary Components
    
    @ViewBuilder
    private var monthSummaryHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Summary")
                        .font(.title3.bold())
                    Text("\(regularEntries.count) entries archived")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Entry type breakdown (excluding special entries)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Image(systemName: "circle")
                            .font(.caption)
                        Text("\(taskCount) tasks")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("\(eventCount) events")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: "note.text")
                            .font(.caption)
                        Text("\(noteCount) notes")
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }
            
            // Special entries indicator
            if !specialEntries.isEmpty {
                HStack(spacing: 12) {
                    ForEach(specialEntries) { entry in
                        HStack(spacing: 4) {
                            Text(entry.specialEntryType == "review" ? "📝" : "📅")
                                .font(.caption)
                            Text(entry.specialEntryType == "review" ? "Review" : "Outlook")
                                .font(.caption)
                                .foregroundStyle(entry.isDraft ? .orange : .primary)
                            if entry.isDraft {
                                Text("(Draft)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(entry.specialEntryType == "review"
                                      ? Color.purple.opacity(0.1)
                                      : Color.green.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Computed Properties
    
    private var taskCount: Int {
        regularEntries.filter { $0.entryType == EntryType.task.rawValue }.count
    }
    
    private var eventCount: Int {
        regularEntries.filter { $0.entryType == EntryType.event.rawValue }.count
    }
    
    private var noteCount: Int {
        regularEntries.filter {
            $0.entryType == EntryType.note.rawValue && !$0.isSpecialEntry
        }.count
    }
    
    // MARK: - Helper Methods
    
    private func loadEntries() {
        guard let monthEntries = monthCollection.entries as? Set<JournalEntry> else {
            entries = []
            specialEntries = []
            regularEntries = []
            return
        }
        
        entries = Array(monthEntries).sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
        
        // Separate special entries from regular entries
        specialEntries = entries.filter { $0.isSpecialEntry }
            .sorted { entry1, entry2 in
                // Reviews before outlooks
                if entry1.specialEntryType != entry2.specialEntryType {
                    return entry1.specialEntryType == "review"
                }
                // Then by date
                return (entry1.date ?? Date()) < (entry2.date ?? Date())
            }
        
        regularEntries = entries.filter { !$0.isSpecialEntry }
        
        // Group regular entries by date
        groupedEntries = Dictionary(grouping: regularEntries) { entry in
            Calendar.current.startOfDay(for: entry.date ?? Date())
        }
    }
    
    private func sortedDates() -> [Date] {
        groupedEntries.keys.sorted()
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MonthArchiveView(
            monthCollection: {
                let collection = Collection(context: CoreDataManager.shared.container.viewContext)
                collection.name = "2025/June"
                collection.isAutomatic = true
                return collection
            }(),
            year: "2025",
            month: "June"
        )
    }
}
