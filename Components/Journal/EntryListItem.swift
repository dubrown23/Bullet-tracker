//
//  EntryListItem.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI
import CoreData

struct EntryListItem: View {
    // MARK: - Properties
    
    @ObservedObject var entry: JournalEntry
    
    // MARK: - Computed Properties
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Symbol based on entry type
                getEntryTypeIcon()
                    .foregroundStyle(getEntryColor())
                    .font(.headline)
                
                Text(entry.content ?? "")
                    .strikethrough(entry.taskStatus == "completed")
            }
            
            HStack {
                // Date
                if let date = entry.date {
                    Text(dateFormatter.string(from: date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Tags
                if let tags = entry.tags as? Set<Tag>, !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(tags).prefix(3), id: \.self) { tag in
                            Text("#\(tag.name ?? "")")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        
                        if tags.count > 3 {
                            Text("+\(tags.count - 3) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    /// Returns the appropriate SF Symbol icon for the entry type
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
    
    /// Returns the appropriate color for the entry based on type and status
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
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let entry = JournalEntry(context: context)
    entry.content = "Sample task"
    entry.entryType = "task"
    entry.date = Date()
    
    return EntryListItem(entry: entry)
        .padding()
}
