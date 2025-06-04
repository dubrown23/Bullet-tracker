//
//  TempEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

/// A simplified entry view for temporary use
struct TempEntryView: View {
    // MARK: - Properties
    
    let date: Date
    
    // MARK: - Environment Properties
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State Properties
    
    @State private var content: String = ""
    @State private var entryType: String = "task"
    
    // MARK: - Computed Properties
    
    /// Determines if the save button should be disabled
    private var isSaveDisabled: Bool {
        content.isEmpty
    }
    
    /// Default task status based on entry type
    private var defaultTaskStatus: String? {
        entryType == "task" ? "pending" : nil
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
        }
    }
    
    // MARK: - View Components
    
    private var entryDetailsSection: some View {
        Section(header: Text("Entry Details")) {
            entryTypePicker
            contentField
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
    
    private var contentField: some View {
        TextField("Content", text: $content)
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
    
    /// Saves the entry using CoreDataManager
    private func saveEntry() {
        _ = CoreDataManager.shared.createJournalEntry(
            content: content,
            entryType: entryType,
            taskStatus: defaultTaskStatus,
            date: date,
            priority: false
        )
        
        dismiss()
    }
}
