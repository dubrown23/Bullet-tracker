//
//  SimpleCollectionsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
@preconcurrency import CoreData

struct SimpleCollectionsView: View {
    // MARK: - State Properties
    
    @State private var automaticCollections: [Collection] = []
    @State private var userCollections: [Collection] = []
    @State private var showingAddAlert = false
    @State private var newCollectionName = ""
    @State private var showingDeleteAlert = false
    @State private var collectionToDelete: Collection?
    @State private var collectionCounts: [UUID: Int] = [:]
    @State private var isLoadingCounts = false
    @State private var preloadedData: [UUID: [JournalEntry]] = [:]
    @State private var isPreloading = false
    @State private var searchText = ""
    
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
                if !filteredUserCollections.isEmpty {
                    userCollectionsSection
                }
                
                // Empty state only if no user collections (automatic ones always exist)
                if filteredUserCollections.isEmpty && filteredAutomaticCollections.isEmpty && searchText.isEmpty {
                    emptyStateSection
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search collections...")
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAlert = true
                    } label: {
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
    
    // MARK: - View Components
    
    private var indexSection: some View {
        Section {
            NavigationLink(destination: IndexView()) {
                specialCollectionRow(
                    icon: "doc.text.magnifyingglass",
                    title: "Index",
                    subtitle: "Search and browse all entries"
                )
            }
        }
    }
    
    private var futureLogSection: some View {
        Section {
            NavigationLink(destination: FutureLogView()) {
                specialCollectionRow(
                    icon: "calendar.badge.plus",
                    title: "Future Log",
                    subtitle: "Schedule tasks and events for future months"
                )
            }
        }
    }
    
    private var automaticCollectionsSection: some View {
        Section(header: Text("Logs")) {
            ForEach(filteredAutomaticCollections) { collection in
                NavigationLink(destination: destinationView(for: collection)) {
                    collectionRow(for: collection)
                        .onAppear {
                            preloadDestinationData(for: collection)
                        }
                }
            }
        }
    }
    
    private var userCollectionsSection: some View {
        Section(header: Text("Your Collections")) {
            ForEach(filteredUserCollections) { collection in
                NavigationLink(destination: CollectionDetailView(collection: collection)) {
                    collectionRow(for: collection)
                        .onAppear {
                            preloadDestinationData(for: collection)
                        }
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
            .onDelete(perform: deleteUserCollections)
        }
    }
    
    private func specialCollectionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 32, height: 32)
                .accessibilityLabel(title)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
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
                
                if isLoadingCounts {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(getEntryCountText(for: collection))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
        case "month", "monthly":
            return "calendar.day.timeline.left"
        default:
            return "folder.fill"
        }
    }
    
    @ViewBuilder
    private func destinationView(for collection: Collection) -> some View {
        switch collection.collectionType {
        case "monthly":
            MonthlyLogContainerView()
            
        case "year":
            YearLogView(yearCollection: collection)
                .onAppear {
                    // Pass preloaded data to the view if available
                    if let collectionID = collection.id,
                       let _ = preloadedData[collectionID] {
                        // The view can use this data instead of fetching again
                    }
                }
            
        case "month":
            // Handle legacy month collections
            if let name = collection.name,
               let (year, month) = parseMonthCollectionName(name) {
                MonthLogView(year: year, month: month)
            } else {
                CollectionDetailView(collection: collection)
                    .onAppear {
                        // Pass preloaded data to the view if available
                        if let collectionID = collection.id,
                           let _ = preloadedData[collectionID] {
                            // Use preloaded data if available
                        }
                    }
            }
            
        default:
            CollectionDetailView(collection: collection)
                .onAppear {
                    // Pass preloaded data to the view if available
                    if let collectionID = collection.id,
                       let _ = preloadedData[collectionID] {
                        // Use preloaded data if available
                    }
                }
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
    
    /// Filters out the Future Log and month archives from automatic collections
    private var filteredAutomaticCollections: [Collection] {
        let baseFiltered = automaticCollections.filter { collection in
            collection.collectionType != "future" &&
            !(collection.name?.contains("/") ?? false)
        }
        
        if searchText.isEmpty {
            return baseFiltered
        } else {
            return baseFiltered.filter { 
                $0.name?.localizedCaseInsensitiveContains(searchText) ?? false 
            }
        }
    }
    
    private var filteredUserCollections: [Collection] {
        if searchText.isEmpty {
            return userCollections
        } else {
            return userCollections.filter { 
                $0.name?.localizedCaseInsensitiveContains(searchText) ?? false 
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Loads all collections from Core Data
    private func loadCollections() {
        let collections = CoreDataManager.shared.fetchAllCollectionsSorted()
        
        // Separate automatic and user collections using filter
        automaticCollections = collections.filter { $0.isAutomatic }
        userCollections = collections.filter { !$0.isAutomatic }
        
        // Load counts asynchronously
        loadCollectionCounts()
        
        // Start preloading destination data for visible collections
        preloadVisibleCollections()
    }
    
    /// Preloads data for destination views of visible collections
    private func preloadVisibleCollections() {
        guard !isPreloading else { return }
        isPreloading = true
        
        Task {
            // Preload data for the first few collections that are likely to be tapped
            let collectionsToPreload = Array(filteredAutomaticCollections.prefix(3)) + Array(userCollections.prefix(3))
            
            for collection in collectionsToPreload {
                guard let collectionID = collection.id else { continue }
                let objectID = collection.objectID
                await preloadDestinationDataAsync(objectID: objectID, collectionID: collectionID)
            }
            
            isPreloading = false
        }
    }
    
    /// Preloads data for a specific collection's destination view
    private func preloadDestinationData(for collection: Collection) {
        guard let collectionID = collection.id,
              preloadedData[collectionID] == nil else { return }
        
        // Capture ObjectID for thread safety
        let objectID = collection.objectID
        
        Task {
            await preloadDestinationDataAsync(objectID: objectID, collectionID: collectionID)
        }
    }
    
    /// Asynchronously preloads entries for a collection
    @MainActor
    private func preloadDestinationDataAsync(objectID: NSManagedObjectID, collectionID: UUID) async {
        // Skip if already preloaded
        if preloadedData[collectionID] != nil { return }
        
        let context = CoreDataManager.shared.container.viewContext
        
        let entries = await context.perform { () -> [JournalEntry] in
            guard let collection = try? context.existingObject(with: objectID) as? Collection else {
                return []
            }
            
            let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            // Limit initial fetch for better performance
            if collection.collectionType == "year" || collection.collectionType == "month" {
                fetchRequest.fetchLimit = 50
            }
            
            do {
                return try context.fetch(fetchRequest)
            } catch {
                return []
            }
        }
        
        // Cache the preloaded data
        preloadedData[collectionID] = entries
    }
    
    /// Loads collection entry counts asynchronously
    private func loadCollectionCounts() {
        guard !isLoadingCounts else { return } // Prevent multiple concurrent loads
        isLoadingCounts = true
        
        Task {
            await loadCountsAsync()
        }
    }
    
    /// Performs async loading of collection counts
    @MainActor
    private func loadCountsAsync() async {
        let allCollections = automaticCollections + userCollections
        
        // Batch fetch counts using TaskGroup with limited concurrency
        let counts = await withTaskGroup(of: (UUID, Int)?.self, returning: [UUID: Int].self) { group in
            var results: [UUID: Int] = [:]
            
            for collection in allCollections {
                guard let collectionID = collection.id else { continue }
                
                group.addTask {
                    let count = await self.fetchEntryCountByObjectID(objectID: collection.objectID)
                    return (collectionID, count)
                }
            }
            
            // Collect results efficiently
            for await result in group {
                if let (id, count) = result {
                    results[id] = count
                }
            }
            
            return results
        }
        
        // Update UI once with all results
        collectionCounts = counts
        isLoadingCounts = false
    }
    
    /// Fetches entry count for a collection using ObjectID for thread safety
    private func fetchEntryCountByObjectID(objectID: NSManagedObjectID) async -> Int {
        let context = CoreDataManager.shared.container.viewContext
        
        return await context.perform {
            guard let collection = try? context.existingObject(with: objectID) as? Collection else {
                return 0
            }
            
            let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "collection == %@", collection)
            
            do {
                return try context.count(for: fetchRequest)
            } catch {
                return 0
            }
        }
    }
    
    /// Parses month collection name into year and month components
    private func parseMonthCollectionName(_ name: String) -> (year: Int, month: Int)? {
        let components = name.split(separator: " ")
        guard let yearMonth = components.first else { return nil }
        
        let parts = yearMonth.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return nil }
        
        return (year, month)
    }
    
    /// Adds a new collection with the specified name
    private func addCollection(name: String) {
        guard !name.isEmpty else { return }
        
        let newCollection = CoreDataManager.shared.createCollection(name: name)
        
        // Update local arrays immediately for responsive UI
        userCollections.append(newCollection)
        
        // Set initial count
        if let collectionID = newCollection.id {
            collectionCounts[collectionID] = 0
        }
        
        // Clean up preloaded data to free memory
        cleanupPreloadedData()
    }
    
    /// Deletes the specified collection
    private func deleteCollection(_ collection: Collection) {
        // Don't delete automatic collections
        guard !collection.isAutomatic else { return }
        
        CoreDataManager.shared.deleteCollection(collection)
        
        // Remove from cache
        if let collectionID = collection.id {
            collectionCounts.removeValue(forKey: collectionID)
            preloadedData.removeValue(forKey: collectionID)
        }
        
        loadCollections()
    }
    
    /// Deletes user collections at the specified offsets
    private func deleteUserCollections(at offsets: IndexSet) {
        let context = CoreDataManager.shared.container.viewContext
        
        for index in offsets {
            let collection = userCollections[index]
            // Don't delete automatic collections
            guard !collection.isAutomatic else { continue }
            
            // Remove from cache
            if let collectionID = collection.id {
                collectionCounts.removeValue(forKey: collectionID)
                preloadedData.removeValue(forKey: collectionID)
            }
            
            context.delete(collection)
        }
        
        do {
            try context.save()
            userCollections.remove(atOffsets: offsets)
        } catch {
            // Silent failure - reload to sync
            loadCollections()
        }
    }
    
    /// Returns a formatted string describing the number of entries in a collection
    private func getEntryCountText(for collection: Collection) -> String {
        guard let collectionID = collection.id else {
            return "No entries"
        }
        
        let entryCount = collectionCounts[collectionID] ?? 0
        return entryCount == 0 ? "No entries" : "\(entryCount) \(entryCount == 1 ? "entry" : "entries")"
    }
    
    /// Cleans up preloaded data to manage memory
    private func cleanupPreloadedData() {
        // Keep only data for visible collections
        let visibleCollectionIDs = Set(
            (filteredAutomaticCollections + userCollections).compactMap { $0.id }
        )
        
        preloadedData = preloadedData.filter { visibleCollectionIDs.contains($0.key) }
    }
}
