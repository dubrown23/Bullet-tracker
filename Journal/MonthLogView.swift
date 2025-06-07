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
    
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Constants
    
    private enum Layout {
        static let emptyStateImageSize: CGFloat = 60
        static let verticalSpacing: CGFloat = 20
        static let iconSize: CGFloat = 16
        static let iconFrameWidth: CGFloat = 24
        static let rowVerticalPadding: CGFloat = 4
        static let rowSpacing: CGFloat = 12
        static let navigationButtonSpacing: CGFloat = 16
        static let titleMinWidth: CGFloat = 120
    }
    
    // MARK: - Static Formatters
    
    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()
    
    // MARK: - Entry Type Configuration
    
    private enum EntryTypeConfig {
        case task(completed: Bool)
        case event
        case note
        
        init(from entry: JournalEntry) {
            switch entry.entryType ?? "note" {
            case "task":
                self = .task(completed: entry.taskStatus == "completed")
            case "event":
                self = .event
            default:
                self = .note
            }
        }
        
        var icon: String {
            switch self {
            case .task(let completed):
                return completed ? "checkmark.circle.fill" : "circle"
            case .event:
                return "calendar"
            case .note:
                return "note.text"
            }
        }
        
        var color: Color {
            switch self {
            case .task(let completed):
                return completed ? .green : .blue
            case .event:
                return .orange
            case .note:
                return .gray
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var monthName: String {
        let components = DateComponents(year: year, month: month)
        let date = Calendar.current.date(from: components) ?? Date()
        return Self.monthFormatter.string(from: date)
    }
    
    private var monthYearTitle: String {
        "\(monthName) \(year)"
    }
    
    private var monthDateComponents: (current: Bool, past: Bool) {
        let calendar = Calendar.current
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)
        
        let isCurrent = year == currentYear && month == currentMonth
        let isPast = year < currentYear || (year == currentYear && month < currentMonth)
        
        return (current: isCurrent, past: isPast)
    }
    
    private var isCurrentMonth: Bool {
        monthDateComponents.current
    }
    
    private var isPastMonth: Bool {
        monthDateComponents.past
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
        .navigationTitle("")
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
        VStack(spacing: Layout.verticalSpacing) {
            Spacer()
            
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: Layout.emptyStateImageSize))
                .foregroundStyle(.secondary)
            
            Text("No entries for \(monthYearTitle)")
                .font(.title3)
                .fontWeight(.medium)
            
            if !isPastMonth {
                Button(action: { showingNewEntry = true }) {
                    Label("Add Entry", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var entriesList: some View {
        List {
            if !futureEntries.isEmpty {
                futureLogSection
            }
            
            ForEach(entriesByDay, id: \.date) { dayGroup in
                daySection(for: dayGroup)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    private var futureLogSection: some View {
        Section {
            ForEach(futureEntries) { entry in
                futureEntryRow(entry)
            }
        } header: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.footnote)
                Text("From Future Log")
                    .textCase(.uppercase)
            }
            .foregroundStyle(.secondary)
        }
    }
    
    private func daySection(for dayGroup: (date: Date, entries: [JournalEntry])) -> some View {
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
    
    private func futureEntryRow(_ entry: JournalEntry) -> some View {
        let typeConfig = EntryTypeConfig(from: entry)
        
        return HStack(spacing: Layout.rowSpacing) {
            Image(systemName: typeConfig.icon)
                .font(.system(size: Layout.iconSize))
                .foregroundStyle(typeConfig.color)
                .frame(width: Layout.iconFrameWidth)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.content ?? "")
                    .font(.body)
                    .lineLimit(2)
                
                if let scheduledDate = entry.scheduledDate {
                    Text(scheduledDate, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, Layout.rowVerticalPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEntry = entry
        }
    }
    
    // MARK: - Toolbar
        
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: Layout.navigationButtonSpacing) {
                Button(action: { onNavigatePrevious?() }) {
                    Image(systemName: "chevron.left")
                        .imageScale(.medium)
                        .foregroundStyle(Color.accentColor)
                }
                
                Text(monthYearTitle)
                    .font(.headline)
                    .frame(minWidth: Layout.titleMinWidth)
                
                Button(action: { onNavigateNext?() }) {
                    Image(systemName: "chevron.right")
                        .imageScale(.medium)
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            if !isPastMonth {
                Button(action: { showingNewEntry = true }) {
                    Image(systemName: "plus")
                        .imageScale(.large)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadEntries() {
        if isPastMonth {
            loadFromArchiveCollection()
        } else {
            loadByDateRange()
        }
    }
    
    private func loadFromArchiveCollection() {
        let calendar = Calendar.current
        let monthNameFromSymbols = calendar.monthSymbols[month - 1]
        let archiveCollectionName = "\(year)/\(monthNameFromSymbols)"
        
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@ AND isAutomatic == true", archiveCollectionName)
        fetchRequest.fetchLimit = 1
        
        do {
            let collections = try viewContext.fetch(fetchRequest)
            
            if let archiveCollection = collections.first,
               let entries = archiveCollection.entries as? Set<JournalEntry> {
                
                let allEntries = Array(entries)
                
                journalEntries = allEntries
                    .filter { !$0.isSpecialEntry && !$0.isFutureEntry }
                    .sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
                
                futureEntries = allEntries
                    .filter { $0.isFutureEntry }
                    .sorted { ($0.scheduledDate ?? Date()) < ($1.scheduledDate ?? Date()) }
            } else {
                journalEntries = []
                futureEntries = []
            }
        } catch {
            journalEntries = []
            futureEntries = []
        }
    }
    
    private func loadByDateRange() {
        let calendar = Calendar.current
        let startComponents = DateComponents(year: year, month: month, day: 1)
        
        guard let startDate = calendar.date(from: startComponents),
              let endDate = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate),
              let endDateInclusive = calendar.date(byAdding: .day, value: 1, to: endDate) else {
            return
        }
        
        // Fetch journal entries
        let journalRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        journalRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND (isFutureEntry == NO OR isFutureEntry == nil) AND isSpecialEntry == NO",
            startDate as NSDate,
            endDateInclusive as NSDate
        )
        journalRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \JournalEntry.date, ascending: true)
        ]
        
        // Fetch future entries
        let futureRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        futureRequest.predicate = NSPredicate(
            format: "isFutureEntry == YES AND scheduledDate >= %@ AND scheduledDate < %@",
            startDate as NSDate,
            endDateInclusive as NSDate
        )
        futureRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \JournalEntry.scheduledDate, ascending: true)
        ]
        
        do {
            journalEntries = try viewContext.fetch(journalRequest)
            futureEntries = try viewContext.fetch(futureRequest)
        } catch {
            // Handle error silently in production
        }
    }
    
    private func dayHeaderText(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        
        if calendar.isDateInToday(date) {
            return "\(monthName) \(day) - Today"
        } else {
            return "\(monthName) \(day)"
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
            // Handle error silently in production
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
