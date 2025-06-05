//
//  MonthLogView.swift
//  Bullet Tracker
//
//  Created on June 4, 2025
//

import SwiftUI
import CoreData

struct MonthLogView: View {
    // MARK: - Properties
    
    let year: Int
    let month: Int
    var onNavigatePrevious: (() -> Void)?
    var onNavigateNext: (() -> Void)?
    
    // MARK: - State Properties
    
    @State private var journalEntries: [JournalEntry] = []
    @State private var futureEntries: [JournalEntry] = []
    @State private var showingNewEntry = false
    @State private var selectedEntry: JournalEntry?
    
    // MARK: - Computed Properties
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        let components = DateComponents(year: year, month: month)
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
    
    private var monthYearTitle: String {
        "\(monthName) \(year)"
    }
    
    private var previousMonth: (year: Int, month: Int) {
        if month == 1 {
            return (year - 1, 12)
        } else {
            return (year, month - 1)
        }
    }
    
    private var nextMonth: (year: Int, month: Int) {
        if month == 12 {
            return (year + 1, 1)
        } else {
            return (year, month + 1)
        }
    }
    
    private var firstDayOfMonth: Date {
        let components = DateComponents(year: year, month: month, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }
    
    // Group entries by day
    private var entriesByDay: [(date: Date, entries: [JournalEntry])] {
        let grouped = Dictionary(grouping: journalEntries) { entry in
            Calendar.current.startOfDay(for: entry.date ?? Date())
        }
        
        return grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, entries: $0.value.sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }) }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if journalEntries.isEmpty && futureEntries.isEmpty {
                emptyStateView
            } else {
                entriesList
            }
        }
        .navigationTitle("")  // Clear the default title
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            toolbarContent
        }
        .onAppear {
            loadEntries()
        }
        .sheet(isPresented: $showingNewEntry) {
            NewEntryView(date: firstDayOfMonth)
                .onDisappear {
                    loadEntries()
                }
        }
        .sheet(item: $selectedEntry) { entry in
            EditEntryView(entry: entry)
                .onDisappear {
                    loadEntries()
                }
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No entries for \(monthYearTitle)")
                .font(.title3)
                .fontWeight(.medium)
            
            Button(action: { showingNewEntry = true }) {
                Label("Add Entry", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var entriesList: some View {
        List {
            // Future Log section - only show if there are future entries
            if !futureEntries.isEmpty {
                futureLogSection
            }
            
            // Regular entries grouped by day
            ForEach(entriesByDay, id: \.date) { dayGroup in
                Section {
                    ForEach(dayGroup.entries) { entry in
                        EntryRowView(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                    .onDelete { indexSet in
                        deleteEntries(from: dayGroup.entries, at: indexSet)
                    }
                } header: {
                    Text(dayHeaderText(for: dayGroup.date))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var futureLogSection: some View {
        Section {
            ForEach(futureEntries) { entry in
                HStack(spacing: 12) {
                    // Entry type icon
                    Image(systemName: getEntryIcon(for: entry))
                        .font(.system(size: 16))
                        .foregroundColor(getEntryColor(for: entry))
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.content ?? "")
                            .font(.body)
                            .lineLimit(2)
                        
                        if let scheduledDate = entry.scheduledDate {
                            Text(scheduledDate, format: .dateTime.month(.abbreviated).day())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedEntry = entry
                }
            }
        } header: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.footnote)
                Text("From Future Log")
                    .textCase(.uppercase)
            }
            .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 16) {
                Button(action: {
                    onNavigatePrevious?()
                }) {
                    Image(systemName: "chevron.left")
                        .imageScale(.medium)
                        .foregroundColor(.accentColor)
                }
                
                Text(monthYearTitle)
                    .font(.headline)
                    .frame(minWidth: 120)
                
                Button(action: {
                    onNavigateNext?()
                }) {
                    Image(systemName: "chevron.right")
                        .imageScale(.medium)
                        .foregroundColor(.accentColor)
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingNewEntry = true }) {
                Image(systemName: "plus")
                    .imageScale(.large)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadEntries() {
        // Fetch regular journal entries for this month
        let calendar = Calendar.current
        let startComponents = DateComponents(year: year, month: month, day: 1)
        let endComponents = DateComponents(year: year, month: month + 1, day: 0)
        
        guard let startDate = calendar.date(from: startComponents),
              let endDate = calendar.date(from: endComponents) else { return }
        
        let context = CoreDataManager.shared.container.viewContext
        
        // Fetch journal entries for this month
        let journalRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        journalRequest.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@ AND (isFutureEntry == NO OR isFutureEntry == nil)",
            startDate as NSDate,
            endDate as NSDate
        )
        journalRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \JournalEntry.date, ascending: true)
        ]
        
        // Fetch future entries scheduled for this month
        let futureRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        futureRequest.predicate = NSPredicate(
            format: "isFutureEntry == YES AND scheduledDate >= %@ AND scheduledDate <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        futureRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \JournalEntry.scheduledDate, ascending: true)
        ]
        
        do {
            journalEntries = try context.fetch(journalRequest)
            futureEntries = try context.fetch(futureRequest)
        } catch {
            #if DEBUG
            print("Error fetching entries: \(error)")
            #endif
        }
    }
    
    private func dayHeaderText(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        
        // Check if it's today
        if calendar.isDateInToday(date) {
            return "\(monthName) \(day) - Today"
        } else {
            return "\(monthName) \(day)"
        }
    }
    
    private func getEntryIcon(for entry: JournalEntry) -> String {
        switch entry.entryType ?? "note" {
        case "task":
            return entry.taskStatus == "completed" ? "checkmark.circle.fill" : "circle"
        case "event":
            return "calendar"
        case "note":
            return "note.text"
        default:
            return "note.text"
        }
    }
    
    private func getEntryColor(for entry: JournalEntry) -> Color {
        switch entry.entryType ?? "note" {
        case "task":
            return entry.taskStatus == "completed" ? .green : .blue
        case "event":
            return .orange
        default:
            return .gray
        }
    }
    
    private func deleteEntries(from entries: [JournalEntry], at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            context.delete(entries[index])
        }
        
        do {
            try context.save()
            loadEntries()
        } catch {
            #if DEBUG
            print("Error deleting entry: \(error)")
            #endif
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MonthLogView(year: 2025, month: 6)
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}
