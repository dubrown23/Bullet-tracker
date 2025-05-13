//
//  SimplestEntryView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

struct SimplestEntryView: View {
    let date: Date
    
    @State private var content: String = ""
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Simple Entry")) {
                    TextField("Content", text: $content)
                }
            }
            .navigationTitle("Quick Note")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveBasicEntry()
                    }
                    .disabled(content.isEmpty)
                }
            }
        }
    }
    
    private func saveBasicEntry() {
        // Create the entry directly without using CoreDataManager
        let entry = JournalEntry(context: viewContext)
        entry.id = UUID()
        entry.content = content
        entry.date = date
        entry.entryType = "note" // Simplest type
        
        // Save the context
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving entry: \(error)")
        }
    }
}