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
            ForEach(monthsOfYear(), id: \.self) { monthInfo in
                NavigationLink(destination:
                    Group {
                        if let collection = getCollectionForMonth(monthInfo.month) {
                            // MonthArchiveView will be created in next file
                            MonthArchiveView(monthCollection: collection, year: yearCollection.name ?? "", month: monthInfo.name)
                        } else {
                            emptyMonthView(monthName: monthInfo.name)
                        }
                    }
                ) {
                    monthRow(monthInfo: monthInfo)
                }
            }
        }
        .navigationTitle(yearCollection.name ?? "Year")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadMonthCollections()
        }
    }
    
    // MARK: - View Components
    
    private func monthRow(monthInfo: MonthInfo) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(monthInfo.name)
                    .font(.headline)
                
                if let collection = getCollectionForMonth(monthInfo.month) {
                    if let entryCount = collection.entries?.count, entryCount > 0 {
                        Text("\(entryCount) entries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No entries")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not yet reached")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func emptyMonthView(monthName: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No entries for \(monthName)")
                .font(.headline)
            
            Text("Entries will appear here at the end of the month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadMonthCollections() {
        let fetchRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        
        // Get the year from the collection name
        guard let yearName = yearCollection.name else { return }
        
        // Look for collections that belong to this year (e.g., "2025/January")
        fetchRequest.predicate = NSPredicate(format: "name BEGINSWITH %@ AND isAutomatic == true", "\(yearName)/")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        
        do {
            monthCollections = try viewContext.fetch(fetchRequest)
        } catch {
            #if DEBUG
            print("Error loading month collections: \(error)")
            #endif
        }
    }
    
    private func getCollectionForMonth(_ month: Int) -> Collection? {
        let monthName = DateFormatter().monthSymbols[month - 1]
        guard let yearName = yearCollection.name else { return nil }
        let collectionName = "\(yearName)/\(monthName)"
        
        return monthCollections.first { $0.name == collectionName }
    }
    
    private func monthsOfYear() -> [MonthInfo] {
        let currentDate = Date()
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: currentDate)
        let currentYear = calendar.component(.year, from: currentDate)
        
        // Get the year from collection name
        guard let yearString = yearCollection.name,
              let year = Int(yearString) else { return [] }
        
        // For current year, only show months up to current month
        // For past years, show all 12 months
        let maxMonth = (year == currentYear) ? currentMonth : 12
        
        return (1...maxMonth).map { month in
            MonthInfo(month: month, name: DateFormatter().monthSymbols[month - 1])
        }
    }
}

// MARK: - Supporting Types

struct MonthInfo: Hashable {
    let month: Int
    let name: String
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
