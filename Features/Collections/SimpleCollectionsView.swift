//
//  SimpleCollectionsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct SimpleCollectionsView: View {
    // MARK: - State Properties
    
    @State private var automaticCollections: [Collection] = []
    @State private var userCollections: [Collection] = []
    @State private var showingAddAlert = false
    @State private var newCollectionName = ""
    @State private var showingDeleteAlert = false
    @State private var collectionToDelete: Collection?
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                // Index section - always at top
                indexSection
                
                // Future Log section - below Index
                futureLogSection
                
                // Auto-generated logs (Year/Month) - filtered to exclude Future Log
                if !filteredAutomaticCollections.isEmpty {
                    automaticCollectionsSection
                }
                
                // User collections
                if !userCollections.isEmpty {
                    userCollectionsSection
                }
                
                // Empty state only if no user collections (automatic ones always exist)
                if userCollections.isEmpty && filteredAutomaticCollections.isEmpty {
                    emptyStateSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Collections")
            .toolbar {
                toolbarContent
            }
            .alert("New Collection", isPresented: $showingAddAlert) {
                newCollectionAlert
            } message: {
                Text("Enter a name for your new collection")
            }
            .alert("Delete Collection", isPresented: $showingDeleteAlert) {
                deleteCollectionAlert
            } message: {
                deleteAlertMessage
            }
            .onAppear {
                loadCollections()
            }
        }
    }
    
    // MARK: - View Components
    
    private var indexSection: some View {
        Section {
            NavigationLink(destination: IndexView()) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(.blue)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Index")
                            .font(.headline)
                        
                        Text("Search and browse all entries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var futureLogSection: some View {
        Section {
            NavigationLink(destination: FutureLogView()) {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(.blue)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Future Log")
                            .font(.headline)
                        
                        Text("Schedule tasks and events for future months")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var automaticCollectionsSection: some View {
        Section(header: Text("Logs")) {
            ForEach(filteredAutomaticCollections) { collection in
                NavigationLink(destination: destinationView(for: collection)) {
                    collectionRow(for: collection)
                }
            }
        }
    }
    
    private var userCollectionsSection: some View {
        Section(header: Text("Your Collections")) {
            ForEach(userCollections) { collection in
                NavigationLink(destination: CollectionDetailView(collection: collection)) {
                    collectionRow(for: collection)
                        .contextMenu {
                            deleteContextMenu(for: collection)
                        }
                }
            }
            .onDelete(perform: deleteUserCollections)
        }
    }
    
    private func collectionRow(for collection: Collection) -> some View {
        HStack {
            Image(systemName: iconForCollection(collection))
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name ?? "Unnamed Collection")
                    .font(.headline)
                
                Text(getEntryCountText(for: collection))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func iconForCollection(_ collection: Collection) -> String {
        switch collection.collectionType {
        case "future":
            return "calendar.badge.clock"
        case "year":
            return "calendar"
        case "month":
            return "calendar.day.timeline.left"
        case "monthly":
            return "calendar.day.timeline.left"
        default:
            return "folder.fill"
        }
    }
    
    @ViewBuilder
    private func destinationView(for collection: Collection) -> some View {
        // Check collection type
        switch collection.collectionType {
        case "monthly":
            // For the single Monthly Log, use the container that handles navigation
            MonthlyLogContainerView()
            
        case "month":
            // Handle old month collections for backward compatibility
            if let name = collection.name {
                let components = name.split(separator: " ")
                if let yearMonth = components.first {
                    let parts = yearMonth.split(separator: "-")
                    if parts.count == 2,
                       let year = Int(parts[0]),
                       let month = Int(parts[1]) {
                        MonthLogView(year: year, month: month)
                    } else {
                        CollectionDetailView(collection: collection)
                    }
                } else {
                    CollectionDetailView(collection: collection)
                }
            } else {
                CollectionDetailView(collection: collection)
            }
            
        default:
            // For all other collections (year, user collections), use the standard view
            CollectionDetailView(collection: collection)
        }
    }
    
    private func deleteContextMenu(for collection: Collection) -> some View {
        Button(role: .destructive) {
            collectionToDelete = collection
            showingDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Text("No collections yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Text("Create a collection to organize your journal entries")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Computed Properties
    
    /// Filters out the Future Log from automatic collections to avoid duplication
    private var filteredAutomaticCollections: [Collection] {
        automaticCollections.filter { $0.collectionType != "future" }
    }
    
    // MARK: - Toolbar Components
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingAddAlert = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    
    // MARK: - Alert Components
    
    private var newCollectionAlert: some View {
        Group {
            TextField("Collection Name", text: $newCollectionName)
            Button("Cancel", role: .cancel) {
                newCollectionName = ""
            }
            Button("Create") {
                if !newCollectionName.isEmpty {
                    addCollection(name: newCollectionName)
                    newCollectionName = ""
                }
            }
        }
    }
    
    private var deleteCollectionAlert: some View {
        Group {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let collection = collectionToDelete {
                    deleteCollection(collection)
                }
            }
        }
    }
    
    private var deleteAlertMessage: Text {
        if let collection = collectionToDelete {
            Text("Are you sure you want to delete '\(collection.name ?? "this collection")'? This action cannot be undone.")
        } else {
            Text("Are you sure you want to delete this collection? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Loads all collections from Core Data
    private func loadCollections() {
        #if DEBUG
        print("Loading collections...")
        #endif
        
        let collections = CoreDataManager.shared.fetchAllCollectionsSorted()
        
        // Separate automatic and user collections
        automaticCollections = collections.filter { $0.isAutomatic }
        userCollections = collections.filter { !$0.isAutomatic }
        
        #if DEBUG
        print("Found \(automaticCollections.count) automatic collections and \(userCollections.count) user collections")
        #endif
    }
    
    /// Adds a new collection with the specified name
    private func addCollection(name: String) {
        guard !name.isEmpty else { return }
        
        _ = CoreDataManager.shared.createCollection(name: name)
        loadCollections()
    }
    
    /// Deletes the specified collection
    private func deleteCollection(_ collection: Collection) {
        // Don't delete automatic collections
        guard !collection.isAutomatic else { return }
        
        CoreDataManager.shared.deleteCollection(collection)
        loadCollections()
    }
    
    /// Deletes user collections at the specified offsets
    private func deleteUserCollections(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            let collection = userCollections[index]
            // Don't delete automatic collections
            guard !collection.isAutomatic else { continue }
            context.delete(collection)
        }
        
        do {
            try context.save()
            loadCollections()
        } catch {
            #if DEBUG
            print("Error deleting collections: \(error)")
            #endif
        }
    }
    
    /// Returns a formatted string describing the number of entries in a collection
    private func getEntryCountText(for collection: Collection) -> String {
        let entryCount = collection.entries?.count ?? 0
        
        switch entryCount {
        case 0:
            return "No entries"
        case 1:
            return "1 entry"
        default:
            return "\(entryCount) entries"
        }
    }
}
