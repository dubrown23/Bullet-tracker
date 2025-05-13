//
//  TempEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

// A simplified version to use temporarily
struct TempEntryView: View {
    let date: Date
    
    @State private var content: String = ""
    @State private var entryType: String = "task"
    @Environment(\.presentationMode) var presentationMode
    
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
                    
                    TextField("Content", text: $content)
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
        }
    }
    
    private func saveEntry() {
        // Use CoreDataManager to create the entry
        _ = CoreDataManager.shared.createJournalEntry(
            content: content,
            entryType: entryType,
            taskStatus: entryType == "task" ? "pending" : nil,
            date: date,
            priority: false
        )
        
        presentationMode.wrappedValue.dismiss()
    }
}