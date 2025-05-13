//
//  IndexView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI
import CoreData

class IndexViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var entries: [JournalEntry] = []
    @Published var selectedEntry: JournalEntry? = nil
    
    func searchEntries() {
        // If search is empty, just show recent entries
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        if !searchText.isEmpty {
            // Create predicates for different fields to search
            let contentPredicate = NSPredicate(format: "content CONTAINS[cd] %@", searchText)
            let tagPredicate = NSPredicate(format: "ANY tags.name CONTAINS[cd] %@", searchText)
            
            // Combine predicates with OR
            let combinedPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [contentPredicate, tagPredicate])
            fetchRequest.predicate = combinedPredicate
        }
        
        // Sort by date, newest first
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        // Limit results if no search is active
        if searchText.isEmpty {
            fetchRequest.fetchLimit = 50 // Show most recent entries
        }
        
        do {
            entries = try context.fetch(fetchRequest)
            print("Found \(entries.count) entries")
        } catch {
            print("Error searching entries: \(error)")
            entries = []
        }
    }
}

struct IndexView: View {
    @StateObject private var viewModel = IndexViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                SearchBar(text: $viewModel.searchText, onSearchChanged: {
                    viewModel.searchEntries()
                })
                .padding(.horizontal)
                .padding(.top, 8)
                
                if viewModel.entries.isEmpty {
                    if viewModel.searchText.isEmpty {
                        // Initial state - no search has been performed yet
                        VStack {
                            Spacer()
                            
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 70))
                                .foregroundColor(.gray)
                            
                            Text("Your Journal Index")
                                .font(.title2)
                                .padding(.top)
                            
                            Text("Search for entries or browse your recent entries")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Spacer()
                        }
                    } else {
                        // No results for search
                        VStack {
                            Spacer()
                            
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 70))
                                .foregroundColor(.gray)
                            
                            Text("No Results")
                                .font(.title2)
                                .padding(.top)
                            
                            Text("No entries found matching '\(viewModel.searchText)'")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding()
                            
                            Spacer()
                        }
                    }
                } else {
                    List {
                        // Results header
                        if !viewModel.searchText.isEmpty {
                            Text("\(viewModel.entries.count) entries found")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Index")
            .onAppear {
                viewModel.searchEntries() // Load recent entries on appear
            }
            .sheet(item: $viewModel.selectedEntry) { entry in
                EditEntryView(entry: entry)
            }
        }
    }
}

// Custom Search Bar
struct SearchBar: View {
    @Binding var text: String
    var onSearchChanged: () -> Void
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search entries", text: $text)
                    .onChange(of: text) { _ in
                        onSearchChanged()
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                        onSearchChanged()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}
