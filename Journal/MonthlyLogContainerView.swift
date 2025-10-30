//
//  MonthlyLogContainerView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/4/25.
//

import SwiftUI
import CoreData

// MARK: - Month Data Cache

@MainActor
private class MonthDataCache {
    struct MonthKey: Hashable {
        let year: Int
        let month: Int
    }
    
    struct MonthData {
        let entries: [JournalEntry]
        let specialEntries: [JournalEntry]
        let loadedAt: Date
    }
    
    private var cache: [MonthKey: MonthData] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    private let maxCacheSize = 5 // Keep up to 5 months cached
    
    func get(year: Int, month: Int) -> MonthData? {
        let key = MonthKey(year: year, month: month)
        
        if let data = cache[key] {
            // Check if cache is still valid
            if Date().timeIntervalSince(data.loadedAt) < cacheExpirationTime {
                return data
            } else {
                // Remove expired cache
                cache.removeValue(forKey: key)
            }
        }
        
        return nil
    }
    
    func set(year: Int, month: Int, entries: [JournalEntry], specialEntries: [JournalEntry]) {
        let key = MonthKey(year: year, month: month)
        
        // Limit cache size
        if cache.count >= maxCacheSize {
            // Remove oldest entry
            if let oldestKey = cache.min(by: { $0.value.loadedAt < $1.value.loadedAt })?.key {
                cache.removeValue(forKey: oldestKey)
            }
        }
        
        cache[key] = MonthData(
            entries: entries,
            specialEntries: specialEntries,
            loadedAt: Date()
        )
    }
    
    func invalidate(year: Int, month: Int) {
        let key = MonthKey(year: year, month: month)
        cache.removeValue(forKey: key)
    }
    
    func invalidateAll() {
        cache.removeAll()
    }
}

struct MonthlyLogContainerView: View {
    // MARK: - State Properties
    
    @State private var currentYear: Int
    @State private var currentMonth: Int
    @State private var isPreloading = false
    
    // MARK: - Static Cache
    
    private static let monthCache = MonthDataCache()
    
    // MARK: - Private Properties
    
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    
    init() {
        let now = Date()
        let calendar = Calendar.current
        _currentYear = State(initialValue: calendar.component(.year, from: now))
        _currentMonth = State(initialValue: calendar.component(.month, from: now))
    }
    
    // MARK: - Body
    
    var body: some View {
        MonthLogView(
            year: currentYear,
            month: currentMonth,
            onNavigatePrevious: navigateToPreviousMonth,
            onNavigateNext: navigateToNextMonth
        )
        .id("\(currentYear)-\(currentMonth)") // Force view refresh on navigation
        .onAppear {
            preloadAdjacentMonths()
        }
        .onChange(of: currentMonth) { _, _ in
            preloadAdjacentMonths()
        }
        .onChange(of: currentYear) { _, _ in
            preloadAdjacentMonths()
        }
    }
    
    // MARK: - Navigation Methods
    
    private func navigateToPreviousMonth() {
        adjustMonth(by: -1)
    }
    
    private func navigateToNextMonth() {
        adjustMonth(by: 1)
    }
    
    private func adjustMonth(by value: Int) {
        let components = DateComponents(year: currentYear, month: currentMonth)
        
        if let currentDate = calendar.date(from: components),
           let newDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentYear = calendar.component(.year, from: newDate)
            currentMonth = calendar.component(.month, from: newDate)
        }
    }
    
    // MARK: - Caching Methods
    
    private func getCachedData() -> MonthDataCache.MonthData? {
        return Self.monthCache.get(year: currentYear, month: currentMonth)
    }
    
    private func preloadAdjacentMonths() {
        guard !isPreloading else { return }
        isPreloading = true
        
        Task {
            // Preload previous, current, and next month
            await withTaskGroup(of: Void.self) { group in
                // Previous month
                if let prevDate = getAdjacentDate(offset: -1) {
                    let prevYear = calendar.component(.year, from: prevDate)
                    let prevMonth = calendar.component(.month, from: prevDate)
                    
                    group.addTask {
                        await self.preloadMonth(year: prevYear, month: prevMonth)
                    }
                }
                
                // Current month (in case not cached)
                group.addTask {
                    await self.preloadMonth(year: self.currentYear, month: self.currentMonth)
                }
                
                // Next month
                if let nextDate = getAdjacentDate(offset: 1) {
                    let nextYear = calendar.component(.year, from: nextDate)
                    let nextMonth = calendar.component(.month, from: nextDate)
                    
                    group.addTask {
                        await self.preloadMonth(year: nextYear, month: nextMonth)
                    }
                }
                
                await group.waitForAll()
            }
            
            isPreloading = false
        }
    }
    
    private func getAdjacentDate(offset: Int) -> Date? {
        let components = DateComponents(year: currentYear, month: currentMonth)
        
        if let currentDate = calendar.date(from: components) {
            return calendar.date(byAdding: .month, value: offset, to: currentDate)
        }
        
        return nil
    }
    
    @MainActor
    private func preloadMonth(year: Int, month: Int) async {
        // Skip if already cached
        if Self.monthCache.get(year: year, month: month) != nil {
            return
        }
        
        let context = CoreDataManager.shared.container.viewContext
        
        await context.perform {
            // Create date range for the month
            let startComponents = DateComponents(year: year, month: month, day: 1)
            guard let startDate = self.calendar.date(from: startComponents),
                  let endDate = self.calendar.date(byAdding: .month, value: 1, to: startDate) else {
                return
            }
            
            // Fetch regular entries
            let entriesFetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
            entriesFetchRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND isSpecialEntry == false",
                startDate as NSDate,
                endDate as NSDate
            )
            entriesFetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            // Fetch special entries
            let specialFetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
            specialFetchRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND isSpecialEntry == true",
                startDate as NSDate,
                endDate as NSDate
            )
            specialFetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
            
            do {
                let entries = try context.fetch(entriesFetchRequest)
                let specialEntries = try context.fetch(specialFetchRequest)
                
                // Cache the results
                Task { @MainActor in
                    Self.monthCache.set(
                        year: year,
                        month: month,
                        entries: entries,
                        specialEntries: specialEntries
                    )
                }
            } catch {
                // Silent failure - data will be loaded on demand
            }
        }
    }
    
    // MARK: - Public Cache Management
    
    static func invalidateCache(for year: Int, month: Int) {
        monthCache.invalidate(year: year, month: month)
    }
    
    static func invalidateAllCache() {
        monthCache.invalidateAll()
    }
}
