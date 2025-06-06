
/*
 //
//  SimplestEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct SimplestEntryView: View {
    // MARK: - Properties
    
    let date: Date
    
    // MARK: - Environment Properties
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    @State private var content: String = ""
    
    // MARK: - Computed Properties
    
    /// Determines if the save button should be disabled
    private var isSaveDisabled: Bool {
        content.isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                entrySection
            }
            .navigationTitle("Quick Note")
            .toolbar {
                toolbarContent
            }
        }
    }
    
    // MARK: - View Components
    
    private var entrySection: some View {
        Section(header: Text("Simple Entry")) {
            TextField("Content", text: $content)
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
                saveBasicEntry()
            }
            .disabled(isSaveDisabled)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Saves a basic journal entry to Core Data
    private func saveBasicEntry() {
        let entry = JournalEntry(context: viewContext)
        entry.id = UUID()
        entry.content = content
        entry.date = date
        entry.entryType = "note"
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            #if DEBUG
            print("Error saving entry: \(error)")
            #endif
        }
    }
}
*/
