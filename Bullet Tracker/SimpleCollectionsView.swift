//
//  SimpleCollectionsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI
import CoreData

struct SimpleCollectionsView: View {
    @State private var collections: [Collection] = []
    @State private var showingAddAlert = false
    @State private var newCollectionName = ""
    @State private var showingDeleteAlert = false
    @State private var collectionToDelete: Collection?
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Special Collections")) {
                    NavigationLink(destination: HabitTrackerView()) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                                .frame(width: 32, height: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Habit Tracker")
                                    .font(.headline)
                                
                                Text("Track your daily habits")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Your Collections")) {
                    ForEach(collections) { collection in
                        NavigationLink(destination: CollectionDetailView(collection: collection)) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                    .frame(width: 32, height: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(collection.name ?? "Unnamed Collection")
                                        .font(.headline)
                                    
                                    // Show entry count
                                    Text(getEntryCountText(for: collection))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button(role: .destructive) {
                                    collectionToDelete = collection
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteCollections)
                    
                    // Add collection button within the list
                    Button(action: {
                        showingAddAlert = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Collection")
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if collections.isEmpty {
                    Section {
                        Button("Create Default Collections") {
                            createDefaultCollections()
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.vertical)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddAlert = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Collection", isPresented: $showingAddAlert) {
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
            } message: {
                Text("Enter a name for your new collection")
            }
            .alert("Delete Collection", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let collection = collectionToDelete {
                        deleteCollection(collection)
                    }
                }
            } message: {
                if let collection = collectionToDelete {
                    Text("Are you sure you want to delete '\(collection.name ?? "this collection")'? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete this collection? This action cannot be undone.")
                }
            }
            .onAppear {
                loadCollections()
            }
        }
    }
    
    private func loadCollections() {
        print("Loading collections...")
        let context = CoreDataManager.shared.container.viewContext
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            collections = try context.fetch(request)
            print("Found \(collections.count) collections")
        } catch {
            print("Failed to fetch collections: \(error)")
        }
    }
    
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
            print("Failed to save collection: \(error)")
        }
    }
    
    private func deleteCollection(_ collection: Collection) {
        let context = CoreDataManager.shared.container.viewContext
        context.delete(collection)
        
        do {
            try context.save()
            loadCollections()
        } catch {
            print("Failed to delete collection: \(error)")
        }
    }
    
    private func deleteCollections(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            context.delete(collections[index])
        }
        
        do {
            try context.save()
            loadCollections()
        } catch {
            print("Error deleting collections: \(error)")
        }
    }
    
    private func createDefaultCollections() {
        let defaultNames = ["Daily Log", "Monthly Log", "Future Log", "Projects", "Ideas"]
        
        for name in defaultNames {
            addCollection(name: name)
        }
    }
    
    private func getEntryCountText(for collection: Collection) -> String {
        let entries = collection.entries?.count ?? 0
        
        if entries == 0 {
            return "No entries"
        } else if entries == 1 {
            return "1 entry"
        } else {
            return "\(entries) entries"
        }
    }
}
