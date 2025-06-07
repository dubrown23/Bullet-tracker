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
    
    @State private var selectedEntry: JournalEntry?
    
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Constants
    
    private enum Layout {
        static let emptyStateImageSize: CGFloat = 48
        static let verticalSpacing: CGFloat = 16
        static let sectionSpacing: CGFloat = 12
        static let summaryCornerRadius: CGFloat = 10
        static let badgeCornerRadius: CGFloat = 6
        static let specialEntryOpacity: Double = 0.05
        static let badgeOpacity: Double = 0.1
        static let horizontalPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 4
    }
    
    // MARK: - Computed Properties
    
    private var allEntries: [JournalEntry] {
        guard let monthEntries = monthCollection.entries as? Set<JournalEntry> else {
            return []
        }
        return Array(monthEntries).sorted { ($0.date ?? Date()) < ($1.date ?? Date()) }
    }
    
    private var specialEntries: [JournalEntry] {
        allEntries
            .filter { $0.isSpecialEntry }
            .sorted { entry1, entry2 in
                // Reviews before outlooks
                if entry1.specialEntryType != entry2.specialEntryType {
                    return entry1.specialEntryType == "review"
                }
                // Then by date
                return (entry1.date ?? Date()) < (entry2.date ?? Date())
            }
    }
    
    private var regularEntries: [JournalEntry] {
        allEntries.filter { !$0.isSpecialEntry }
    }
    
    private var groupedEntries: [Date: [JournalEntry]] {
        Dictionary(grouping: regularEntries) { entry in
            Calendar.current.startOfDay(for: entry.date ?? Date())
        }
    }
    
    private var sortedDates: [Date] {
        groupedEntries.keys.sorted()
    }
    
    private var entryCounts: (tasks: Int, events: Int, notes: Int) {
        regularEntries.reduce((0, 0, 0)) { counts, entry in
            switch entry.entryType {
            case EntryType.task.rawValue:
                return (counts.tasks + 1, counts.events, counts.notes)
            case EntryType.event.rawValue:
                return (counts.tasks, counts.events + 1, counts.notes)
            default:
                return (counts.tasks, counts.events, counts.notes + 1)
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if allEntries.isEmpty {
                emptyStateView
            } else {
                entryList
            }
        }
        .navigationTitle("\(month) \(year)")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedEntry) { entry in
            if entry.isSpecialEntry {
                SpecialEntryDetailView(entry: entry)
            } else {
                EditEntryView(entry: entry)
            }
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        VStack(spacing: Layout.verticalSpacing) {
            Spacer()
            
            Image(systemName: "tray")
                .font(.system(size: Layout.emptyStateImageSize))
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
            // Special Entries Section
            if !specialEntries.isEmpty {
                specialEntriesSection
            }
            
            // Summary Section
            Section {
                monthSummaryHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            
            // Regular Entries by Date
            ForEach(sortedDates, id: \.self) { date in
                daySection(for: date)
            }
        }
        .listStyle(.plain)
    }
    
    private var specialEntriesSection: some View {
        Section {
            ForEach(specialEntries) { entry in
                EntryRowView(entry: entry)
                    .listRowBackground(specialEntryBackground(for: entry))
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
    
    private func specialEntryBackground(for entry: JournalEntry) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(entry.specialEntryType == "review"
                  ? Color.purple.opacity(Layout.specialEntryOpacity)
                  : Color.green.opacity(Layout.specialEntryOpacity))
    }
    
    private func daySection(for date: Date) -> some View {
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
    
    @ViewBuilder
    private var monthSummaryHeader: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Summary")
                        .font(.title3.bold())
                    Text("\(regularEntries.count) entries archived")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                entryTypeBreakdown
            }
            
            if !specialEntries.isEmpty {
                specialEntriesIndicator
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(Layout.summaryCornerRadius)
        .padding(.horizontal)
    }
    
    private var entryTypeBreakdown: some View {
        VStack(alignment: .trailing, spacing: 4) {
            entryTypeRow(icon: "circle", count: entryCounts.tasks, label: "tasks")
            entryTypeRow(icon: "calendar", count: entryCounts.events, label: "events")
            entryTypeRow(icon: "note.text", count: entryCounts.notes, label: "notes")
        }
        .foregroundStyle(.secondary)
    }
    
    private func entryTypeRow(icon: String, count: Int, label: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
            Text("\(count) \(label)")
                .font(.caption)
        }
    }
    
    private var specialEntriesIndicator: some View {
        HStack(spacing: Layout.sectionSpacing) {
            ForEach(specialEntries) { entry in
                specialEntryBadge(for: entry)
            }
        }
    }
    
    private func specialEntryBadge(for entry: JournalEntry) -> some View {
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
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                .fill(entry.specialEntryType == "review"
                      ? Color.purple.opacity(Layout.badgeOpacity)
                      : Color.green.opacity(Layout.badgeOpacity))
        )
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
