//
//  YearLogView.swift
//  Bullet Tracker
//
//  Created on 6/5/2025.
//

import SwiftUI
@preconcurrency import CoreData

struct YearLogView: View {
    // MARK: - Properties
    
    let yearCollection: Collection
    
    // MARK: - State Properties
    
    @State private var monthCollections: [Collection] = []
    @State private var isLoading = true
    
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Constants
    
    private enum Layout {
        static let emptyStateImageSize: CGFloat = 48
        static let verticalSpacing: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 4
        static let iconFrameWidth: CGFloat = 30
    }
    
    // MARK: - Computed Properties
    
    private var sortedMonthCollections: [Collection] {
        monthCollections.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // MARK: - Data Loading
    
    private func loadMonthCollections() async {
        guard let yearName = yearCollection.name else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        // Create fetch request outside the async context
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "name BEGINSWITH %@ AND isAutomatic == true AND entries.@count > 0",
            "\(yearName)/"
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        
        let collections = await viewContext.perform {
            do {
                return try self.viewContext.fetch(fetchRequest)
            } catch {
                return []
            }
        }
        
        await MainActor.run {
            monthCollections = collections
            isLoading = false
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sortedMonthCollections, id: \.self) { collection in
                        NavigationLink(destination: monthArchiveView(for: collection)) {
                            monthRow(collection: collection)
                        }
                    }
                }
                .overlay {
                    if monthCollections.isEmpty {
                        emptyYearView
                    }
                }
            }
        }
        .navigationTitle(yearCollection.name ?? "Year")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadMonthCollections()
        }
    }
    
    // MARK: - View Components
    
    private func monthArchiveView(for collection: Collection) -> some View {
        MonthArchiveView(
            monthCollection: collection,
            year: yearCollection.name ?? "",
            month: extractMonthName(from: collection.name ?? "")
        )
    }
    
    private func monthRow(collection: Collection) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(.blue)
                .frame(width: Layout.iconFrameWidth)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(extractMonthName(from: collection.name ?? ""))
                    .font(.headline)
                
                Text(entryCountText(for: collection))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, Layout.rowVerticalPadding)
    }
    
    private var emptyYearView: some View {
        VStack(spacing: Layout.verticalSpacing) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: Layout.emptyStateImageSize))
                .foregroundStyle(.secondary)
            
            Text("No entries for \(yearCollection.name ?? "this year")")
                .font(.headline)
            
            Text("Entries will appear here as months complete")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractMonthName(from collectionName: String) -> String {
        // Collection names are in format "2025/January"
        // Using last component is more robust than index-based access
        collectionName.components(separatedBy: "/").last ?? "Unknown"
    }
    
    private func entryCountText(for collection: Collection) -> String {
        let count = collection.entries?.count ?? 0
        return "\(count) \(count == 1 ? "entry" : "entries")"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        YearLogView(yearCollection: {
            let collection = Collection(context: CoreDataManager.shared.container.viewContext)
            collection.name = "2025"
            collection.isAutomatic = true
            collection.collectionType = "year"
            return collection
        }())
    }
}
