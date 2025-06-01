//
//  IndexView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

// MARK: - View Model

class IndexViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchText: String = ""
    @Published var entries: [JournalEntry] = []
    @Published var selectedEntry: JournalEntry? = nil
    
    // MARK: - Constants
    
    private let recentEntriesLimit = 50
    
    // MARK: - Public Methods
    
    /// Searches journal entries based on the current search text
    func searchEntries() {
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        configureSearchPredicate(for: fetchRequest)
        configureSortDescriptors(for: fetchRequest)
        
        if searchText.isEmpty {
            fetchRequest.fetchLimit = recentEntriesLimit
        }
        
        do {
            entries = try context.fetch(fetchRequest)
            #if DEBUG
            print("Found \(entries.count) entries")
            #endif
        } catch {
            #if DEBUG
            print("Error searching entries: \(error)")
            #endif
            entries = []
        }
    }
    
    // MARK: - Private Methods
    
    /// Configures the search predicate based on the search text
    private func configureSearchPredicate(for fetchRequest: NSFetchRequest<JournalEntry>) {
        guard !searchText.isEmpty else { return }
        
        let contentPredicate = NSPredicate(
            format: "content CONTAINS[cd] %@",
            searchText
        )
        let tagPredicate = NSPredicate(
            format: "ANY tags.name CONTAINS[cd] %@",
            searchText
        )
        
        fetchRequest.predicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: [contentPredicate, tagPredicate]
        )
    }
    
    /// Configures sort descriptors to show newest entries first
    private func configureSortDescriptors(for fetchRequest: NSFetchRequest<JournalEntry>) {
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: false)
        ]
    }
}

// MARK: - Main View

struct IndexView: View {
    // MARK: - State Properties
    
    @StateObject private var viewModel = IndexViewModel()
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                contentView
            }
            .navigationTitle("Index")
            .onAppear {
                viewModel.searchEntries()
            }
            .sheet(item: $viewModel.selectedEntry) { entry in
                EditEntryView(entry: entry)
            }
        }
    }
    
    // MARK: - View Components
    
    private var searchBar: some View {
        SearchBar(text: $viewModel.searchText) {
            viewModel.searchEntries()
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var contentView: some View {
        Group {
            if viewModel.entries.isEmpty {
                emptyStateView
            } else {
                entriesListView
            }
        }
    }
    
    private var emptyStateView: some View {
        Group {
            if viewModel.searchText.isEmpty {
                initialStateView
            } else {
                noResultsView
            }
        }
    }
    
    private var initialStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundStyle(.secondary)
            
            Text("Your Journal Index")
                .font(.title2)
            
            Text("Search for entries or browse your recent entries")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 70))
                .foregroundStyle(.secondary)
            
            Text("No Results")
                .font(.title2)
            
            Text("No entries found matching '\(viewModel.searchText)'")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var entriesListView: some View {
        List {
            if !viewModel.searchText.isEmpty {
                resultsHeader
            }
            
            entriesSection
        }
        .listStyle(.plain)
    }
    
    private var resultsHeader: some View {
        Text("\(viewModel.entries.count) entries found")
            .font(.caption)
            .foregroundStyle(.secondary)
            .listRowBackground(Color.clear)
    }
    
    private var entriesSection: some View {
        ForEach(viewModel.entries) { entry in
            EntryListItem(entry: entry)
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedEntry = entry
                }
        }
    }
}

// MARK: - Supporting Views

struct SearchBar: View {
    // MARK: - Properties
    
    @Binding var text: String
    let onSearchChanged: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            searchField
        }
    }
    
    // MARK: - View Components
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search entries", text: $text)
                .onChange(of: text) { _, _ in
                    onSearchChanged()
                }
            
            if !text.isEmpty {
                clearButton
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    private var clearButton: some View {
        Button {
            text = ""
            onSearchChanged()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
    }
}
