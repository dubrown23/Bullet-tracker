//
//  FutureLogView.swift
//  Bullet Tracker
//
//  Created on June 4, 2025
//

import SwiftUI
import CoreData

struct FutureLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var futureEntries: FetchedResults<JournalEntry>
    
    @State private var showingAddEntry = false
    @State private var selectedEntry: JournalEntry?
    
    // MARK: - Constants
    
    enum Layout {
        static let emptyStateImageSize: CGFloat = 60
        static let horizontalPadding: CGFloat = 40
        static let verticalSpacing: CGFloat = 20
        static let topPadding: CGFloat = 10
        static let rowVerticalPadding: CGFloat = 4
        static let rowSpacing: CGFloat = 12
        static let iconSize: CGFloat = 16
        static let iconFrameWidth: CGFloat = 24
    }
    
    // MARK: - Static Formatters
    
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    // MARK: - Init
    
    init() {
        _futureEntries = FetchRequest<JournalEntry>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \JournalEntry.scheduledDate, ascending: true),
                NSSortDescriptor(keyPath: \JournalEntry.date, ascending: false)
            ],
            predicate: NSPredicate(format: "isFutureEntry == YES"),
            animation: .default
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Group {
                if futureEntries.isEmpty {
                    emptyStateView
                } else {
                    futureEntriesList
                }
            }
            .navigationTitle("Future Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEntry = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEntry) {
                AddFutureEntryView()
            }
            .sheet(item: $selectedEntry) { entry in
                EditFutureEntryView(entry: entry)
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: Layout.verticalSpacing) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: Layout.emptyStateImageSize))
                .foregroundColor(.secondary)
            
            Text("No Future Entries")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Schedule tasks and events for future months")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.horizontalPadding)
            
            Button(action: { showingAddEntry = true }) {
                Label("Add Future Entry", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, Layout.topPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var futureEntriesList: some View {
        List {
            ForEach(groupedEntries.keys.sorted(), id: \.self) { monthKey in
                Section {
                    ForEach(groupedEntries[monthKey] ?? []) { entry in
                        FutureEntryRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEntry = entry
                            }
                    }
                    .onDelete { indexSet in
                        deleteEntries(from: groupedEntries[monthKey] ?? [], at: indexSet)
                    }
                } header: {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.footnote)
                        Text(monthKey)
                            .textCase(.uppercase)
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Computed Properties
    
    private var groupedEntries: [String: [JournalEntry]] {
        Dictionary(grouping: futureEntries) { entry in
            if let scheduledDate = entry.scheduledDate {
                return Self.monthYearFormatter.string(from: scheduledDate)
            } else {
                return "Unscheduled"
            }
        }
    }
    
    // MARK: - Methods
    
    private func deleteEntries(from entries: [JournalEntry], at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                viewContext.delete(entries[index])
            }
            
            do {
                try viewContext.save()
            } catch {
                // Handle error silently in production
            }
        }
    }
}

// MARK: - Future Entry Row

struct FutureEntryRow: View {
    let entry: JournalEntry
    
    // MARK: - Entry Type Configuration
    
    private enum EntryTypeConfig {
        case task
        case event
        case note
        
        init(from type: String?) {
            switch type {
            case "task": self = .task
            case "event": self = .event
            default: self = .note
            }
        }
        
        var icon: String {
            switch self {
            case .task: return "circle"
            case .event: return "calendar"
            case .note: return "note.text"
            }
        }
        
        var color: Color {
            switch self {
            case .task: return .blue
            case .event: return .orange
            case .note: return .gray
            }
        }
    }
    
    private var entryTypeConfig: EntryTypeConfig {
        EntryTypeConfig(from: entry.entryType)
    }
    
    var body: some View {
        HStack(spacing: FutureLogView.Layout.rowSpacing) {
            // Entry type icon
            Image(systemName: entryTypeConfig.icon)
                .font(.system(size: FutureLogView.Layout.iconSize))
                .foregroundColor(entryTypeConfig.color)
                .frame(width: FutureLogView.Layout.iconFrameWidth)
            
            VStack(alignment: .leading, spacing: 4) {
                // Entry content with inline date for events
                if entry.entryType == "event", let scheduledDate = entry.scheduledDate {
                    eventContent(scheduledDate: scheduledDate)
                } else {
                    regularContent
                }
            }
            
            Spacer()
        }
        .padding(.vertical, FutureLogView.Layout.rowVerticalPadding)
    }
    
    @ViewBuilder
    private func eventContent(scheduledDate: Date) -> some View {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: scheduledDate)
        
        HStack {
            Text(entry.content ?? "")
                .font(.body)
                .lineLimit(2)
            
            if day != 1 {
                Text("· \(scheduledDate, format: .dateTime.month(.abbreviated).day())")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var regularContent: some View {
        Text(entry.content ?? "")
            .font(.body)
            .lineLimit(2)
        
        // Show date below for non-events with specific dates
        if let scheduledDate = entry.scheduledDate, entry.entryType != "event" {
            let calendar = Calendar.current
            let day = calendar.component(.day, from: scheduledDate)
            
            if day != 1 {
                Text(scheduledDate, format: .dateTime.month(.abbreviated).day())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Add Future Entry View

struct AddFutureEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var entryContent = ""
    @State private var entryType = "note"
    @State private var selectedDate: Date?
    @State private var parsedDate: Date?
    @State private var showDatePicker = false
    
    // MARK: - Constants
    
    static let entryTypes = [
        ("task", "Task", "circle"),
        ("event", "Event", "calendar"),
        ("note", "Note", "note.text")
    ]
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            Form {
                contentSection
                dateSection
                tipsSection
            }
            .navigationTitle("Add Future Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: saveEntry)
                        .disabled(entryContent.isEmpty || !hasValidDate)
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var contentSection: some View {
        Section {
            // Entry type selector
            Picker("Type", selection: $entryType) {
                ForEach(Self.entryTypes, id: \.0) { type in
                    Label(type.1, systemImage: type.2)
                        .tag(type.0)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.vertical, 4)
            
            // Content input with @mention support
            VStack(alignment: .leading, spacing: 8) {
                TextField("Entry content (use @month to schedule)", text: $entryContent, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                    .onChange(of: entryContent) { _, newValue in
                        let result = FutureEntryParser.parseFutureDate(from: newValue)
                        parsedDate = result.scheduledDate
                    }
                
                // Show parsed date feedback
                if let date = parsedDate {
                    HStack {
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Scheduled for \(date, format: .dateTime.month(.wide).day().year())")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
    }
    
    private var dateSection: some View {
        Section {
            Toggle("Choose specific date", isOn: $showDatePicker)
            
            if showDatePicker {
                DatePicker("Scheduled Date",
                         selection: Binding(
                            get: { selectedDate ?? Date() },
                            set: { selectedDate = $0 }
                         ),
                         in: Date()...,
                         displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
            }
        } header: {
            Text("Or pick a date manually")
        }
    }
    
    private var tipsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tips:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Use @december or @dec to schedule for December")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Use @dec-25 for a specific date")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("• Use @12/25/2025 for full date")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasValidDate: Bool {
        parsedDate != nil || selectedDate != nil
    }
    
    // MARK: - Methods
    
    private func saveEntry() {
        let entry = JournalEntry(context: viewContext)
        entry.id = UUID()
        entry.date = Date()
        entry.entryType = entryType
        entry.isFutureEntry = true
        
        // Process content and date
        if showDatePicker, let manualDate = selectedDate {
            entry.content = entryContent
            entry.scheduledDate = manualDate
        } else if let parsed = parsedDate {
            let result = FutureEntryParser.parseFutureDate(from: entryContent)
            entry.content = result.cleanText
            entry.scheduledDate = parsed
        }
        
        // Find and assign to Future Log collection
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Future Log")
        fetchRequest.fetchLimit = 1
        
        do {
            if let futureLogCollection = try viewContext.fetch(fetchRequest).first {
                entry.collection = futureLogCollection
            }
            
            try viewContext.save()
            dismiss()
        } catch {
            // Handle error silently in production
        }
    }
}

// MARK: - Edit Future Entry View

struct EditFutureEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let entry: JournalEntry
    
    @State private var entryContent: String
    @State private var entryType: String
    @State private var scheduledDate: Date
    
    init(entry: JournalEntry) {
        self.entry = entry
        _entryContent = State(initialValue: entry.content ?? "")
        _entryType = State(initialValue: entry.entryType ?? "note")
        _scheduledDate = State(initialValue: entry.scheduledDate ?? Date())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    // Entry type selector
                    Picker("Type", selection: $entryType) {
                        ForEach(AddFutureEntryView.entryTypes, id: \.0) { type in
                            Label(type.1, systemImage: type.2)
                                .tag(type.0)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 4)
                    
                    // Content
                    TextField("Entry content", text: $entryContent, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Section {
                    DatePicker("Scheduled Date",
                             selection: $scheduledDate,
                             in: Date()...,
                             displayedComponents: .date)
                }
            }
            .navigationTitle("Edit Future Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save", action: saveChanges)
                }
            }
        }
    }
    
    private func saveChanges() {
        entry.content = entryContent
        entry.entryType = entryType
        entry.scheduledDate = scheduledDate
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            // Handle error silently in production
        }
    }
}

struct FutureLogView_Previews: PreviewProvider {
    static var previews: some View {
        FutureLogView()
            .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
    }
}

