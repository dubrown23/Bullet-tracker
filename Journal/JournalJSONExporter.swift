//
//  JournalJSONExporter.swift
//  Bullet Tracker
//
//  JSON export for journal data backup
//

import Foundation
import CoreData

struct JournalJSONExporter {

    private static let iso8601Formatter = ISO8601DateFormatter()

    static func exportJournalData(startDate: Date, endDate: Date) -> Data? {
        let context = CoreDataManager.shared.container.viewContext
        let calendar = Calendar.current
        guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDate) else { return nil }

        var exportData: [String: Any] = [
            "exportDate": iso8601Formatter.string(from: Date()),
            "startDate": iso8601Formatter.string(from: startDate),
            "endDate": iso8601Formatter.string(from: endDate),
            "version": 1
        ]

        // Export habits
        var habitsArray: [[String: Any]] = []
        let habitRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        habitRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND completionState > 0",
            startDate as NSDate, endOfRange as NSDate
        )
        habitRequest.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: true),
            NSSortDescriptor(key: "habit.order", ascending: true)
        ]

        if let entries = try? context.fetch(habitRequest) {
            for entry in entries {
                guard let habit = entry.habit else { continue }

                var entryDict: [String: Any] = [
                    "date": iso8601Formatter.string(from: entry.date ?? Date()),
                    "habitName": habit.name ?? "",
                    "habitIcon": habit.icon ?? "",
                    "habitColor": habit.color ?? "",
                    "completionState": entry.completionState,
                    "isNegativeHabit": habit.isNegativeHabit
                ]

                if let details = entry.details {
                    entryDict["details"] = details
                }

                habitsArray.append(entryDict)
            }
        }
        exportData["habitEntries"] = habitsArray

        // Export notes
        var notesArray: [[String: Any]] = []
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startDate as NSDate, endOfRange as NSDate
        )
        noteRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        if let notes = try? context.fetch(noteRequest) {
            for note in notes {
                notesArray.append([
                    "date": iso8601Formatter.string(from: note.date ?? Date()),
                    "content": note.content ?? ""
                ])
            }
        }
        exportData["notes"] = notesArray

        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
}
