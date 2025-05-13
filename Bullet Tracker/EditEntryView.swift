//
//  EditEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

struct EditEntryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var entry: JournalEntry
    
    @State private var content: String = ""
    @State private var type: EntryType = .task
    @State private var taskStatus: TaskStatus = .pending
    @State private var selectedCollection: Collection?
    @State private var tagsText: String = ""
    @State private var priority: Bool = false
    @State private var collections: [Collection] = []
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Entry Details")) {
                    Picker("Type", selection: $type) {
                        ForEach(EntryType.allCases) { type in
                            HStack {
                                Text(type.symbol)
                                Text(type.rawValue.capitalized)
                            }.tag(type)
                        }
                    }
                    
                    if type == .task {
                        Picker("Status", selection: $taskStatus) {
                            ForEach(TaskStatus.allCases) { status in
                                HStack {
                                    Text(status.symbol)
                                    Text(status.rawValue.capitalized)
                                }.tag(status)
                            }
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
                        presentationMode.wrappedValue.dismiss()
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
                    presentationMode.wrappedValue.dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this entry? This action cannot be undone.")
            }
        }
    }
    
    private func loadCollections() {
        collections = CoreDataManager.shared.fetchAllCollections()
    }
    
    private func loadEntryData() {
        content = entry.content ?? ""
        
        if let entryType = entry.entryType, let type = EntryType(rawValue: entryType) {
            self.type = type
        }
        
        if let status = entry.taskStatus, let taskStatus = TaskStatus(rawValue: status) {
            self.taskStatus = taskStatus
        }
        
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
            entryType: type.rawValue,
            taskStatus: type == .task ? taskStatus.rawValue : nil,
            priority: priority,
            collection: selectedCollection,
            tags: tags
        )
        
        presentationMode.wrappedValue.dismiss()
    }
}