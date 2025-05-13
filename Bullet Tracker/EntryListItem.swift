//
//  EntryListItem.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI
import CoreData

// Helper view for entry list items
struct EntryListItem: View {
    @ObservedObject var entry: JournalEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Symbol based on entry type
                getEntryTypeIcon()
                    .foregroundColor(getEntryColor())
                    .font(.headline)
                
                Text(entry.content ?? "")
                    .strikethrough(entry.taskStatus == "completed")
            }
            
            HStack {
                // Date
                if let date = entry.date {
                    Text(dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Tags
                if let tags = entry.tags as? Set<Tag>, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(tags).prefix(3), id: \.self) { tag in
                            Text("#\(tag.name ?? "")")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        
                        if tags.count > 3 {
                            Text("+\(tags.count - 3) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getEntryTypeIcon() -> some View {
        switch entry.entryType {
        case "task":
            return Image(systemName: entry.taskStatus == "completed" ? "checkmark.circle.fill" : "circle")
        case "event":
            return Image(systemName: "calendar")
        default: // note
            return Image(systemName: "note.text")
        }
    }
    
    private func getEntryColor() -> Color {
        switch entry.entryType {
        case "task":
            return entry.taskStatus == "completed" ? .green : (entry.priority ? .red : .primary)
        case "event":
            return .blue
        default: // note
            return .gray
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}