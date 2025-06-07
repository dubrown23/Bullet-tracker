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
    
    // MARK: - Constants
    
    private enum EntryType {
        static let task = "task"
        static let event = "event"
        static let note = "note"
    }
    
    private enum TaskStatus {
        static let completed = "completed"
    }
    
    private let maxTagsToShow = 3
    
    // MARK: - Static Formatters
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    // MARK: - Computed Properties
    
    private var entryIcon: String {
        switch entry.entryType {
        case EntryType.task:
            return entry.taskStatus == TaskStatus.completed ? "checkmark.circle.fill" : "circle"
        case EntryType.event:
            return "calendar"
        default:
            return "note.text"
        }
    }
    
    private var entryColor: Color {
        switch entry.entryType {
        case EntryType.task:
            return entry.taskStatus == TaskStatus.completed ? .green : (entry.priority ? .red : .primary)
        case EntryType.event:
            return .blue
        default:
            return .gray
        }
    }
    
    private var tags: [Tag] {
        guard let tagSet = entry.tags as? Set<Tag> else { return [] }
        return Array(tagSet)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: entryIcon)
                    .foregroundStyle(entryColor)
                    .font(.headline)
                
                Text(entry.content ?? "")
                    .strikethrough(entry.taskStatus == TaskStatus.completed)
            }
            
            HStack {
                // Date
                if let date = entry.date {
                    Text(date, formatter: Self.dateFormatter)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Tags
                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(maxTagsToShow), id: \.self) { tag in
                            Text("#\(tag.name ?? "")")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        
                        if tags.count > maxTagsToShow {
                            Text("+\(tags.count - maxTagsToShow) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
