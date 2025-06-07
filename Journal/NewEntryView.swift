//
//  NewEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct NewEntryView: View {
    // MARK: - Properties
    
    let date: Date
    
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    @State private var content: String = ""
    @State private var entryType: String = "task"
    @State private var taskStatus: String = "pending"
    @State private var priority: Bool = false
    @State private var tagsText: String = ""
    @State private var selectedCollection: Collection?
    @State private var collections: [Collection] = []
    
    // Future entry properties
    @State private var scheduleForLater: Bool = false
    @State private var parsedDate: Date?
    @State private var selectedFutureDate: Date?
    @State private var showDatePicker: Bool = false
    
    // Special entry properties (Phase 5)
    @State private var isSpecialEntry: Bool = false
    @State private var specialEntryType: String = "review"
    @State private var targetMonth: Date = Date()
    @State private var showExtendedEditor: Bool = false
    @State private var isDraft: Bool = false
    
    // MARK: - Computed Properties
    
    /// Determines if the save button should be disabled
    private var isSaveDisabled: Bool {
        if scheduleForLater {
            return content.isEmpty || !hasValidFutureDate
        } else {
            return content.isEmpty
        }
    }
    
    private var hasValidFutureDate: Bool {
        parsedDate != nil || selectedFutureDate != nil
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                entryDetailsSection
                
                if !isSpecialEntry {
                    scheduleSection
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEntry() }
                        .disabled(isSaveDisabled)
                }
            }
            .onAppear {
                loadCollections()
            }
            .sheet(isPresented: $showExtendedEditor) {
                SpecialEntryEditorView(
                    content: $content,
                    specialType: specialEntryType,
                    targetMonth: targetMonth,
                    isDraft: $isDraft,
                    onSave: saveEntry
                )
            }
            .onChange(of: entryType) { _, newValue in
                updateSpecialEntryState(for: newValue)
            }
        }
    }
    
    // MARK: - View Components
    
    private var entryDetailsSection: some View {
        Section(header: Text("Entry Details")) {
            entryTypePicker
            
            if isSpecialEntry {
                monthSelector
            } else {
                regularEntryControls
            }
        }
    }
    
    private var regularEntryControls: some View {
        Group {
            if entryType == "task" && !scheduleForLater {
                taskControls
            }
            
            contentField
            tagsField
            
            if !collections.isEmpty && !scheduleForLater {
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
                
                Picker("Month", selection: $targetMonth) {
                    ForEach(SpecialEntryTemplates.availableMonths(), id: \.self) { month in
                        Text(SpecialEntryTemplates.monthDisplayString(for: month))
                            .tag(month)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Button(action: { showExtendedEditor = true }) {
                HStack {
                    Image(systemName: specialEntryType == "review" ? "doc.text.magnifyingglass" : "calendar.badge.plus")
                    Text(buttonTitle)
                    Spacer()
                    if !content.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            if !content.isEmpty {
                contentPreview
            }
            
            if isDraft {
                Label("Draft - not published", systemImage: "doc.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private var buttonTitle: String {
        let action = content.isEmpty ? "Write" : "Edit"
        let type = specialEntryType == "review" ? "Review" : "Outlook"
        return "\(action) \(type)"
    }
    
    private var contentPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(content)
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
            Toggle("Schedule for Later", isOn: $scheduleForLater)
                .onChange(of: scheduleForLater) { _, newValue in
                    if !newValue {
                        resetFutureDateFields()
                    }
                }
            
            if scheduleForLater {
                futureSchedulingControls
            }
        }
    }
    
    private var futureSchedulingControls: some View {
        Group {
            if let date = parsedDate {
                HStack {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Scheduled for \(date, format: .dateTime.month(.wide).day().year())")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Toggle("Choose specific date", isOn: $showDatePicker)
            
            if showDatePicker {
                DatePicker(
                    "Future Date",
                    selection: Binding(
                        get: { selectedFutureDate ?? Date() },
                        set: { selectedFutureDate = $0 }
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
        Picker("Type", selection: $entryType) {
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
            Picker("Status", selection: $taskStatus) {
                Text("Pending").tag("pending")
                Text("Completed").tag("completed")
                Text("Migrated").tag("migrated")
                Text("Scheduled").tag("scheduled")
            }
            
            Toggle("Priority", isOn: $priority)
        }
    }
    
    private var contentField: some View {
        TextField(
            scheduleForLater ? "Content (use @month to schedule)" : "Content",
            text: $content
        )
        .onChange(of: content) { _, newValue in
            if scheduleForLater && !showDatePicker {
                let result = FutureEntryParser.parseFutureDate(from: newValue)
                parsedDate = result.scheduledDate
            }
        }
    }
    
    private var tagsField: some View {
        TextField("Tags (comma separated)", text: $tagsText)
    }
    
    private var collectionPicker: some View {
        Picker("Collection", selection: $selectedCollection) {
            Text("None").tag(nil as Collection?)
            ForEach(collections, id: \.self) { collection in
                Text(collection.name ?? "").tag(collection as Collection?)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateSpecialEntryState(for entryType: String) {
        if entryType == "review" || entryType == "outlook" {
            isSpecialEntry = true
            specialEntryType = entryType
            let calendar = Calendar.current
            targetMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
        } else {
            isSpecialEntry = false
        }
    }
    
    private func resetFutureDateFields() {
        parsedDate = nil
        selectedFutureDate = nil
        showDatePicker = false
    }
    
    private func loadCollections() {
        collections = CoreDataManager.shared.fetchAllCollections()
    }
    
    private func saveEntry() {
        let context = CoreDataManager.shared.container.viewContext
        
        if isSpecialEntry {
            saveSpecialEntry(in: context)
        } else if scheduleForLater {
            saveFutureEntry(in: context)
        } else {
            saveRegularEntry(in: context)
        }
        
        dismiss()
    }
    
    private func saveSpecialEntry(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        let calendar = Calendar.current
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
            
            let entry = JournalEntry(context: context)
            entry.id = UUID()
            entry.content = content
            entry.date = Date()
            entry.entryType = "note"
            entry.isSpecialEntry = true
            entry.specialEntryType = specialEntryType
            entry.targetMonth = targetMonth
            entry.isDraft = isDraft
            
            // Find appropriate collection
            let year = calendar.component(.year, from: targetMonth)
            let monthName = targetMonth.formatted(.dateTime.month(.wide))
            let monthCollectionName = "\(year)/\(monthName)"
            
            let collectionFetch: NSFetchRequest<Collection> = Collection.fetchRequest()
            collectionFetch.predicate = NSPredicate(format: "name == %@", monthCollectionName)
            collectionFetch.fetchLimit = 1
            
            if let monthCollection = try context.fetch(collectionFetch).first {
                entry.collection = monthCollection
            } else if let yearCollection = CoreDataManager.shared.getOrCreateYearCollection(year: year) {
                entry.collection = yearCollection
            }
            
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
        
        // Find Future Log collection
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Future Log")
        fetchRequest.fetchLimit = 1
        
        do {
            if let futureLogCollection = try context.fetch(fetchRequest).first {
                entry.collection = futureLogCollection
            }
            
            processTags(for: entry, in: context)
            try context.save()
        } catch {
            // Silent failure
        }
    }
    
    private func saveRegularEntry(in context: NSManagedObjectContext) {
        let entry = createJournalEntry(in: context)
        processTags(for: entry, in: context)
        
        do {
            try context.save()
        } catch {
            // Silent failure
        }
    }
    
    private func createJournalEntry(in context: NSManagedObjectContext) -> JournalEntry {
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
        
        return entry
    }
    
    private func processTags(for entry: JournalEntry, in context: NSManagedObjectContext) {
        guard !tagsText.isEmpty else { return }
        
        let tagNames = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for tagName in tagNames {
            let tag = findOrCreateTag(named: tagName, in: context)
            entry.addToTags(tag)
        }
    }
    
    private func findOrCreateTag(named tagName: String, in context: NSManagedObjectContext) -> Tag {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", tagName)
        fetchRequest.fetchLimit = 1
        
        do {
            if let existingTag = try context.fetch(fetchRequest).first {
                return existingTag
            }
        } catch {
            // Continue to create new tag
        }
        
        let newTag = Tag(context: context)
        newTag.id = UUID()
        newTag.name = tagName
        return newTag
    }
}
