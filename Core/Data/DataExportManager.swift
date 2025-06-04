//
//  DataExportManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/13/25.
//

import Foundation
import CoreData
import UIKit

class DataExportManager {
    static let shared = DataExportManager()
    
    // MARK: - CSV Export
    
    /// Exports habit data to CSV format
    func exportHabitsToCSV() -> URL? {
        let habits = CoreDataManager.shared.fetchAllHabits()
        
        // Create CSV header
        var csvString = "Name,Icon,Color,Frequency,CustomDays,StartDate,Notes,MultiState,TrackDetails,DetailType,Order\n"
        
        // Add data rows
        for habit in habits {
            let row = [
                escapeCSV(habit.name ?? ""),
                escapeCSV(habit.icon ?? ""),
                escapeCSV(habit.color ?? ""),
                escapeCSV(habit.frequency ?? ""),
                escapeCSV(habit.customDays ?? ""),
                formatDate(habit.startDate ?? Date()),
                escapeCSV(habit.notes ?? ""),
                "\(habit.value(forKey: "useMultipleStates") as? Bool ?? false)",
                "\(habit.value(forKey: "trackDetails") as? Bool ?? false)",
                escapeCSV(habit.value(forKey: "detailType") as? String ?? ""),
                "\(habit.order)"
            ]
            
            csvString.append(row.joined(separator: ",") + "\n")
        }
        
        // Create a file in the temporary directory
        let fileName = "BulletTracker_Habits_\(formatDateForFilename(Date())).csv"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            #if DEBUG
            print("Error writing CSV file: \(error)")
            #endif
            return nil
        }
    }
    
    /// Exports habit data to CSV format with summary statistics
    func exportHabitsToCSVWithStats() -> URL? {
        let habits = CoreDataManager.shared.fetchAllHabits()
        
        // Create CSV header
        var csvString = "Name,Icon,Color,Frequency,CustomDays,StartDate,Notes,MultiState,TrackDetails,DetailType,Order\n"
        
        // Add data rows
        for habit in habits {
            let row = [
                escapeCSV(habit.name ?? ""),
                escapeCSV(habit.icon ?? ""),
                escapeCSV(habit.color ?? ""),
                escapeCSV(habit.frequency ?? ""),
                escapeCSV(habit.customDays ?? ""),
                formatDate(habit.startDate ?? Date()),
                escapeCSV(habit.notes ?? ""),
                "\(habit.value(forKey: "useMultipleStates") as? Bool ?? false)",
                "\(habit.value(forKey: "trackDetails") as? Bool ?? false)",
                escapeCSV(habit.value(forKey: "detailType") as? String ?? ""),
                "\(habit.order)"
            ]
            
            csvString.append(row.joined(separator: ",") + "\n")
        }
        
        // Add summary statistics section
        csvString.append("\n# Summary Statistics\n")
        csvString.append("Total Habits,\(habits.count)\n")
        
        // Count habits by frequency
        let dailyCount = habits.filter { $0.frequency == "daily" }.count
        let weekdaysCount = habits.filter { $0.frequency == "weekdays" }.count
        let weekendsCount = habits.filter { $0.frequency == "weekends" }.count
        let weeklyCount = habits.filter { $0.frequency == "weekly" }.count
        let customCount = habits.filter { $0.frequency == "custom" }.count
        
        csvString.append("Daily Habits,\(dailyCount)\n")
        csvString.append("Weekday Habits,\(weekdaysCount)\n")
        csvString.append("Weekend Habits,\(weekendsCount)\n")
        csvString.append("Weekly Habits,\(weeklyCount)\n")
        csvString.append("Custom Schedule Habits,\(customCount)\n")
        
        // Create a file in the temporary directory
        let fileName = "BulletTracker_Habits_\(formatDateForFilename(Date())).csv"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            #if DEBUG
            print("Error writing CSV file: \(error)")
            #endif
            return nil
        }
    }
    
    /// Exports habit entries data to CSV format
    func exportHabitEntriesToCSV() -> URL? {
        let habits = CoreDataManager.shared.fetchAllHabits()
        
        // Create CSV header
        var csvString = "HabitName,Date,Completed,CompletionState,Details\n"
        
        // Get all habit entries
        for habit in habits {
            if let entries = habit.entries as? Set<HabitEntry> {
                for entry in entries {
                    let row = [
                        escapeCSV(habit.name ?? ""),
                        formatDate(entry.date ?? Date()),
                        "\(entry.completed)",
                        "\(entry.value(forKey: "completionState") as? Int ?? 1)",
                        escapeCSV(entry.details ?? "")
                    ]
                    
                    csvString.append(row.joined(separator: ",") + "\n")
                }
            }
        }
        
        // Create a file in the temporary directory
        let fileName = "BulletTracker_HabitEntries_\(formatDateForFilename(Date())).csv"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            #if DEBUG
            print("Error writing CSV file: \(error)")
            #endif
            return nil
        }
    }
    
    /// Exports a monthly report for habit tracking
    func exportMonthlyReport(for date: Date) -> URL? {
        let calendar = Calendar.current
        
        // Get the first and last day of the month
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            #if DEBUG
            print("Error calculating month date range")
            #endif
            return nil
        }
        
        #if DEBUG
        print("Generating monthly report from \(startOfMonth) to \(endOfMonth)")
        #endif
        
        let habits = CoreDataManager.shared.fetchAllHabits()
        #if DEBUG
        print("Found \(habits.count) habits")
        #endif
        
        // Create a formatted month name for the report
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let monthTitle = dateFormatter.string(from: date)
        
        // Create simple report if no data is available
        if habits.isEmpty {
            // Create a simple report
            var csvString = "Monthly Habit Report - \(monthTitle)\n\n"
            csvString.append("No habits found in the system. Add habits to generate a detailed report.\n")
            
            // Create a file in the temporary directory
            let fileName = "BulletTracker_MonthlyReport_\(formatDateForFilename(date)).csv"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            
            do {
                try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
                #if DEBUG
                print("Successfully created empty monthly report at: \(tempURL)")
                #endif
                return tempURL
            } catch {
                #if DEBUG
                print("Error writing monthly report file: \(error)")
                #endif
                return nil
            }
        }
        
        // Create the CSV header
        var csvString = "Monthly Habit Report - \(monthTitle)\n\n"
        csvString.append("Habit Name,Frequency,Success Rate,Success,Partial,Failed\n")
        
        // Get all habit entries for the month - manually since getHabitEntriesForDateRange might not be available
        let entries = getHabitEntriesForRange(start: startOfMonth, end: endOfMonth)
        #if DEBUG
        print("Found \(entries.count) habit entries for the month")
        #endif
        
        // Process each habit
        for habit in habits {
            guard let habitId = habit.id else { continue }
            
            // Calculate expected completions for this habit in the month
            var expectedCompletions = 0
            var currentDate = startOfMonth
            while currentDate <= endOfMonth {
                if shouldPerformHabit(habit, on: currentDate) {
                    expectedCompletions += 1
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            // Get actual completions
            let habitEntries = entries.filter { $0.habit?.id == habitId }
            let actualCompletions = habitEntries.count
            
            // Count by state if habit uses multiple states
            let useMultipleStates = habit.value(forKey: "useMultipleStates") as? Bool ?? false
            var successCount = 0
            var partialCount = 0
            var failedCount = 0
            
            if useMultipleStates {
                for entry in habitEntries {
                    let state = entry.value(forKey: "completionState") as? Int ?? 1
                    switch state {
                    case 1: successCount += 1
                    case 2: partialCount += 1
                    case 3: failedCount += 1
                    default: break
                    }
                }
            } else {
                // If not using multiple states, all completions are successes
                successCount = actualCompletions
            }
            
            // Calculate success rate
            let successRate = expectedCompletions > 0 ? Double(successCount) / Double(expectedCompletions) : 0
            let successRateFormatted = String(format: "%.1f%%", successRate * 100)
            
            // Create the row - different format based on whether it's multi-state or binary
            let row: [String]
            
            if useMultipleStates {
                // Multi-state habit format (with success/partial/failed columns)
                row = [
                    escapeCSV(habit.name ?? ""),
                    escapeCSV(getFrequencyDescription(habit)),
                    successRateFormatted,
                    "\(successCount)/\(expectedCompletions)", // Success fraction
                    "\(partialCount)/\(expectedCompletions)", // Partial fraction
                    "\(failedCount)/\(expectedCompletions)"   // Failed fraction
                ]
            } else {
                // Binary habit format (without partial/failed columns)
                row = [
                    escapeCSV(habit.name ?? ""),
                    escapeCSV(getFrequencyDescription(habit)),
                    successRateFormatted,
                    "\(successCount)/\(expectedCompletions)", // Success fraction
                    "", // Empty partial column
                    ""  // Empty failed column
                ]
            }
            
            csvString.append(row.joined(separator: ",") + "\n")
        }
        
        // Add summary section
        csvString.append("\n# Month Summary\n")
        
        // Calculate overall statistics
        let totalExpectedCompletions = habits.reduce(0) { total, habit in
            var expectedForHabit = 0
            var currentDate = startOfMonth
            while currentDate <= endOfMonth {
                if shouldPerformHabit(habit, on: currentDate) {
                    expectedForHabit += 1
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            return total + expectedForHabit
        }
        
        let totalActualCompletions = entries.count
        let overallSuccessRate = totalExpectedCompletions > 0 ? Double(totalActualCompletions) / Double(totalExpectedCompletions) : 0
        
        csvString.append("Total Expected Completions,\(totalExpectedCompletions)\n")
        csvString.append("Total Actual Completions,\(totalActualCompletions)\n")
        csvString.append("Overall Success Rate,\(String(format: "%.1f%%", overallSuccessRate * 100))\n")
        
        // Calculate total success completions
        let totalSuccessCompletions = entries.filter { entry in
            let habit = entry.habit
            let useMultipleStates = habit?.value(forKey: "useMultipleStates") as? Bool ?? false
            if useMultipleStates {
                return (entry.value(forKey: "completionState") as? Int ?? 1) == 1
            } else {
                return true
            }
        }.count
        
        csvString.append("Overall Completion Fraction,\(totalSuccessCompletions)/\(totalExpectedCompletions)\n")
        
        // Calculate most and least successful habits
        if !habits.isEmpty {
            var habitSuccessRates: [(Habit, Double)] = []
            
            for habit in habits {
                guard let habitId = habit.id else { continue }
                
                // Calculate expected completions
                var expectedForHabit = 0
                var currentDate = startOfMonth
                while currentDate <= endOfMonth {
                    if shouldPerformHabit(habit, on: currentDate) {
                        expectedForHabit += 1
                    }
                    currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                }
                
                if expectedForHabit > 0 {
                    // Calculate actual successful completions
                    let habitEntries = entries.filter { $0.habit?.id == habitId }
                    let successCount = habitEntries.filter {
                        ($0.value(forKey: "completionState") as? Int ?? 1) == 1 ||
                        !(habit.value(forKey: "useMultipleStates") as? Bool ?? false)
                    }.count
                    
                    let successRate = Double(successCount) / Double(expectedForHabit)
                    habitSuccessRates.append((habit, successRate))
                }
            }
            
            // Sort by success rate
            habitSuccessRates.sort { $0.1 > $1.1 }
            
            if let mostSuccessful = habitSuccessRates.first {
                csvString.append("Most Successful Habit,\(escapeCSV(mostSuccessful.0.name ?? "")),\(String(format: "%.1f%%", mostSuccessful.1 * 100))\n")
            }
            
            if habitSuccessRates.count > 1, let leastSuccessful = habitSuccessRates.last {
                csvString.append("Least Successful Habit,\(escapeCSV(leastSuccessful.0.name ?? "")),\(String(format: "%.1f%%", leastSuccessful.1 * 100))\n")
            }
        }
        
        // Create a file in the temporary directory
        let fileName = "BulletTracker_MonthlyReport_\(formatDateForFilename(date)).csv"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
            #if DEBUG
            print("Successfully created monthly report at: \(tempURL)")
            #endif
            return tempURL
        } catch {
            #if DEBUG
            print("Error writing monthly report file: \(error)")
            #endif
            return nil
        }
    }
    
    // Custom implementation to get habit entries for a date range
    private func getHabitEntriesForRange(start: Date, end: Date) -> [HabitEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: end)!
        
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            let results = try context.fetch(fetchRequest)
            #if DEBUG
            print("Found \(results.count) entries between \(startOfDay) and \(endOfDay)")
            #endif
            return results
        } catch {
            #if DEBUG
            print("Error fetching habit entries for date range: \(error)")
            #endif
            return []
        }
    }
    
    // MARK: - JSON Export/Import
    
    /// Exports all app data to a JSON file
    func exportAppDataToJSON() -> URL? {
        let appData = createAppDataDictionary()
        
        // Convert to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: appData, options: .prettyPrinted)
            
            // Create a file in the temporary directory
            let fileName = "BulletTracker_Backup_\(formatDateForFilename(Date())).json"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            #if DEBUG
            print("Error creating JSON backup: \(error)")
            #endif
            return nil
        }
    }
    
    /// Imports app data from a JSON file
    func importAppDataFromJSON(url: URL, completion: @escaping (Bool, String) -> Void) {
        do {
            let jsonData = try Data(contentsOf: url)
            guard let appData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                completion(false, "Invalid JSON format")
                return
            }
            
            // Clear existing data
            CoreDataManager.shared.clearAllData()
            
            // Import data
            let result = restoreAppDataFromDictionary(appData)
            completion(result.success, result.message)
        } catch {
            completion(false, "Error reading JSON file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Share Data
    
    /// Share a file using UIActivityViewController
    func shareFile(url: URL, from viewController: UIViewController, sourceView: UIView? = nil) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // For iPad support
        if let sourceView = sourceView {
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        }
        
        viewController.present(activityVC, animated: true)
    }
    
    // MARK: - Helper Methods
    
    /// Creates a dictionary representing all app data
    private func createAppDataDictionary() -> [String: Any] {
        let habitData = exportHabitsToDict()
        let entriesData = exportHabitEntriesToDict()
        let collectionsData = exportCollectionsToDict()
        let journalEntriesData = exportJournalEntriesToDict()
        let tagsData = exportTagsToDict()
        
        return [
            "version": 1,
            "timestamp": Date().timeIntervalSince1970,
            "habits": habitData,
            "habitEntries": entriesData,
            "collections": collectionsData,
            "journalEntries": journalEntriesData,
            "tags": tagsData
        ]
    }
    
    /// Restores app data from a dictionary
    private func restoreAppDataFromDictionary(_ data: [String: Any]) -> (success: Bool, message: String) {
        guard let version = data["version"] as? Int, version == 1 else {
            return (false, "Unsupported backup version")
        }
        
        let context = CoreDataManager.shared.container.viewContext
        
        // First restore collections (they have no dependencies)
        if let collectionsData = data["collections"] as? [[String: Any]] {
            _ = importCollections(collectionsData, context: context)
        }
        
        // Then restore tags
        if let tagsData = data["tags"] as? [[String: Any]] {
            _ = importTags(tagsData, context: context)
        }
        
        // Then restore habits
        var habitsMap: [String: Habit] = [:]
        if let habitsData = data["habits"] as? [[String: Any]] {
            habitsMap = importHabits(habitsData, context: context)
        }
        
        // Then restore habit entries (depend on habits)
        if let entriesData = data["habitEntries"] as? [[String: Any]] {
            importHabitEntries(entriesData, habitsMap: habitsMap, context: context)
        }
        
        // Finally restore journal entries (may depend on collections and tags)
        if let journalEntriesData = data["journalEntries"] as? [[String: Any]] {
            importJournalEntries(journalEntriesData, context: context)
        }
        
        // Save changes
        do {
            try context.save()
            return (true, "Data imported successfully")
        } catch {
            return (false, "Error saving data: \(error.localizedDescription)")
        }
    }
    
    // Export methods for each entity type
    private func exportHabitsToDict() -> [[String: Any]] {
        let habits = CoreDataManager.shared.fetchAllHabits()
        var result: [[String: Any]] = []
        
        for habit in habits {
            var habitDict: [String: Any] = [
                "id": habit.id?.uuidString ?? UUID().uuidString,
                "name": habit.name ?? "",
                "icon": habit.icon ?? "",
                "color": habit.color ?? "",
                "frequency": habit.frequency ?? "",
                "customDays": habit.customDays ?? "",
                "order": habit.order
            ]
            
            if let startDate = habit.startDate {
                habitDict["startDate"] = startDate.timeIntervalSince1970
            }
            
            if let notes = habit.notes {
                habitDict["notes"] = notes
            }
            
            if let useMultipleStates = habit.value(forKey: "useMultipleStates") as? Bool {
                habitDict["useMultipleStates"] = useMultipleStates
            }
            
            if let trackDetails = habit.value(forKey: "trackDetails") as? Bool {
                habitDict["trackDetails"] = trackDetails
            }
            
            if let detailType = habit.value(forKey: "detailType") as? String {
                habitDict["detailType"] = detailType
            }
            
            if let collection = habit.collection, let collectionId = collection.id {
                habitDict["collectionId"] = collectionId.uuidString
            }
            
            result.append(habitDict)
        }
        
        return result
    }
    
    private func exportHabitEntriesToDict() -> [[String: Any]] {
        let habits = CoreDataManager.shared.fetchAllHabits()
        var result: [[String: Any]] = []
        
        for habit in habits {
            if let entries = habit.entries as? Set<HabitEntry> {
                for entry in entries {
                    var entryDict: [String: Any] = [
                        "id": entry.id?.uuidString ?? UUID().uuidString,
                        "habitId": habit.id?.uuidString ?? "",
                        "completed": entry.completed
                    ]
                    
                    if let date = entry.date {
                        entryDict["date"] = date.timeIntervalSince1970
                    }
                    
                    if let completionState = entry.value(forKey: "completionState") as? Int {
                        entryDict["completionState"] = completionState
                    }
                    
                    if let details = entry.details {
                        entryDict["details"] = details
                    }
                    
                    result.append(entryDict)
                }
            }
        }
        
        return result
    }
    
    private func exportCollectionsToDict() -> [[String: Any]] {
        let collections = CoreDataManager.shared.fetchAllCollections()
        var result: [[String: Any]] = []
        
        for collection in collections {
            let collectionDict: [String: Any] = [
                "id": collection.id?.uuidString ?? UUID().uuidString,
                "name": collection.name ?? ""
            ]
            
            result.append(collectionDict)
        }
        
        return result
    }
    
    private func exportJournalEntriesToDict() -> [[String: Any]] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        var result: [[String: Any]] = []
        
        do {
            let entries = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
            
            for entry in entries {
                var entryDict: [String: Any] = [
                    "id": entry.id?.uuidString ?? UUID().uuidString,
                    "content": entry.content ?? "",
                    "entryType": entry.entryType ?? "",
                    "priority": entry.priority
                ]
                
                if let date = entry.date {
                    entryDict["date"] = date.timeIntervalSince1970
                }
                
                if let taskStatus = entry.taskStatus {
                    entryDict["taskStatus"] = taskStatus
                }
                
                if let collection = entry.collection, let collectionId = collection.id {
                    entryDict["collectionId"] = collectionId.uuidString
                }
                
                // Handle tags
                if let tags = entry.tags as? Set<Tag> {
                    var tagIds: [String] = []
                    for tag in tags {
                        if let tagId = tag.id?.uuidString {
                            tagIds.append(tagId)
                        }
                    }
                    entryDict["tagIds"] = tagIds
                }
                
                result.append(entryDict)
            }
        } catch {
            #if DEBUG
            print("Error fetching journal entries: \(error)")
            #endif
        }
        
        return result
    }
    
    private func exportTagsToDict() -> [[String: Any]] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        var result: [[String: Any]] = []
        
        do {
            let tags = try CoreDataManager.shared.container.viewContext.fetch(fetchRequest)
            
            for tag in tags {
                let tagDict: [String: Any] = [
                    "id": tag.id?.uuidString ?? UUID().uuidString,
                    "name": tag.name ?? ""
                ]
                
                result.append(tagDict)
            }
        } catch {
            #if DEBUG
            print("Error fetching tags: \(error)")
            #endif
        }
        
        return result
    }
    
    // Import methods for each entity type
    private func importCollections(_ collections: [[String: Any]], context: NSManagedObjectContext) -> [String: Collection] {
        var collectionsMap: [String: Collection] = [:]
        
        for collectionData in collections {
            guard let idString = collectionData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = collectionData["name"] as? String else {
                continue
            }
            
            let collection = Collection(context: context)
            collection.id = id
            collection.name = name
            
            collectionsMap[idString] = collection
        }
        
        return collectionsMap
    }
    
    private func importTags(_ tags: [[String: Any]], context: NSManagedObjectContext) -> [String: Tag] {
        var tagsMap: [String: Tag] = [:]
        
        for tagData in tags {
            guard let idString = tagData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = tagData["name"] as? String else {
                continue
            }
            
            let tag = Tag(context: context)
            tag.id = id
            tag.name = name
            
            tagsMap[idString] = tag
        }
        
        return tagsMap
    }
    
    private func importHabits(_ habits: [[String: Any]], context: NSManagedObjectContext) -> [String: Habit] {
        var habitsMap: [String: Habit] = [:]
        
        // First fetch all collections for reference
        let collections = CoreDataManager.shared.fetchAllCollections()
        var collectionsById: [String: Collection] = [:]
        for collection in collections {
            if let id = collection.id?.uuidString {
                collectionsById[id] = collection
            }
        }
        
        for habitData in habits {
            guard let idString = habitData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = habitData["name"] as? String else {
                continue
            }
            
            let habit = Habit(context: context)
            habit.id = id
            habit.name = name
            habit.icon = habitData["icon"] as? String
            habit.color = habitData["color"] as? String
            habit.frequency = habitData["frequency"] as? String
            habit.customDays = habitData["customDays"] as? String
            habit.notes = habitData["notes"] as? String
            
            if let startDateTimestamp = habitData["startDate"] as? TimeInterval {
                habit.startDate = Date(timeIntervalSince1970: startDateTimestamp)
            }
            
            if let order = habitData["order"] as? Int32 {
                habit.order = order
            }
            
            // Custom properties
            if let useMultipleStates = habitData["useMultipleStates"] as? Bool {
                habit.setValue(useMultipleStates, forKey: "useMultipleStates")
            }
            
            if let trackDetails = habitData["trackDetails"] as? Bool {
                habit.setValue(trackDetails, forKey: "trackDetails")
            }
            
            if let detailType = habitData["detailType"] as? String {
                habit.setValue(detailType, forKey: "detailType")
            }
            
            // Link to collection
            if let collectionId = habitData["collectionId"] as? String,
               let collection = collectionsById[collectionId] {
                habit.collection = collection
            }
            
            habitsMap[idString] = habit
        }
        
        return habitsMap
    }
    
    private func importHabitEntries(_ entries: [[String: Any]], habitsMap: [String: Habit], context: NSManagedObjectContext) {
        for entryData in entries {
            guard let idString = entryData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let habitIdString = entryData["habitId"] as? String,
                  let habit = habitsMap[habitIdString],
                  let completed = entryData["completed"] as? Bool,
                  let dateTimestamp = entryData["date"] as? TimeInterval else {
                continue
            }
            
            let entry = HabitEntry(context: context)
            entry.id = id
            entry.habit = habit
            entry.completed = completed
            entry.date = Date(timeIntervalSince1970: dateTimestamp)
            entry.details = entryData["details"] as? String
            
            if let completionState = entryData["completionState"] as? Int {
                entry.setValue(completionState, forKey: "completionState")
            }
        }
    }
    
    private func importJournalEntries(_ entries: [[String: Any]], context: NSManagedObjectContext) {
        // First fetch all collections and tags for reference
        let collections = CoreDataManager.shared.fetchAllCollections()
        var collectionsById: [String: Collection] = [:]
        for collection in collections {
            if let id = collection.id?.uuidString {
                collectionsById[id] = collection
            }
        }
        
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        var tagsById: [String: Tag] = [:]
        
        do {
            let tags = try context.fetch(fetchRequest)
            for tag in tags {
                if let id = tag.id?.uuidString {
                    tagsById[id] = tag
                }
            }
        } catch {
            #if DEBUG
            print("Error fetching tags: \(error)")
            #endif
        }
        
        for entryData in entries {
            guard let idString = entryData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let content = entryData["content"] as? String,
                  let entryType = entryData["entryType"] as? String,
                  let dateTimestamp = entryData["date"] as? TimeInterval else {
                continue
            }
            
            let entry = JournalEntry(context: context)
            entry.id = id
            entry.content = content
            entry.entryType = entryType
            entry.date = Date(timeIntervalSince1970: dateTimestamp)
            entry.taskStatus = entryData["taskStatus"] as? String
            entry.priority = entryData["priority"] as? Bool ?? false
            
            // Link to collection
            if let collectionId = entryData["collectionId"] as? String,
               let collection = collectionsById[collectionId] {
                entry.collection = collection
            }
            
            // Add tags
            if let tagIds = entryData["tagIds"] as? [String] {
                for tagId in tagIds {
                    if let tag = tagsById[tagId] {
                        entry.addToTags(tag)
                    }
                }
            }
        }
    }
    
    // Helper for escaping CSV
    private func escapeCSV(_ string: String) -> String {
        var escaped = string
        // Replace double quotes with two double quotes
        escaped = escaped.replacingOccurrences(of: "\"", with: "\"\"")
        // If the string contains a comma, newline, or double quote, wrap it in double quotes
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }
    
    // Date formatting
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // Format date for filenames
    private func formatDateForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
    
    // Convert frequency to readable description
    private func getFrequencyDescription(_ habit: Habit) -> String {
        guard let frequency = habit.frequency else { return "Unknown" }
        
        switch frequency {
        case "daily":
            return "Daily"
        case "weekdays":
            return "Weekdays (Mon-Fri)"
        case "weekends":
            return "Weekends (Sat-Sun)"
        case "weekly":
            return "Weekly"
        case "custom":
            if let customDays = habit.customDays, !customDays.isEmpty {
                return "Custom (\(customDays))"
            } else {
                return "Custom"
            }
        default:
            return frequency.capitalized
        }
    }
    
    // Helper method to determine if a habit should be performed on a given date
    private func shouldPerformHabit(_ habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1 is Sunday, 7 is Saturday
        
        switch habit.frequency {
        case "daily":
            return true
            
        case "weekdays":
            // Weekdays are 2-6 (Monday-Friday)
            return (2...6).contains(weekday)
            
        case "weekends":
            // Weekends are 1 and 7 (Sunday and Saturday)
            return weekday == 1 || weekday == 7
            
        case "weekly":
            // Assume the habit should be done on the same day of the week as it was started
            if let startDate = habit.startDate {
                let startWeekday = calendar.component(.weekday, from: startDate)
                return weekday == startWeekday
            }
            return false
            
        case "custom":
            // Custom days format: "1,3,5" for Sun, Tue, Thu
            let customDays = habit.customDays?.components(separatedBy: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? []
            return customDays.contains(weekday)
            
        default:
            return false
        }
    }
}

// MARK: - CoreDataManager Extension

extension CoreDataManager {
    func clearAllData() {
        let context = container.viewContext
        let entityNames = ["Habit", "HabitEntry", "Collection", "JournalEntry", "Tag"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try container.persistentStoreCoordinator.execute(deleteRequest, with: context)
            } catch {
                #if DEBUG
                print("Error clearing \(entityName) data: \(error)")
                #endif
            }
        }
        
        // Reset context
        context.reset()
    }
}
