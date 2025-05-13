//
//  NewEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI
import CoreData

struct NewEntryView: View {
    let date: Date
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var content: String = ""
    @State private var entryType: String = "task"
    @State private var taskStatus: String = "pending"
    @State private var priority: Bool = false
    @State private var tagsText: String = ""
    @State private var selectedCollection: Collection?
    @State private var collections: [Collection] = []
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Entry Details")) {
                    Picker("Type", selection: $entryType) {
                        Text("Task").tag("task")
                        Text("Event").tag("event")
                        Text("Note").tag("note")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
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
                    
                    if !collections.isEmpty {
                        Picker("Collection", selection: $selectedCollection) {
                            Text("None").tag(nil as Collection?)
                            ForEach(collections, id: \.self) { collection in
                                Text(collection.name ?? "").tag(collection as Collection?)
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(content.isEmpty)
                }
            }
            .onAppear {
                loadCollections()
            }
        }
    }
    
    private func loadCollections() {
        // Use CoreDataManager to fetch collections
        collections = CoreDataManager.shared.fetchAllCollections()
    }
    
    private func saveEntry() {
        // Get context from CoreDataManager
        let context = CoreDataManager.shared.container.viewContext
        
        // Create a new entry
        let entry = JournalEntry(context: context)
        entry.id = UUID()
        entry.content = content
        entry.date = date
        entry.entryType = entryType
        entry.priority = priority
        
        // Only set taskStatus if it's a task
        if entryType == "task" {
            entry.taskStatus = taskStatus
        }
        
        // Set collection if selected
        entry.collection = selectedCollection
        
        // Process tags if any
        if !tagsText.isEmpty {
            let tagNames = tagsText.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
            
            for tagName in tagNames where !tagName.isEmpty {
                // Check if tag already exists
                let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", tagName)
                fetchRequest.fetchLimit = 1
                
                var tag: Tag
                
                do {
                    let results = try context.fetch(fetchRequest)
                    if let existingTag = results.first {
                        tag = existingTag
                    } else {
                        // Create new tag
                        tag = Tag(context: context)
                        tag.id = UUID()
                        tag.name = tagName
                    }
                    
                    // Add tag to entry
                    entry.addToTags(tag)
                } catch {
                    print("Error processing tag: \(error)")
                }
            }
        }
        
        // Save context
        do {
            try context.save()
            print("Entry saved successfully")
        } catch {
            print("Error saving entry: \(error)")
        }
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
}
