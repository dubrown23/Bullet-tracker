import SwiftUI
import CoreData

struct CollectionsView: View {
    @State private var collections: [Collection] = []
    @State private var newCollectionName = ""
    @State private var showingAddAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                if collections.isEmpty {
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
                        
                        Button(action: {
                            createDefaultCollections()
                            loadCollections()
                        }) {
                            Text("Create Default Collections")
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(10)
                        }
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    .padding()
                } else {
                    List {
                        Section(header: Text("Your Collections")) {
                            ForEach(collections) { collection in
                                NavigationLink(destination: Text(collection.name ?? "Unnamed Collection")) {
                                    HStack {
                                        Image(systemName: "folder.fill")
                                            .foregroundColor(.blue)
                                        Text(collection.name ?? "Unnamed Collection")
                                    }
                                }
                            }
                            .onDelete(perform: deleteCollections)
                        }
                    }
                }
            }
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
            .onAppear {
                loadCollections()
            }
            .alert("Create New Collection", isPresented: $showingAddAlert) {
                TextField("Collection Name", text: $newCollectionName)
                Button("Cancel", role: .cancel) {
                    newCollectionName = ""
                }
                Button("Create") {
                    if !newCollectionName.isEmpty {
                        createCollection(name: newCollectionName)
                        newCollectionName = ""
                        loadCollections()
                    }
                }
            } message: {
                Text("Enter a name for your new collection")
            }
        }
    }
    
    private func loadCollections() {
        print("Loading collections...")
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            collections = try context.fetch(fetchRequest)
            print("Loaded \(collections.count) collections")
        } catch {
            print("Error loading collections: \(error)")
            collections = []
        }
    }
    
    private func createCollection(name: String) {
        print("Creating collection: \(name)")
        let context = CoreDataManager.shared.container.viewContext
        let collection = Collection(context: context)
        collection.id = UUID()
        collection.name = name
        
        do {
            try context.save()
            print("Collection created successfully")
        } catch {
            print("Error creating collection: \(error)")
        }
    }
    
    private func createDefaultCollections() {
        let defaultNames = ["Daily Log", "Monthly Log", "Future Log", "Ideas", "Projects"]
        
        for name in defaultNames {
            createCollection(name: name)
        }
    }
    
    private func deleteCollections(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            context.delete(collections[index])
        }
        
        do {
            try context.save()
            print("Collections deleted")
            loadCollections()
        } catch {
            print("Error deleting collections: \(error)")
        }
    }
}
