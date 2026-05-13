//
//  JournalJSONExporter.swift
//  Bullet Tracker
//
//  JSON export for journal data backup.
//

import Foundation
import SwiftData

struct JournalJSONExporter {

    private static let iso8601Formatter = ISO8601DateFormatter()

    static func exportJournalData(startDate: Date, endDate: Date, in context: ModelContext) -> Data? {
        let calendar = Calendar.current
        guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDate) else { return nil }

        var exportData: [String: Any] = [
            "exportDate": iso8601Formatter.string(from: Date()),
            "startDate": iso8601Formatter.string(from: startDate),
            "endDate": iso8601Formatter.string(from: endDate),
            "version": 1
        ]

        // Export habit entries (completed only) within the range, ordered by date then habit order.
        let allEntries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []
        let entries = allEntries
            .filter { entry in
                entry.date >= startDate && entry.date < endOfRange && entry.completionState != .notDone
            }
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return (lhs.habit?.order ?? 0) < (rhs.habit?.order ?? 0)
            }

        var habitsArray: [[String: Any]] = []
        for entry in entries {
            guard let habit = entry.habit else { continue }

            var entryDict: [String: Any] = [
                "date": iso8601Formatter.string(from: entry.date),
                "habitName": habit.name ?? "",
                "habitIcon": habit.icon ?? "",
                "habitColor": habit.color ?? "",
                "completionState": entry.completionState.rawValue,
                "completionStyle": habit.completionStyle.rawValue
            ]

            // Encode the typed details payload back to a JSON-friendly dictionary
            // so the exported file stays a plain `[String: Any]` JSON object.
            if let details = entry.details,
               let payload = jsonifyDetails(details) {
                entryDict["details"] = payload
            }

            habitsArray.append(entryDict)
        }
        exportData["habitEntries"] = habitsArray

        // Export notes within the range, ordered by date.
        let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        let notes = allNotes
            .filter { note in
                guard let date = note.date else { return false }
                return date >= startDate && date < endOfRange
            }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }

        var notesArray: [[String: Any]] = []
        for note in notes {
            notesArray.append([
                "date": iso8601Formatter.string(from: note.date ?? Date()),
                "content": note.content ?? ""
            ])
        }
        exportData["notes"] = notesArray

        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }

    /// Convert a typed `HabitEntryDetails` payload to a JSON-serialisable dictionary
    /// (mirrors the shape the old `details: String` JSON blob carried, so any
    /// downstream tool that parsed those exports still reads the new ones).
    private static func jsonifyDetails(_ details: HabitEntryDetails) -> [String: Any]? {
        switch details {
        case .notes(let notes):
            return ["notes": notes]
        case .workout(let types, let duration, let intensity, let notes):
            return [
                "types": types,
                "type": types.first ?? "",
                "duration": duration,
                "intensity": intensity,
                "notes": notes
            ]
        case .reading(let bookTitle, let pagesRead, let notes):
            return [
                "bookTitle": bookTitle,
                "pagesRead": pagesRead,
                "notes": notes
            ]
        case .mood(let mood, let notes):
            return [
                "mood": mood,
                "notes": notes
            ]
        }
    }
}
