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
    
    @State private var collections: [Collection] = []
    @State private var showingAddAlert = false
    @State private var newCollectionName = ""
    @State private var showingDeleteAlert = false
    @State private var collectionToDelete: Collection?
    
    // MARK: - Constants
    
    private let defaultCollectionNames = ["Daily Log", "Monthly Log", "Future Log", "Projects", "Ideas"]
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            List {
                specialCollectionsSection
                userCollectionsSection
                
                if collections.isEmpty {
                    defaultCollectionsSection
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
    
    private var specialCollectionsSection: some View {
        Section(header: Text("Special Collections")) {
            NavigationLink(destination: IndexView()) {
                indexRow
            }
        }
    }
    
    private var indexRow: some View {
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
    
    private var userCollectionsSection: some View {
        Section(header: Text("Your Collections")) {
            ForEach(collections) { collection in
                NavigationLink(destination: CollectionDetailView(collection: collection)) {
                    collectionRow(for: collection)
                        .contextMenu {
                            deleteContextMenu(for: collection)
                        }
                }
            }
            .onDelete(perform: deleteCollections)
        }
    }
    
    private func collectionRow(for collection: Collection) -> some View {
        HStack {
            Image(systemName: "folder.fill")
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
    
    private func deleteContextMenu(for collection: Collection) -> some View {
        Button(role: .destructive) {
            collectionToDelete = collection
            showingDeleteAlert = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private var defaultCollectionsSection: some View {
        Section {
            Button {
                createDefaultCollections()
            } label: {
                Text("Create Default Collections")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
            .padding(.vertical)
        }
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
        
        let context = CoreDataManager.shared.container.viewContext
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            collections = try context.fetch(request)
            #if DEBUG
            print("Found \(collections.count) collections")
            #endif
        } catch {
            #if DEBUG
            print("Failed to fetch collections: \(error)")
            #endif
        }
    }
    
    /// Adds a new collection with the specified name
    private func addCollection(name: String) {
        guard !name.isEmpty else { return }
        
        let context = CoreDataManager.shared.container.viewContext
        let newCollection = Collection(context: context)
        newCollection.id = UUID()
        newCollection.name = name
        
        do {
            try context.save()
            loadCollections()
        } catch {
            #if DEBUG
            print("Failed to save collection: \(error)")
            #endif
        }
    }
    
    /// Deletes the specified collection
    private func deleteCollection(_ collection: Collection) {
        let context = CoreDataManager.shared.container.viewContext
        context.delete(collection)
        
        do {
            try context.save()
            loadCollections()
        } catch {
            #if DEBUG
            print("Failed to delete collection: \(error)")
            #endif
        }
    }
    
    /// Deletes collections at the specified offsets
    private func deleteCollections(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            context.delete(collections[index])
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
    
    /// Creates default collections for new users
    private func createDefaultCollections() {
        for name in defaultCollectionNames {
            addCollection(name: name)
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
