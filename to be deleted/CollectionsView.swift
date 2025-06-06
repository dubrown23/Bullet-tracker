/*
 //
//  CollectionsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct CollectionsView: View {
    // MARK: - State Properties
    
    @State private var collections: [Collection] = []
    @State private var newCollectionName = ""
    @State private var showingAddAlert = false
    
    // MARK: - Constants
    
    /// Default collection names for quick setup
    private let defaultCollectionNames = ["Daily Log", "Monthly Log", "Future Log", "Ideas", "Projects"]
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack {
                if collections.isEmpty {
                    emptyStateView
                } else {
                    collectionsList
                }
            }
            .navigationTitle("Collections")
            .toolbar {
                toolbarContent
            }
            .onAppear(perform: loadCollections)
            .alert("Create New Collection", isPresented: $showingAddAlert) {
                createCollectionAlert
            } message: {
                Text("Enter a name for your new collection")
            }
        }
    }
    
    // MARK: - View Components
    
    /// Empty state view shown when no collections exist
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "folder")
                .font(.system(size: 70))
                .foregroundColor(.blue)
            
            Text("No Collections Found")
                .font(.title2)
            
            Text("Create your first collection to organize your journal entries.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            createCollectionButton
            createDefaultCollectionsButton
            
            Spacer()
        }
        .padding()
    }
    
    /// Button to create a new collection
    private var createCollectionButton: some View {
        Button(action: {
            showingAddAlert = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Create Collection")
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.top)
    }
    
    /// Button to create default collections
    private var createDefaultCollectionsButton: some View {
        Button(action: {
            createDefaultCollections()
        }) {
            Text("Create Default Collections")
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(10)
        }
        .padding(.top, 10)
    }
    
    /// List view of existing collections
    private var collectionsList: some View {
        List {
            Section(header: Text("Your Collections")) {
                ForEach(collections) { collection in
                    NavigationLink(destination: collectionDetailDestination(for: collection)) {
                        collectionRow(for: collection)
                    }
                }
                .onDelete(perform: deleteCollections)
            }
        }
    }
    
    /// Creates a row view for a collection
    private func collectionRow(for collection: Collection) -> some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
            Text(collection.name ?? "Unnamed Collection")
        }
    }
    
    /// Creates the destination view for a collection
    private func collectionDetailDestination(for collection: Collection) -> some View {
        // TODO: Replace with actual CollectionDetailView when implemented
        Text(collection.name ?? "Unnamed Collection")
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: {
                showingAddAlert = true
            }) {
                Image(systemName: "plus")
            }
        }
    }
    
    // MARK: - Alert Content
    
    /// Alert content for creating a new collection
    private var createCollectionAlert: some View {
        Group {
            TextField("Collection Name", text: $newCollectionName)
            
            Button("Cancel", role: .cancel) {
                newCollectionName = ""
            }
            
            Button("Create") {
                if !newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    createCollection(name: newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines))
                    newCollectionName = ""
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Loads all collections from Core Data
    private func loadCollections() {
        #if DEBUG
        print("📁 Loading collections...")
        #endif
        
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            collections = try context.fetch(fetchRequest)
            #if DEBUG
            print("✅ Loaded \(collections.count) collections")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error loading collections: \(error)")
            #endif
            collections = []
        }
    }
    
    /// Creates a new collection with the given name
    private func createCollection(name: String) {
        #if DEBUG
        print("➕ Creating collection: \(name)")
        #endif
        
        let context = CoreDataManager.shared.container.viewContext
        let collection = Collection(context: context)
        collection.id = UUID()
        collection.name = name
        
        do {
            try context.save()
            loadCollections()
            #if DEBUG
            print("✅ Collection created successfully")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error creating collection: \(error)")
            #endif
        }
    }
    
    /// Creates the default set of collections
    private func createDefaultCollections() {
        for name in defaultCollectionNames {
            createCollection(name: name)
        }
    }
    
    /// Deletes collections at the specified indices
    private func deleteCollections(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            context.delete(collections[index])
        }
        
        do {
            try context.save()
            loadCollections()
            #if DEBUG
            print("🗑️ Collections deleted")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error deleting collections: \(error)")
            #endif
        }
    }
}
*/
