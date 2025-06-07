//
//  IndexView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

// MARK: - View Model

@MainActor
class IndexViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var searchText: String = ""
    @Published var entries: [JournalEntry] = []
    @Published var selectedEntry: JournalEntry? = nil
    
    // MARK: - Constants
    
    private let recentEntriesLimit = 50
    
    // MARK: - Private Properties
    
    private var searchTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    /// Searches journal entries with debouncing
    func searchEntries() {
        // Cancel previous search
        searchTask?.cancel()
        
        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            guard !Task.isCancelled else { return }
            
            await performSearch()
        }
    }
    
    // MARK: - Private Methods
    
    private func performSearch() async {
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        configureSearchPredicate(for: fetchRequest)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        if searchText.isEmpty {
            fetchRequest.fetchLimit = recentEntriesLimit
        }
        
        do {
            entries = try context.fetch(fetchRequest)
        } catch {
            entries = []
        }
    }
    
    private func configureSearchPredicate(for fetchRequest: NSFetchRequest<JournalEntry>) {
        guard !searchText.isEmpty else { return }
        
        let contentPredicate = NSPredicate(format: "content CONTAINS[cd] %@", searchText)
        let tagPredicate = NSPredicate(format: "ANY tags.name CONTAINS[cd] %@", searchText)
        
        fetchRequest.predicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: [contentPredicate, tagPredicate]
        )
    }
}

// MARK: - Main View

struct IndexView: View {
    // MARK: - State Properties
    
    @StateObject private var viewModel = IndexViewModel()
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - Constants
    
    private enum Layout {
        static let emptyStateImageSize: CGFloat = 70
        static let verticalSpacing: CGFloat = 16
        static let horizontalPadding: CGFloat = 8
        static let searchBarCornerRadius: CGFloat = 10
    }
    
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
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search entries", text: $viewModel.searchText)
                .focused($isSearchFocused)
                .onChange(of: viewModel.searchText) { _, _ in
                    viewModel.searchEntries()
                }
            
            if !viewModel.searchText.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(Layout.horizontalPadding)
        .background(Color(.systemGray6))
        .cornerRadius(Layout.searchBarCornerRadius)
        .padding(.horizontal)
        .padding(.top, Layout.horizontalPadding)
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
        VStack(spacing: Layout.verticalSpacing) {
            Spacer()
            
            Image(systemName: viewModel.searchText.isEmpty ? "doc.text.magnifyingglass" : "magnifyingglass")
                .font(.system(size: Layout.emptyStateImageSize))
                .foregroundStyle(.secondary)
            
            Text(emptyStateTitle)
                .font(.title2)
            
            Text(emptyStateMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var emptyStateTitle: String {
        viewModel.searchText.isEmpty ? "Your Journal Index" : "No Results"
    }
    
    private var emptyStateMessage: String {
        if viewModel.searchText.isEmpty {
            return "Search for entries or browse your recent entries"
        } else {
            return "No entries found matching '\(viewModel.searchText)'"
        }
    }
    
    private var entriesListView: some View {
        List {
            if !viewModel.searchText.isEmpty {
                Text("\(viewModel.entries.count) entries found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
            }
            
            ForEach(viewModel.entries) { entry in
                EntryListItem(entry: entry)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedEntry = entry
                    }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Helper Methods
    
    private func clearSearch() {
        viewModel.searchText = ""
        viewModel.searchEntries()
        isSearchFocused = false
    }
}

// MARK: - Preview

#Preview {
    IndexView()
        .environment(\.managedObjectContext, CoreDataManager.shared.container.viewContext)
}
