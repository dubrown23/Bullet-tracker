//
//  NewEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

// MARK: - Tag Processing Utility

struct TagProcessor {
    static func processTags(from text: String, for entry: JournalEntry, in context: NSManagedObjectContext) {
        guard !text.isEmpty else { return }
        
        let tagNames = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for tagName in tagNames {
            let tag = CoreDataManager.shared.getOrCreateTag(name: tagName)
            entry.addToTags(tag)
        }
    }
}

// MARK: - View Model

@MainActor
class NewEntryViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var content: String = ""
    @Published var entryType: String = "task"
    @Published var taskStatus: String = "pending"
    @Published var priority: Bool = false
    @Published var tagsText: String = ""
    @Published var selectedCollection: Collection?
    @Published var collections: [Collection] = []
    
    // Future entry properties
    @Published var scheduleForLater: Bool = false
    @Published var parsedDate: Date?
    @Published var selectedFutureDate: Date?
    @Published var showDatePicker: Bool = false
    
    // Special entry properties
    @Published var isSpecialEntry: Bool = false
    @Published var specialEntryType: String = "review"
    @Published var targetMonth: Date = Date()
    @Published var showExtendedEditor: Bool = false
    @Published var isDraft: Bool = false
    
    // MARK: - Private Properties
    
    private let date: Date
    private var cachedCollections: [Collection]?
    private let calendar = Calendar.current
    
    // MARK: - Computed Properties
    
    var isSaveDisabled: Bool {
        if scheduleForLater {
            return content.isEmpty || !hasValidFutureDate
        } else {
            return content.isEmpty
        }
    }
    
    var hasValidFutureDate: Bool {
        parsedDate != nil || selectedFutureDate != nil
    }
    
    // MARK: - Initialization
    
    init(date: Date) {
        self.date = date
        loadCollections()
    }
    
    // MARK: - Public Methods
    
    func updateEntryType(_ newType: String) {
        entryType = newType
        
        if newType == "review" || newType == "outlook" {
            isSpecialEntry = true
            specialEntryType = newType
            targetMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        } else {
            isSpecialEntry = false
        }
    }
    
    func updateScheduleForLater(_ value: Bool) {
        scheduleForLater = value
        if !value {
            parsedDate = nil
            selectedFutureDate = nil
            showDatePicker = false
        }
    }
    
    func updateContent(_ newContent: String) {
        content = newContent
        if scheduleForLater && !showDatePicker {
            let result = FutureEntryParser.parseFutureDate(from: newContent)
            parsedDate = result.scheduledDate
        }
    }
    
    func loadCollections() {
        if let cached = cachedCollections {
            collections = cached
        } else {
            collections = CoreDataManager.shared.fetchAllCollections()
            cachedCollections = collections
        }
    }
    
    func saveEntry() {
        let context = CoreDataManager.shared.container.viewContext
        
        if isSpecialEntry {
            saveSpecialEntry(in: context)
        } else if scheduleForLater {
            saveFutureEntry(in: context)
        } else {
            saveRegularEntry(in: context)
        }
    }
    
    // MARK: - Private Save Methods
    
    private func saveSpecialEntry(in context: NSManagedObjectContext) {
        // Remove existing entry for the same month/type
        removeExistingSpecialEntry(in: context)
        
        let entry = JournalEntry(context: context)
        entry.id = UUID()
        entry.content = content
        entry.date = Date()
        entry.entryType = "note"
        entry.isSpecialEntry = true
        entry.specialEntryType = specialEntryType
        entry.targetMonth = targetMonth
        entry.isDraft = isDraft
        
        // Set collection
        entry.collection = findAppropriateCollection(for: targetMonth, in: context)
        
        do {
            try context.save()
        } catch {
            // Silent failure
        }
    }
    
    private func saveFutureEntry(in context: NSManagedObjectContext) {
        let entry = JournalEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        entry.entryType = entryType
        entry.isFutureEntry = true
        entry.priority = priority
        
        if showDatePicker, let manualDate = selectedFutureDate {
            entry.content = content
            entry.scheduledDate = manualDate
        } else if let parsed = parsedDate {
            let result = FutureEntryParser.parseFutureDate(from: content)
            entry.content = result.cleanText
            entry.scheduledDate = parsed
        }
        
        // Set Future Log collection
        entry.collection = findFutureLogCollection(in: context)
        
        TagProcessor.processTags(from: tagsText, for: entry, in: context)
        
        do {
            try context.save()
        } catch {
            // Silent failure
        }
    }
    
    private func saveRegularEntry(in context: NSManagedObjectContext) {
        let entry = JournalEntry(context: context)
        entry.id = UUID()
        entry.content = content
        entry.date = date
        entry.entryType = entryType
        entry.priority = priority
        
        if entryType == "task" {
            entry.taskStatus = taskStatus
        }
        
        entry.collection = selectedCollection
        
        TagProcessor.processTags(from: tagsText, for: entry, in: context)
        
        do {
            try context.save()
        } catch {
            // Silent failure
        }
    }
    
    // MARK: - Helper Methods
    
    private func removeExistingSpecialEntry(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        let monthStart = calendar.dateInterval(of: .month, for: targetMonth)?.start ?? targetMonth
        let monthEnd = calendar.dateInterval(of: .month, for: targetMonth)?.end ?? targetMonth
        
        fetchRequest.predicate = NSPredicate(
            format: "isSpecialEntry == %@ AND specialEntryType == %@ AND targetMonth >= %@ AND targetMonth < %@",
            NSNumber(value: true),
            specialEntryType,
            monthStart as NSDate,
            monthEnd as NSDate
        )
        
        do {
            let existingEntries = try context.fetch(fetchRequest)
            existingEntries.forEach { context.delete($0) }
        } catch {
            // Silent failure
        }
    }
    
    private func findAppropriateCollection(for date: Date, in context: NSManagedObjectContext) -> Collection? {
        let year = calendar.component(.year, from: date)
        let monthName = date.formatted(.dateTime.month(.wide))
        let monthCollectionName = "\(year)/\(monthName)"
        
        let collectionFetch: NSFetchRequest<Collection> = Collection.fetchRequest()
        collectionFetch.predicate = NSPredicate(format: "name == %@", monthCollectionName)
        collectionFetch.fetchLimit = 1
        
        do {
            if let monthCollection = try context.fetch(collectionFetch).first {
                return monthCollection
            }
        } catch {
            // Continue to year collection
        }
        
        return CoreDataManager.shared.getOrCreateYearCollection(year: year)
    }
    
    private func findFutureLogCollection(in context: NSManagedObjectContext) -> Collection? {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Future Log")
        fetchRequest.fetchLimit = 1
        
        do {
            return try context.fetch(fetchRequest).first
        } catch {
            return nil
        }
    }
}

