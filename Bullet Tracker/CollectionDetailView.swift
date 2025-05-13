//
//  CollectionDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI
import CoreData

struct CollectionDetailView: View {
    @ObservedObject var collection: Collection
    @State private var entries: [JournalEntry] = []
    @State private var showingAddEntrySheet = false
    
    var body: some View {
        VStack {
            if entries.isEmpty {
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
                    
                    Spacer()
                }
                .padding()
            } else {
                List {
                    ForEach(entries) { entry in
                        EntryListItem(entry: entry)
                    }
                    .onDelete(perform: deleteEntries)
                }
            }
        }
        .navigationTitle(collection.name ?? "Collection")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddEntrySheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear {
            loadEntries()
        }
        .sheet(isPresented: $showingAddEntrySheet, onDismiss: {
            loadEntries()
        }) {
            NewEntryView(date: Date())
        }
    }
    
    private func loadEntries() {
        // Get entries for this collection
        if let collectionEntries = collection.entries as? Set<JournalEntry> {
            // Convert to array and sort by date
            entries = Array(collectionEntries).sorted(by: {
                ($0.date ?? Date()) > ($1.date ?? Date())
            })
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            context.delete(entries[index])
        }
        
        do {
            try context.save()
            loadEntries()
        } catch {
            print("Error deleting entries: \(error)")
        }
    }
}
