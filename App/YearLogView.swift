//
//  YearLogView.swift
//  Bullet Tracker
//
//  Created on 6/5/2025.
//

import SwiftUI
import CoreData

struct YearLogView: View {
    // MARK: - Properties
    
    let yearCollection: Collection
    
    // MARK: - State Properties
    
    @State private var monthCollections: [Collection] = []
    @State private var selectedMonth: Collection?
    
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Body
    
    var body: some View {
        List {
            ForEach(monthCollections.sorted(by: { ($0.sortOrder) < ($1.sortOrder) }), id: \.self) { collection in
                NavigationLink(destination:
                    MonthArchiveView(
                        monthCollection: collection,
                        year: yearCollection.name ?? "",
                        month: extractMonthName(from: collection.name ?? "")
                    )
                ) {
                    monthRow(collection: collection)
                }
            }
        }
        .navigationTitle(yearCollection.name ?? "Year")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadMonthCollections()
        }
        .overlay {
            if monthCollections.isEmpty {
                emptyYearView
            }
        }
    }
    
    // MARK: - View Components
    
    private func monthRow(collection: Collection) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(extractMonthName(from: collection.name ?? ""))
                    .font(.headline)
                
                let entryCount = collection.entries?.count ?? 0
                Text("\(entryCount) \(entryCount == 1 ? "entry" : "entries")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var emptyYearView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 48))
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
    
    private func loadMonthCollections() {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        
        // Get the year from the collection name
        guard let yearName = yearCollection.name else { return }
        
        // Look for collections that belong to this year and have entries
        fetchRequest.predicate = NSPredicate(
            format: "name BEGINSWITH %@ AND isAutomatic == true AND entries.@count > 0",
            "\(yearName)/"
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        
        do {
            monthCollections = try viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("Error loading month collections: \(error)")
            #endif
        }
    }
    
    private func extractMonthName(from collectionName: String) -> String {
        // Collection names are in format "2025/January"
        let components = collectionName.split(separator: "/")
        if components.count > 1 {
            return String(components[1])
        }
        return "Unknown"
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
