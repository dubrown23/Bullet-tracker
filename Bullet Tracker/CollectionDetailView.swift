//
//  CollectionDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct CollectionDetailView: View {
    // MARK: - Properties
    
    /// The collection being displayed
    @ObservedObject var collection: Collection
    
    // MARK: - State Properties
    
    @State private var entries: [JournalEntry] = []
    @State private var showingAddEntrySheet = false
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            if entries.isEmpty {
                emptyStateView
            } else {
                entriesList
            }
        }
        .navigationTitle(collection.name ?? "Collection")
        .toolbar {
            toolbarContent
        }
        .onAppear(perform: loadEntries)
        .sheet(isPresented: $showingAddEntrySheet, onDismiss: loadEntries) {
            NewEntryView(date: Date())
        }
    }
    
    // MARK: - View Components
    
    /// Empty state shown when no entries exist
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("No Entries")
                .font(.title2)
            
            Text("Add entries to this collection using the + button")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            addEntryButton
            
            Spacer()
        }
        .padding()
    }
    
    /// Button to add a new entry from empty state
    private var addEntryButton: some View {
        Button(action: {
            showingAddEntrySheet = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Entry")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.top)
    }
    
    /// List of journal entries
    private var entriesList: some View {
        List {
            ForEach(entries) { entry in
                EntryListItem(entry: entry)
            }
            .onDelete(perform: deleteEntries)
        }
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                showingAddEntrySheet = true
            }) {
                Image(systemName: "plus")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Loads entries from the collection and sorts them by date
    private func loadEntries() {
        guard let collectionEntries = collection.entries as? Set<JournalEntry> else {
            entries = []
            return
        }
        
        // Convert to array and sort by date (newest first)
        entries = Array(collectionEntries).sorted { entry1, entry2 in
            (entry1.date ?? Date()) > (entry2.date ?? Date())
        }
    }
    
    /// Deletes entries at the specified indices
    private func deleteEntries(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            context.delete(entries[index])
        }
        
        do {
            try context.save()
            loadEntries()
        } catch {
            #if DEBUG
            print("❌ Error deleting entries: \(error)")
            #endif
        }
    }
}
