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
    
    @ObservedObject var collection: Collection
    
    // MARK: - State Properties
    
    @State private var showingAddEntrySheet = false
    
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Constants
    
    private enum Layout {
        static let emptyStateImageSize: CGFloat = 70
        static let verticalSpacing: CGFloat = 20
        static let buttonCornerRadius: CGFloat = 10
    }
    
    // MARK: - Computed Properties
    
    private var sortedEntries: [JournalEntry] {
        guard let collectionEntries = collection.entries as? Set<JournalEntry> else {
            return []
        }
        
        return collectionEntries.sorted { ($0.date ?? Date()) > ($1.date ?? Date()) }
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack {
            if sortedEntries.isEmpty {
                emptyStateView
            } else {
                entriesList
            }
        }
        .navigationTitle(collection.name ?? "Collection")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddEntrySheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddEntrySheet) {
            NewEntryView(date: Date())
        }
    }
    
    // MARK: - View Components
    
    private var emptyStateView: some View {
        VStack(spacing: Layout.verticalSpacing) {
            Spacer()
            
            Image(systemName: "doc.text")
                .font(.system(size: Layout.emptyStateImageSize))
                .foregroundColor(.blue)
            
            Text("No Entries")
                .font(.title2)
            
            Text("Add entries to this collection using the + button")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: { showingAddEntrySheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Entry")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(Layout.buttonCornerRadius)
            }
            .padding(.top)
            
            Spacer()
        }
        .padding()
    }
    
    private var entriesList: some View {
        List {
            ForEach(sortedEntries) { entry in
                EntryListItem(entry: entry)
            }
            .onDelete(perform: deleteEntries)
        }
    }
    
    // MARK: - Helper Methods
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            viewContext.delete(sortedEntries[index])
        }
        
        do {
            try viewContext.save()
        } catch {
            // Handle error silently in production
        }
    }
}
