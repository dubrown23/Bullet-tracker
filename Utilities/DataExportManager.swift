//
//  DataExportManager.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/13/25.
//

import Foundation
import CoreData
import UIKit

struct DataExportManager {
    static let shared = DataExportManager()
    
    // MARK: - Constants
    
    enum Constants {
        static let habitCSVHeader = "Name,Icon,Color,Frequency,CustomDays,StartDate,Notes,MultiState,TrackDetails,DetailType,Order\n"
        static let entryCSVHeader = "HabitName,Date,Completed,CompletionState,Details\n"
        static let filePrefix = "BulletTracker"
        static let entityNames = ["Habit", "HabitEntry", "Collection", "JournalEntry", "Tag"]
        static let backupVersion = 1
    }
    
    // MARK: - Static Formatters
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    private static let filenameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
    
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    // MARK: - CSV Export
    
    func exportHabitsToCSV() -> URL? {
        let habits = CoreDataManager.shared.fetchAllHabits()
        var csvString = Constants.habitCSVHeader
        
        for habit in habits {
            let row = createHabitCSVRow(habit)
            csvString.append(row.joined(separator: ",") + "\n")
        }
        
        return saveToTempFile(csvString, prefix: "Habits")
    }
    
    func exportHabitsToCSVWithStats() -> URL? {
        let habits = CoreDataManager.shared.fetchAllHabits()
        var csvString = Constants.habitCSVHeader
        
        for habit in habits {
            let row = createHabitCSVRow(habit)
            csvString.append(row.joined(separator: ",") + "\n")
        }
        
        // Add summary statistics
        csvString.append("\n# Summary Statistics\n")
        csvString.append("Total Habits,\(habits.count)\n")
        
        let frequencies = ["daily", "weekdays", "weekends", "weekly", "custom"]
        let labels = ["Daily", "Weekday", "Weekend", "Weekly", "Custom Schedule"]
        
        for (frequency, label) in zip(frequencies, labels) {
            let count = habits.filter { $0.frequency == frequency }.count
            csvString.append("\(label) Habits,\(count)\n")
        }
        
        return saveToTempFile(csvString, prefix: "Habits")
    }
    
    func exportHabitEntriesToCSV() -> URL? {
        let habits = CoreDataManager.shared.fetchAllHabits()
        var csvString = Constants.entryCSVHeader
        
        for habit in habits {
            if let entries = habit.entries as? Set<HabitEntry> {
                for entry in entries {
                    let row = createEntryCSVRow(habit: habit, entry: entry)
                    csvString.append(row.joined(separator: ",") + "\n")
                }
            }
        }
        
        return saveToTempFile(csvString, prefix: "HabitEntries")
    }
    
    func exportMonthlyReport(for date: Date) -> URL? {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return nil
        }
        
        let habits = CoreDataManager.shared.fetchAllHabits()
        let monthTitle = Self.monthYearFormatter.string(from: date)
        
        var csvString = "Monthly Habit Report - \(monthTitle)\n\n"
        
        if habits.isEmpty {
            csvString.append("No habits found in the system. Add habits to generate a detailed report.\n")
            return saveToTempFile(csvString, prefix: "MonthlyReport", date: date)
        }
        
        csvString.append("Habit Name,Frequency,Success Rate,Success,Partial,Failed\n")
        
        let entries = getHabitEntriesForRange(start: startOfMonth, end: endOfMonth)
        var totalExpected = 0
        var totalSuccess = 0
        var habitStats: [(Habit, Double)] = []
        
        for habit in habits {
            let stats = calculateHabitStats(habit: habit, entries: entries, startDate: startOfMonth, endDate: endOfMonth)
            totalExpected += stats.expected
            totalSuccess += stats.success
            
            if stats.expected > 0 {
                habitStats.append((habit, Double(stats.success) / Double(stats.expected)))
            }
            
            let row = createMonthlyReportRow(habit: habit, stats: stats)
            csvString.append(row.joined(separator: ",") + "\n")
        }
        
        // Add summary
        csvString.append("\n# Month Summary\n")
        csvString.append("Total Expected Completions,\(totalExpected)\n")
        csvString.append("Total Actual Completions,\(entries.count)\n")
        
