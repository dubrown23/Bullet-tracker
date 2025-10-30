//
//  EditEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

// MARK: - Shared Entry Form View Model

@MainActor
class EntryFormViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var content: String = ""
    @Published var entryType: String = "task"
    @Published var taskStatus: String = "pending"
    @Published var selectedCollection: Collection?
    @Published var tagsText: String = ""
    @Published var priority: Bool = false
    @Published var collections: [Collection] = []
    
    // Future entry properties (for unified approach)
    @Published var scheduleForLater: Bool = false
    @Published var parsedDate: Date?
    @Published var selectedFutureDate: Date?
    @Published var showDatePicker: Bool = false
    
    // Special entry properties
    @Published var isSpecialEntry: Bool = false
    @Published var specialEntryType: String = "review"
    @Published var targetMonth: Date = Date()
    @Published var isDraft: Bool = false
    
    // MARK: - Private Properties
    
    private var entry: JournalEntry?
    private var cachedCollections: [Collection]?
    private let calendar = Calendar.current
    
    // MARK: - Computed Properties
    
    var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var canEditSpecialProperties: Bool {
        // Only allow editing special properties for new entries
        entry == nil
    }
    
    // MARK: - Initialization
    
    init(entry: JournalEntry? = nil, date: Date = Date()) {
        self.entry = entry
        loadCollections()
        
        if let entry = entry {
            loadEntryData(from: entry)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadEntryData(from entry: JournalEntry) {
        content = entry.content ?? ""
        entryType = entry.entryType ?? "task"
        taskStatus = entry.taskStatus ?? "pending"
        selectedCollection = entry.collection
        priority = entry.priority
        
        // Load tags
        if let tags = entry.tags as? Set<Tag> {
            tagsText = tags
                .compactMap { $0.name }
                .sorted()
                .joined(separator: ", ")
        }
        
        // Load future entry data
        if entry.isFutureEntry {
            scheduleForLater = true
            if let scheduledDate = entry.scheduledDate {
                selectedFutureDate = scheduledDate
                showDatePicker = true
            }
        }
        
        // Load special entry data
        if entry.isSpecialEntry {
            isSpecialEntry = true
            specialEntryType = entry.specialEntryType ?? "review"
            targetMonth = entry.targetMonth ?? Date()
            isDraft = entry.isDraft
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
    
    // MARK: - Save Methods
    
    func saveEntry() {
        if let existingEntry = entry {
            updateExistingEntry(existingEntry)
        } else {
            createNewEntry()
        }
    }
    
    private func updateExistingEntry(_ entry: JournalEntry) {
        // Update basic properties
        entry.content = content
        entry.entryType = entryType
        entry.taskStatus = entryType == "task" ? taskStatus : nil
        entry.priority = priority
        entry.collection = selectedCollection
        
        // Update future entry properties if applicable
        if entry.isFutureEntry && scheduleForLater {
            if showDatePicker, let date = selectedFutureDate {
                entry.scheduledDate = date
            } else if let parsed = parsedDate {
                let result = FutureEntryParser.parseFutureDate(from: content)
                entry.content = result.cleanText
                entry.scheduledDate = parsed
            }
        }
        
        // Update special entry properties if applicable
        if entry.isSpecialEntry {
            entry.isDraft = isDraft
            // Note: We don't allow changing targetMonth or specialEntryType for existing entries
        }
        
        // Process tags
        TagProcessor.processTags(from: tagsText, for: entry, in: entry.managedObjectContext!)
        
        // Save
        CoreDataManager.shared.saveContext()
    }
    
    private func createNewEntry() {
        // This path would be used if we unify NewEntryView with EditEntryView
        // For now, this is a placeholder
        let context = CoreDataManager.shared.container.viewContext
        let entry = JournalEntry(context: context)
        entry.id = UUID()
        entry.date = Date()
        
        updateExistingEntry(entry)
    }
    
    func deleteEntry() {
        guard let entry = entry else { return }
        CoreDataManager.shared.deleteJournalEntry(entry)
    }
}

// MARK: - Edit Entry View

struct EditEntryView: View {
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @ObservedObject var entry: JournalEntry
    
    // MARK: - State Properties
    
    @StateObject private var viewModel: EntryFormViewModel
    @State private var showingDeleteAlert = false
    
    // MARK: - Initialization
    
    init(entry: JournalEntry) {
        self.entry = entry
        self._viewModel = StateObject(wrappedValue: EntryFormViewModel(entry: entry))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                entryDetailsSection
                
                if entry.isFutureEntry {
                    futureEntrySection
                }
                
                if entry.isSpecialEntry {
                    specialEntrySection
                }
                
                deleteSection
            }
            .navigationTitle("Edit Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveEntry()
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
            .alert("Delete Entry", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteEntry()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this entry? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var entryDetailsSection: some View {
        Section(header: Text("Entry Details")) {
            // Only allow type change for non-special entries
            if !entry.isSpecialEntry {
                Picker("Type", selection: $viewModel.entryType) {
                    Text("Task").tag("task")
                    Text("Event").tag("event")
                    Text("Note").tag("note")
                }
                .pickerStyle(.segmented)
                .disabled(entry.isFutureEntry) // Future entries maintain their type
            }
            
            if viewModel.entryType == "task" && !entry.isFutureEntry {
                taskControls
            }
            
            TextField("Content", text: $viewModel.content)
            
            if !entry.isSpecialEntry {
                TextField("Tags (comma separated)", text: $viewModel.tagsText)
            }
            
            if !viewModel.collections.isEmpty && !entry.isFutureEntry && !entry.isSpecialEntry {
                collectionPicker
            }
        }
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
    
    private var collectionPicker: some View {
        Picker("Collection", selection: $viewModel.selectedCollection) {
            Text("None").tag(nil as Collection?)
            ForEach(viewModel.collections, id: \.self) { collection in
                Text(collection.name ?? "").tag(collection as Collection?)
            }
        }
    }
    
    private var futureEntrySection: some View {
        Section(header: Text("Future Entry")) {
            if let scheduledDate = entry.scheduledDate {
                HStack {
                    Text("Scheduled for")
                    Spacer()
                    Text(scheduledDate, format: .dateTime.month(.wide).day().year())
                        .foregroundStyle(.secondary)
                }
            }
            
            if viewModel.showDatePicker {
                DatePicker(
                    "Reschedule",
                    selection: Binding(
                        get: { viewModel.selectedFutureDate ?? Date() },
                        set: { viewModel.selectedFutureDate = $0 }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )
            }
            
            Toggle("Change date", isOn: $viewModel.showDatePicker)
        }
    }
    
    private var specialEntrySection: some View {
        Section(header: Text("Special Entry")) {
            HStack {
                Text("Type")
                Spacer()
                Text(entry.specialEntryType == "review" ? "📝 Review" : "📅 Outlook")
                    .foregroundStyle(.secondary)
            }
            
            if let targetMonth = entry.targetMonth {
                HStack {
                    Text("Month")
                    Spacer()
                    Text(targetMonth, format: .dateTime.month(.wide).year())
                        .foregroundStyle(.secondary)
                }
            }
            
            Toggle("Draft", isOn: $viewModel.isDraft)
        }
    }
    
    private var deleteSection: some View {
        Section {
            Button("Delete Entry", role: .destructive) {
                showingDeleteAlert = true
            }
        }
    }
}
