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
            // For future entries, need content and a valid date
            return content.isEmpty || (!hasValidFutureDate)
        } else {
            // For regular entries, just need content
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
                
                // Schedule for later section
                if !isSpecialEntry {
                    scheduleSection
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                toolbarContent
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
                    onSave: {
                        saveEntry()
                    }
                )
            }
            .onChange(of: entryType) { _, newValue in
                // Check if this is a special entry type
                if newValue == "review" || newValue == "outlook" {
                    isSpecialEntry = true
                    specialEntryType = newValue
                    // Set default target month to current month
                    let calendar = Calendar.current
                    targetMonth = calendar.dateInterval(of: .month, for: Date())?.start ?? Date()
                    // Don't auto-open the editor anymore
                } else {
                    isSpecialEntry = false
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var entryDetailsSection: some View {
        Section(header: Text("Entry Details")) {
            entryTypePicker
            
            if isSpecialEntry {
                // Month selector for special entries
                monthSelector
            } else {
                // Regular entry controls
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
    }
    
    private var monthSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month picker
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
            
            // Edit button to open editor
            Button(action: {
                showExtendedEditor = true
            }) {
                HStack {
                    Image(systemName: specialEntryType == "review" ? "doc.text.magnifyingglass" : "calendar.badge.plus")
                    Text(content.isEmpty ? "Write \(specialEntryType == "review" ? "Review" : "Outlook")" : "Edit \(specialEntryType == "review" ? "Review" : "Outlook")")
                    Spacer()
                    if !content.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            
            // Show content preview if exists
            if !content.isEmpty {
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
            
            if isDraft {
                Label("Draft - not published", systemImage: "doc.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private var scheduleSection: some View {
        Section(header: Text("Scheduling")) {
            Toggle("Schedule for Later", isOn: $scheduleForLater)
                .onChange(of: scheduleForLater) { _, newValue in
                    if !newValue {
                        // Reset future date fields when toggled off
                        parsedDate = nil
                        selectedFutureDate = nil
                        showDatePicker = false
                    }
                }
            
            if scheduleForLater {
                // Show parsed date feedback
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
                
                // Manual date picker option
                Toggle("Choose specific date", isOn: $showDatePicker)
                
                if showDatePicker {
                    DatePicker("Future Date",
                             selection: Binding(
                                get: { selectedFutureDate ?? Date() },
                                set: { selectedFutureDate = $0 }
                             ),
                             in: Date()...,
                             displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                }
                
                // Tips for @mentions
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Use @december or @dec in your content")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("• Use @dec-25 for a specific date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
        }
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
        TextField(scheduleForLater ? "Content (use @month to schedule)" : "Content", text: $content)
            .onChange(of: content) { _, newValue in
                if scheduleForLater && !showDatePicker {
                    // Parse for @mentions as user types
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
    
    // MARK: - Toolbar Components
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") {
                saveEntry()
            }
            .disabled(isSaveDisabled)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Loads all collections from Core Data
    private func loadCollections() {
        collections = CoreDataManager.shared.fetchAllCollections()
    }
    
    /// Saves the new journal entry to Core Data
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
    
    /// Saves a special entry (review or outlook)
    private func saveSpecialEntry(in context: NSManagedObjectContext) {
        // Check for ANY existing entry of same type for same month (draft or published)
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
            
            // Delete ALL existing entries for this type/month (not just drafts)
            for existingEntry in existingEntries {
                context.delete(existingEntry)
            }
            
            // Create new entry
            let entry = JournalEntry(context: context)
            entry.id = UUID()
            entry.content = content
            entry.date = Date()
            entry.entryType = "note" // Base type
            entry.isSpecialEntry = true
            entry.specialEntryType = specialEntryType
            entry.targetMonth = targetMonth
            entry.isDraft = isDraft
            
            // Find the appropriate month collection (from Phase 4 archives)
            let year = calendar.component(.year, from: targetMonth)
            let _ = calendar.component(.month, from: targetMonth)
            let monthName = targetMonth.formatted(.dateTime.month(.wide))
            let monthCollectionName = "\(year)/\(monthName)"
            
            // Try to find existing month collection
            let collectionFetch: NSFetchRequest<Collection> = Collection.fetchRequest()
            collectionFetch.predicate = NSPredicate(format: "name == %@", monthCollectionName)
            collectionFetch.fetchLimit = 1
            
            if let monthCollection = try context.fetch(collectionFetch).first {
                entry.collection = monthCollection
            } else {
                // If no month collection exists, use year collection
                if let yearCollection = CoreDataManager.shared.getOrCreateYearCollection(year: year) {
                    entry.collection = yearCollection
                }
            }
            
            try context.save()
            #if DEBUG
            print("Special entry saved successfully to collection: \(entry.collection?.name ?? "none")")
            #endif
        } catch {
            #if DEBUG
            print("Error saving special entry: \(error)")
            #endif
        }
    }
    /// Saves a future entry
    private func saveFutureEntry(in context: NSManagedObjectContext) {
        let entry = JournalEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        entry.entryType = entryType
        entry.isFutureEntry = true
        entry.priority = priority
        
        // Process content and date
        if showDatePicker, let manualDate = selectedFutureDate {
            // Using manual date picker
            entry.content = content
            entry.scheduledDate = manualDate
        } else if let parsed = parsedDate {
            // Using @mention parsing
            let result = FutureEntryParser.parseFutureDate(from: content)
            entry.content = result.cleanText
            entry.scheduledDate = parsed
        }
        
        // Find and assign to Future Log collection
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Future Log")
        fetchRequest.fetchLimit = 1
        
        do {
            if let futureLogCollection = try context.fetch(fetchRequest).first {
                entry.collection = futureLogCollection
            }
            
            // Process tags
            processTags(for: entry, in: context)
            
            try context.save()
            #if DEBUG
            print("Future entry saved successfully")
            #endif
        } catch {
            #if DEBUG
            print("Error saving future entry: \(error)")
            #endif
        }
    }
    
    /// Saves a regular entry (existing functionality)
    private func saveRegularEntry(in context: NSManagedObjectContext) {
        let entry = createJournalEntry(in: context)
        processTags(for: entry, in: context)
        
        do {
            try context.save()
            #if DEBUG
            print("Entry saved successfully")
            #endif
        } catch {
            #if DEBUG
            print("Error saving entry: \(error)")
            #endif
        }
    }
    
    /// Creates a new journal entry with the current form data
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
    
    /// Processes and adds tags to the journal entry
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
    
    /// Finds an existing tag or creates a new one
    private func findOrCreateTag(named tagName: String, in context: NSManagedObjectContext) -> Tag {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", tagName)
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let existingTag = results.first {
                return existingTag
            }
        } catch {
            #if DEBUG
            print("Error fetching tag: \(error)")
            #endif
        }
        
        // Create new tag if not found
        let newTag = Tag(context: context)
        newTag.id = UUID()
        newTag.name = tagName
        return newTag
    }
}