// MARK: - Main View

struct NewEntryView: View {
    // MARK: - Properties
    
    let date: Date
    
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    @StateObject private var viewModel: NewEntryViewModel
    
    // MARK: - Initialization
    
    init(date: Date) {
        self.date = date
        self._viewModel = StateObject(wrappedValue: NewEntryViewModel(date: date))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                entryDetailsSection
                
                if !viewModel.isSpecialEntry {
                    scheduleSection
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveEntry()
                        dismiss()
                    }
                    .disabled(viewModel.isSaveDisabled)
                }
            }
            .sheet(isPresented: $viewModel.showExtendedEditor) {
                SpecialEntryEditorView(
                    content: $viewModel.content,
                    specialType: viewModel.specialEntryType,
                    targetMonth: viewModel.targetMonth,
                    isDraft: $viewModel.isDraft,
                    onSave: {
                        viewModel.saveEntry()
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - View Components
    
    private var entryDetailsSection: some View {
        Section(header: Text("Entry Details")) {
            entryTypePicker
            
            if viewModel.isSpecialEntry {
                monthSelector
            } else {
                regularEntryControls
            }
        }
    }
    
    private var regularEntryControls: some View {
        Group {
            if viewModel.entryType == "task" && !viewModel.scheduleForLater {
                taskControls
            }
            
            contentField
            tagsField
            
            if !viewModel.collections.isEmpty && !viewModel.scheduleForLater {
                collectionPicker
            }
        }
    }
    
    private var monthSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Month")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Picker("Month", selection: $viewModel.targetMonth) {
                    ForEach(SpecialEntryTemplates.availableMonths(), id: \.self) { month in
                        Text(SpecialEntryTemplates.monthDisplayString(for: month))
                            .tag(month)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Button(action: { viewModel.showExtendedEditor = true }) {
                HStack {
                    Image(systemName: viewModel.specialEntryType == "review" ? "doc.text.magnifyingglass" : "calendar.badge.plus")
                    Text(buttonTitle)
                    Spacer()
                    if !viewModel.content.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            if !viewModel.content.isEmpty {
                contentPreview
            }
            
            if viewModel.isDraft {
                Label("Draft - not published", systemImage: "doc.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private var buttonTitle: String {
        let action = viewModel.content.isEmpty ? "Write" : "Edit"
        let type = viewModel.specialEntryType == "review" ? "Review" : "Outlook"
        return "\(action) \(type)"
    }
    
    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(viewModel.content)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
    
    private var scheduleSection: some View {
        Section(header: Text("Scheduling")) {
            Toggle("Schedule for Later", isOn: Binding(
                get: { viewModel.scheduleForLater },
                set: { viewModel.updateScheduleForLater($0) }
            ))
            
            if viewModel.scheduleForLater {
                futureSchedulingControls
            }
        }
    }
    
    private var futureSchedulingControls: some View {
        Group {
            if let date = viewModel.parsedDate {
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Scheduled for \(date, format: .dateTime.month(.wide).day().year())")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Toggle("Choose specific date", isOn: $viewModel.showDatePicker)
            
            if viewModel.showDatePicker {
                DatePicker(
                    "Future Date",
                    selection: Binding(
                        get: { viewModel.selectedFutureDate ?? Date() },
                        set: { viewModel.selectedFutureDate = $0 }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(GraphicalDatePickerStyle())
            }
            
            schedulingTips
        }
    }
    
    private var schedulingTips: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tips:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach([
                "Use @december or @dec in your content",
                "Use @dec-25 for a specific date"
            ], id: \.self) { tip in
                Text("• \(tip)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }
    
    private var entryTypePicker: some View {
        Picker("Type", selection: Binding(
            get: { viewModel.entryType },
            set: { viewModel.updateEntryType($0) }
        )) {
            Text("Task").tag("task")
            Text("Event").tag("event")
            Text("Note").tag("note")
            Text("📝 Review").tag("review")
            Text("📅 Outlook").tag("outlook")
        }
        .pickerStyle(.segmented)
    }
    
    private var taskControls: some View {
        Group {
            Picker("Status", selection: $viewModel.taskStatus) {
                Text("Pending").tag("pending")
                Text("Completed").tag("completed")
                Text("Migrated").tag("migrated")
                Text("Scheduled").tag("scheduled")
            }
            
            Toggle("Priority", isOn: $viewModel.priority)
        }
    }
    
    private var contentField: some View {
        TextField(
            viewModel.scheduleForLater ? "Content (use @month to schedule)" : "Content",
            text: Binding(
                get: { viewModel.content },
                set: { viewModel.updateContent($0) }
            )
        )
    }
    
    private var tagsField: some View {
        TextField("Tags (comma separated)", text: $viewModel.tagsText)
    }
    
    private var collectionPicker: some View {
        Picker("Collection", selection: $viewModel.selectedCollection) {
            Text("None").tag(nil as Collection?)
            ForEach(viewModel.collections, id: \.self) { collection in
                Text(collection.name ?? "").tag(collection as Collection?)
            }
        }
    }
}
