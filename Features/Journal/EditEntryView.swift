//
//  EditEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct EditEntryView: View {
    // MARK: - Environment Properties
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    @ObservedObject var entry: JournalEntry
    
    // MARK: - State Properties
    
    @State private var content: String = ""
    @State private var entryType: String = "task"
    @State private var taskStatus: String = "pending"
    @State private var selectedCollection: Collection?
    @State private var tagsText: String = ""
    @State private var priority: Bool = false
    @State private var collections: [Collection] = []
    @State private var showingDeleteAlert = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Entry Details")) {
                    Picker("Type", selection: $entryType) {
                        Text("Task").tag("task")
                        Text("Event").tag("event")
                        Text("Note").tag("note")
                    }
                    .pickerStyle(.segmented)
                    
                    if entryType == "task" {
                        Picker("Status", selection: $taskStatus) {
                            Text("Pending").tag("pending")
                            Text("Completed").tag("completed")
                            Text("Migrated").tag("migrated")
                            Text("Scheduled").tag("scheduled")
                        }
                        
                        Toggle("Priority", isOn: $priority)
                    }
                    
                    TextField("Content", text: $content)
                    
                    TextField("Tags (comma separated)", text: $tagsText)
                    
                    Picker("Collection", selection: $selectedCollection) {
                        Text("None").tag(nil as Collection?)
                        ForEach(collections, id: \.self) { collection in
                            Text(collection.name ?? "").tag(collection as Collection?)
                        }
                    }
                }
                
                Section {
                    Button("Delete Entry", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateEntry()
                    }
                    .disabled(content.isEmpty)
                }
            }
            .onAppear {
                loadCollections()
                loadEntryData()
            }
            .alert("Delete Entry", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    CoreDataManager.shared.deleteJournalEntry(entry)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this entry? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCollections() {
        collections = CoreDataManager.shared.fetchAllCollections()
    }
    
    private func loadEntryData() {
        content = entry.content ?? ""
        entryType = entry.entryType ?? "task"
        taskStatus = entry.taskStatus ?? "pending"
        selectedCollection = entry.collection
        priority = entry.priority
        
        // Convert tags to comma-separated string
        if let tags = entry.tags as? Set<Tag> {
            tagsText = tags.compactMap { $0.name }.joined(separator: ", ")
        }
    }
    
    private func updateEntry() {
        // Process tags
        let tagNames = tagsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        var tags: [Tag] = []
        
        for name in tagNames where !name.isEmpty {
            let tag = CoreDataManager.shared.getOrCreateTag(name: name)
            tags.append(tag)
        }
        
        // Update journal entry
        CoreDataManager.shared.updateJournalEntry(
            entry,
            content: content,
            entryType: entryType,
            taskStatus: entryType == "task" ? taskStatus : nil,
            priority: priority,
            collection: selectedCollection,
            tags: tags
        )
        
        dismiss()
    }
}