        let overallRate = totalExpected > 0 ? Double(totalSuccess) / Double(totalExpected) : 0
        csvString.append("Overall Success Rate,\(String(format: "%.1f%%", overallRate * 100))\n")
        csvString.append("Overall Completion Fraction,\(totalSuccess)/\(totalExpected)\n")
        
        // Add best/worst habits
        habitStats.sort { $0.1 > $1.1 }
        if let best = habitStats.first {
            csvString.append("Most Successful Habit,\(escapeCSV(best.0.name ?? "")),\(String(format: "%.1f%%", best.1 * 100))\n")
        }
        if habitStats.count > 1, let worst = habitStats.last {
            csvString.append("Least Successful Habit,\(escapeCSV(worst.0.name ?? "")),\(String(format: "%.1f%%", worst.1 * 100))\n")
        }
        
        return saveToTempFile(csvString, prefix: "MonthlyReport", date: date)
    }
    
    // MARK: - JSON Export/Import
    
    func exportAppDataToJSON() -> URL? {
        let appData = createAppDataDictionary()
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: appData, options: .prettyPrinted)
            let fileName = "\(Constants.filePrefix)_Backup_\(Self.filenameDateFormatter.string(from: Date())).json"
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }
    
    func importAppDataFromJSON(url: URL, completion: @escaping (Bool, String) -> Void) {
        do {
            let jsonData = try Data(contentsOf: url)
            guard let appData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                completion(false, "Invalid JSON format")
                return
            }
            
            CoreDataManager.shared.clearAllData()
            let result = restoreAppDataFromDictionary(appData)
            completion(result.success, result.message)
        } catch {
            completion(false, "Error reading JSON file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Share
    
    func shareFile(url: URL, from viewController: UIViewController, sourceView: UIView? = nil) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let sourceView = sourceView {
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        }
        
        viewController.present(activityVC, animated: true)
    }
    
    // MARK: - Private Helper Methods
    
    private func createHabitCSVRow(_ habit: Habit) -> [String] {
        [
            escapeCSV(habit.name ?? ""),
            escapeCSV(habit.icon ?? ""),
            escapeCSV(habit.color ?? ""),
            escapeCSV(habit.frequency ?? ""),
            escapeCSV(habit.customDays ?? ""),
            Self.dateFormatter.string(from: habit.startDate ?? Date()),
            escapeCSV(habit.notes ?? ""),
            "\(habit.value(forKey: "useMultipleStates") as? Bool ?? false)",
            "\(habit.value(forKey: "trackDetails") as? Bool ?? false)",
            escapeCSV(habit.value(forKey: "detailType") as? String ?? ""),
            "\(habit.order)"
        ]
    }
    
    private func createEntryCSVRow(habit: Habit, entry: HabitEntry) -> [String] {
        [
            escapeCSV(habit.name ?? ""),
            Self.dateFormatter.string(from: entry.date ?? Date()),
            "\(entry.completed)",
            "\(entry.value(forKey: "completionState") as? Int ?? 1)",
            escapeCSV(entry.details ?? "")
        ]
    }
    
    private func createMonthlyReportRow(habit: Habit, stats: HabitStats) -> [String] {
        let successRate = stats.expected > 0 ? Double(stats.success) / Double(stats.expected) : 0
        let successRateFormatted = String(format: "%.1f%%", successRate * 100)
        
        if habit.value(forKey: "useMultipleStates") as? Bool ?? false {
            return [
                escapeCSV(habit.name ?? ""),
                escapeCSV(getFrequencyDescription(habit)),
                successRateFormatted,
                "\(stats.success)/\(stats.expected)",
                "\(stats.partial)/\(stats.expected)",
                "\(stats.failed)/\(stats.expected)"
            ]
        } else {
            return [
                escapeCSV(habit.name ?? ""),
                escapeCSV(getFrequencyDescription(habit)),
                successRateFormatted,
                "\(stats.success)/\(stats.expected)",
                "",
                ""
            ]
        }
    }
    
    private func saveToTempFile(_ content: String, prefix: String, date: Date = Date()) -> URL? {
        let dateString = Self.filenameDateFormatter.string(from: date)
        let fileName = "\(Constants.filePrefix)_\(prefix)_\(dateString).csv"
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            return nil
        }
    }
    
    private func getHabitEntriesForRange(start: Date, end: Date) -> [HabitEntry] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: start)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: end) else { return [] }
        
        let context = CoreDataManager.shared.container.viewContext
        let fetchRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startOfDay as NSDate, endOfDay as NSDate)
        
        do {
            return try context.fetch(fetchRequest)
        } catch {
            return []
        }
    }
    
    private struct HabitStats {
        let expected: Int
        let success: Int
        let partial: Int
        let failed: Int
    }
    
    private func calculateHabitStats(habit: Habit, entries: [HabitEntry], startDate: Date, endDate: Date) -> HabitStats {
        guard let habitId = habit.id else { return HabitStats(expected: 0, success: 0, partial: 0, failed: 0) }
        
        let calendar = Calendar.current
        var expected = 0
        var currentDate = startDate
        
        while currentDate <= endDate {
            if shouldPerformHabit(habit, on: currentDate) {
                expected += 1
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        let habitEntries = entries.filter { $0.habit?.id == habitId }
        let useMultipleStates = habit.value(forKey: "useMultipleStates") as? Bool ?? false
        
        var success = 0
        var partial = 0
        var failed = 0
        
        if useMultipleStates {
            for entry in habitEntries {
                switch entry.value(forKey: "completionState") as? Int ?? 1 {
                case 1: success += 1
                case 2: partial += 1
                case 3: failed += 1
                default: break
                }
            }
        } else {
            success = habitEntries.count
        }
        
        return HabitStats(expected: expected, success: success, partial: partial, failed: failed)
    }
    
    private func createAppDataDictionary() -> [String: Any] {
        [
            "version": Constants.backupVersion,
            "timestamp": Date().timeIntervalSince1970,
            "habits": exportHabitsToDict(),
            "habitEntries": exportHabitEntriesToDict(),
            "collections": exportCollectionsToDict(),
            "journalEntries": exportJournalEntriesToDict(),
            "tags": exportTagsToDict()
        ]
    }
    
    private func restoreAppDataFromDictionary(_ data: [String: Any]) -> (success: Bool, message: String) {
        guard let version = data["version"] as? Int, version == Constants.backupVersion else {
            return (false, "Unsupported backup version")
        }
        
        let context = CoreDataManager.shared.container.viewContext
        
        var collectionsMap: [String: Collection] = [:]
        var tagsMap: [String: Tag] = [:]
        var habitsMap: [String: Habit] = [:]
        
        // Import in dependency order
        if let collectionsData = data["collections"] as? [[String: Any]] {
            collectionsMap = importCollections(collectionsData, context: context)
        }
        
        if let tagsData = data["tags"] as? [[String: Any]] {
            tagsMap = importTags(tagsData, context: context)
        }
        
        if let habitsData = data["habits"] as? [[String: Any]] {
            habitsMap = importHabits(habitsData, collectionsMap: collectionsMap, context: context)
        }
        
        if let entriesData = data["habitEntries"] as? [[String: Any]] {
            importHabitEntries(entriesData, habitsMap: habitsMap, context: context)
        }
        
        if let journalData = data["journalEntries"] as? [[String: Any]] {
            importJournalEntries(journalData, collectionsMap: collectionsMap, tagsMap: tagsMap, context: context)
        }
        
        do {
            try context.save()
            return (true, "Data imported successfully")
        } catch {
            return (false, "Error saving data: \(error.localizedDescription)")
        }
    }
    
    // Export helpers
    private func exportHabitsToDict() -> [[String: Any]] {
        CoreDataManager.shared.fetchAllHabits().compactMap { habit in
            guard let id = habit.id else { return nil }
            
            var dict: [String: Any] = [
                "id": id.uuidString,
                "name": habit.name ?? "",
                "icon": habit.icon ?? "",
                "color": habit.color ?? "",
                "frequency": habit.frequency ?? "",
                "customDays": habit.customDays ?? "",
                "order": habit.order
            ]
            
            if let startDate = habit.startDate {
                dict["startDate"] = startDate.timeIntervalSince1970
            }
            
            if let notes = habit.notes {
                dict["notes"] = notes
            }
            
            // Dynamic properties
            ["useMultipleStates", "trackDetails", "detailType"].forEach { key in
                if let value = habit.value(forKey: key) {
                    dict[key] = value
                }
            }
            
            if let collectionId = habit.collection?.id {
                dict["collectionId"] = collectionId.uuidString
            }
            
            return dict
        }
    }
    
    private func exportHabitEntriesToDict() -> [[String: Any]] {
        CoreDataManager.shared.fetchAllHabits().flatMap { habit -> [[String: Any]] in
            guard let habitId = habit.id,
                  let entries = habit.entries as? Set<HabitEntry> else { return [] }
            
            return entries.compactMap { entry in
                guard let entryId = entry.id else { return nil }
                
                var dict: [String: Any] = [
                    "id": entryId.uuidString,
                    "habitId": habitId.uuidString,
                    "completed": entry.completed
                ]
                
                if let date = entry.date {
                    dict["date"] = date.timeIntervalSince1970
                }
                
                if let completionState = entry.value(forKey: "completionState") as? Int {
                    dict["completionState"] = completionState
                }
                
                if let details = entry.details {
                    dict["details"] = details
                }
                
                return dict
            }
        }
    }
    
    private func exportCollectionsToDict() -> [[String: Any]] {
        CoreDataManager.shared.fetchAllCollections().compactMap { collection in
            guard let id = collection.id else { return nil }
            return [
                "id": id.uuidString,
                "name": collection.name ?? ""
            ]
        }
    }
    
    private func exportJournalEntriesToDict() -> [[String: Any]] {
        let fetchRequest: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        
        do {
            return try CoreDataManager.shared.container.viewContext.fetch(fetchRequest).compactMap { entry in
                guard let id = entry.id else { return nil }
                
                var dict: [String: Any] = [
                    "id": id.uuidString,
                    "content": entry.content ?? "",
                    "entryType": entry.entryType ?? "",
                    "priority": entry.priority
                ]
                
                if let date = entry.date {
                    dict["date"] = date.timeIntervalSince1970
                }
                
                if let taskStatus = entry.taskStatus {
                    dict["taskStatus"] = taskStatus
                }
                
                if let collectionId = entry.collection?.id {
                    dict["collectionId"] = collectionId.uuidString
                }
                
                if let tags = entry.tags as? Set<Tag> {
                    dict["tagIds"] = tags.compactMap { $0.id?.uuidString }
                }
                
                return dict
            }
        } catch {
            return []
        }
    }
    
    private func exportTagsToDict() -> [[String: Any]] {
        let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        
        do {
            return try CoreDataManager.shared.container.viewContext.fetch(fetchRequest).compactMap { tag in
                guard let id = tag.id else { return nil }
                return [
                    "id": id.uuidString,
                    "name": tag.name ?? ""
                ]
            }
        } catch {
            return []
        }
    }
    
    // Import helpers
    private func importCollections(_ data: [[String: Any]], context: NSManagedObjectContext) -> [String: Collection] {
        var map: [String: Collection] = [:]
        
        for item in data {
            guard let idString = item["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = item["name"] as? String else { continue }
            
            let collection = Collection(context: context)
            collection.id = id
            collection.name = name
            map[idString] = collection
        }
        
        return map
    }
    
    private func importTags(_ data: [[String: Any]], context: NSManagedObjectContext) -> [String: Tag] {
        var map: [String: Tag] = [:]
        
        for item in data {
            guard let idString = item["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = item["name"] as? String else { continue }
            
            let tag = Tag(context: context)
            tag.id = id
            tag.name = name
            map[idString] = tag
        }
        
        return map
    }
    
    private func importHabits(_ data: [[String: Any]], collectionsMap: [String: Collection], context: NSManagedObjectContext) -> [String: Habit] {
        var map: [String: Habit] = [:]
        
        for item in data {
            guard let idString = item["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let name = item["name"] as? String else { continue }
            
            let habit = Habit(context: context)
            habit.id = id
            habit.name = name
            habit.icon = item["icon"] as? String
            habit.color = item["color"] as? String
            habit.frequency = item["frequency"] as? String
            habit.customDays = item["customDays"] as? String
            habit.notes = item["notes"] as? String
            
            if let timestamp = item["startDate"] as? TimeInterval {
                habit.startDate = Date(timeIntervalSince1970: timestamp)
            }
            
            if let order = item["order"] as? Int32 {
                habit.order = order
            }
            
            // Dynamic properties
            ["useMultipleStates", "trackDetails", "detailType"].forEach { key in
                if let value = item[key] {
                    habit.setValue(value, forKey: key)
                }
            }
            
            if let collectionId = item["collectionId"] as? String,
               let collection = collectionsMap[collectionId] {
                habit.collection = collection
            }
            
            map[idString] = habit
        }
        
        return map
    }
    
    private func importHabitEntries(_ data: [[String: Any]], habitsMap: [String: Habit], context: NSManagedObjectContext) {
        for item in data {
            guard let idString = item["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let habitId = item["habitId"] as? String,
                  let habit = habitsMap[habitId],
                  let completed = item["completed"] as? Bool,
                  let timestamp = item["date"] as? TimeInterval else { continue }
            
            let entry = HabitEntry(context: context)
            entry.id = id
            entry.habit = habit
            entry.completed = completed
            entry.date = Date(timeIntervalSince1970: timestamp)
            entry.details = item["details"] as? String
            
            if let completionState = item["completionState"] as? Int {
                entry.setValue(completionState, forKey: "completionState")
            }
        }
    }
    
    private func importJournalEntries(_ data: [[String: Any]], collectionsMap: [String: Collection], tagsMap: [String: Tag], context: NSManagedObjectContext) {
        for item in data {
            guard let idString = item["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let content = item["content"] as? String,
                  let entryType = item["entryType"] as? String,
                  let timestamp = item["date"] as? TimeInterval else { continue }
            
            let entry = JournalEntry(context: context)
            entry.id = id
            entry.content = content
            entry.entryType = entryType
            entry.date = Date(timeIntervalSince1970: timestamp)
            entry.taskStatus = item["taskStatus"] as? String
            entry.priority = item["priority"] as? Bool ?? false
            
            if let collectionId = item["collectionId"] as? String,
               let collection = collectionsMap[collectionId] {
                entry.collection = collection
            }
            
            if let tagIds = item["tagIds"] as? [String] {
                for tagId in tagIds {
                    if let tag = tagsMap[tagId] {
                        entry.addToTags(tag)
                    }
                }
            }
        }
    }
    
    // Utility methods
    private func escapeCSV(_ string: String) -> String {
        var escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            escaped = "\"\(escaped)\""
        }
        return escaped
    }
    
    private func getFrequencyDescription(_ habit: Habit) -> String {
        guard let frequency = habit.frequency else { return "Unknown" }
        
        switch frequency {
        case "daily": return "Daily"
        case "weekdays": return "Weekdays (Mon-Fri)"
        case "weekends": return "Weekends (Sat-Sun)"
        case "weekly": return "Weekly"
        case "custom":
            if let customDays = habit.customDays, !customDays.isEmpty {
                return "Custom (\(customDays))"
            }
            return "Custom"
        default: return frequency.capitalized
        }
    }
    
    private func shouldPerformHabit(_ habit: Habit, on date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        switch habit.frequency {
        case "daily":
            return true
        case "weekdays":
            return (2...6).contains(weekday)
        case "weekends":
            return weekday == 1 || weekday == 7
        case "weekly":
            if let startDate = habit.startDate {
                return calendar.component(.weekday, from: startDate) == weekday
            }
            return false
        case "custom":
            let days = habit.customDays?.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) } ?? []
            return days.contains(weekday)
        default:
            return false
        }
    }
}

// MARK: - CoreDataManager Extension

extension CoreDataManager {
    func clearAllData() {
        let context = container.viewContext
        
        for entityName in DataExportManager.Constants.entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try container.persistentStoreCoordinator.execute(deleteRequest, with: context)
            } catch {
                // Handle silently
            }
        }
        
        context.reset()
    }
}
