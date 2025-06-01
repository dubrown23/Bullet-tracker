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
    
    // MARK: - Computed Properties
    
    /// Determines if the save button should be disabled
    private var isSaveDisabled: Bool {
        content.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                entryDetailsSection
            }
            .navigationTitle("New Entry")
            .toolbar {
                toolbarContent
            }
            .onAppear {
                loadCollections()
            }
        }
    }
    
    // MARK: - View Components
    
    private var entryDetailsSection: some View {
        Section(header: Text("Entry Details")) {
            entryTypePicker
            
            if entryType == "task" {
                taskControls
            }
            
            contentField
            tagsField
            
            if !collections.isEmpty {
                collectionPicker
            }
        }
    }
    
    private var entryTypePicker: some View {
        Picker("Type", selection: $entryType) {
            Text("Task").tag("task")
            Text("Event").tag("event")
            Text("Note").tag("note")
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
        TextField("Content", text: $content)
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
        
        dismiss()
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
