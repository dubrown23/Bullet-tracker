//
//  EntryRowView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

struct EntryRowView: View {
    // MARK: - Environment Properties
    
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - Properties
    
    @ObservedObject var entry: JournalEntry
    
    // MARK: - State Properties
    
    @State private var showingEditSheet = false
    @State private var showingDetailView = false
    
    // MARK: - Computed Properties
    
    /// Calculate age of task in days
    private var taskAge: Int? {
        guard let originalDate = entry.originalDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: originalDate, to: Date()).day ?? 0
        return days
    }
    
    /// Get age indicator dots based on task age
    private var ageIndicator: String {
        guard let age = taskAge else { return "" }
        switch age {
        case 1:
            return " •"
        case 2...3:
            return " ••"
        case 4...:
            return " •••"
        default:
            return ""
        }
    }
    
    /// Determine if task is old (5+ days)
    private var isOldTask: Bool {
        guard let age = taskAge else { return false }
        return age >= 5
    }
    
    /// Check if this is a special entry (review or outlook)
    private var isSpecialEntry: Bool {
        entry.isSpecialEntry
    }
    
    /// Get preview text for special entries
    private var specialEntryPreview: String {
        guard isSpecialEntry else { return "" }
        let content = entry.content ?? ""
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        if let firstLine = lines.first {
            return String(firstLine.prefix(100)) + (firstLine.count > 100 ? "..." : "")
        }
        return "No content"
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isSpecialEntry {
                specialEntryRow
            } else {
                regularEntryRow
            }
        }
    }
    
    // MARK: - Regular Entry Row
    
    private var regularEntryRow: some View {
        HStack(alignment: .top) {
            // Entry icon - using our digital system
            if entry.entryType == EntryType.task.rawValue {
                Button(action: toggleTaskStatus) {
                    Image(systemName: getIcon())
                        .font(.system(size: 18))
                        .foregroundStyle(getIconColor())
                        .frame(width: 30)
                }
            } else {
                Image(systemName: getIcon())
                    .font(.system(size: 18))
                    .foregroundStyle(getIconColor())
                    .frame(width: 30)
            }
            
            // Entry content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.content ?? "")
                        .strikethrough(entry.taskStatus == TaskStatus.completed.rawValue)
                        .foregroundStyle(isOldTask ? .orange : .primary)
                    
                    // Age indicator dots
                    if !ageIndicator.isEmpty {
                        Text(ageIndicator)
                            .foregroundStyle(isOldTask ? .red : .secondary)
                            .font(.caption)
                    }
                }
                
                // Original date for migrated tasks
                if let originalDate = entry.originalDate {
                    Text("from \(originalDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let tags = entry.tags as? Set<Tag>, !tags.isEmpty {
                    tagScrollView(tags: tags)
                }
            }
            
            Spacer()
            
            Button(action: {
                showingEditSheet = true
            }) {
                Image(systemName: "pencil")
                    .foregroundStyle(.gray)
            }
            .padding(.leading)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .sheet(isPresented: $showingEditSheet) {
            EditEntryView(entry: entry)
        }
    }
    
    // MARK: - Special Entry Row (Reviews & Outlooks)
    
    private var specialEntryRow: some View {
        Button(action: { showingDetailView = true }) {
            HStack(alignment: .top, spacing: 12) {
                // Special entry icon
                Text(entry.specialEntryType == "review" ? "📝" : "📅")
                    .font(.title2)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 6) {
                    // Title with month
                    if let targetMonth = entry.targetMonth {
                        Text(SpecialEntryTemplates.title(for: entry.specialEntryType ?? "", month: targetMonth))
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    // Draft indicator
                    if entry.isDraft {
                        Label("Draft", systemImage: "doc.badge.clock")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    // Content preview
                    Text(specialEntryPreview)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    // Date created
                    if let date = entry.date {
                        Text("Created \(date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Read more indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(entry.specialEntryType == "review"
                          ? Color.purple.opacity(0.1)
                          : Color.green.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetailView) {
            SpecialEntryDetailView(entry: entry)
        }
    }
    
    // MARK: - View Components
    
    /// Horizontal scrolling view for tags
    private func tagScrollView(tags: Set<Tag>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Array(tags), id: \.self) { tag in
                    Text("#\(tag.name ?? "")")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .frame(height: 24)
    }
    
    // MARK: - Helper Methods
    
    /// Returns the appropriate SF Symbol icon for the entry type
    private func getIcon() -> String {
        switch entry.entryType ?? "note" {
        case EntryType.task.rawValue:
            if entry.taskStatus == TaskStatus.completed.rawValue {
                return "checkmark.circle.fill"
            } else {
                return "circle"
            }
        case EntryType.event.rawValue:
            return "calendar"
        case EntryType.note.rawValue:
            return "note.text"
        default:
            return "note.text"
        }
    }
    
    /// Returns the appropriate color for the icon
    private func getIconColor() -> Color {
        switch entry.entryType ?? "note" {
        case EntryType.task.rawValue:
            if entry.taskStatus == TaskStatus.completed.rawValue {
                return .green
            } else {
                // Use orange/red for old tasks
                if isOldTask {
                    return .red
                }
                return entry.priority ? .red : .blue
            }
        case EntryType.event.rawValue:
            return .orange
        case EntryType.note.rawValue:
            return .gray
        default:
            return .gray
        }
    }
    
    /// Returns the traditional bullet journal symbol (kept for reference but not used)
    private func getSymbol() -> String {
        if entry.entryType == EntryType.task.rawValue {
            if let status = entry.taskStatus {
                return TaskStatus(rawValue: status)?.symbol ?? EntryType.task.symbol
            }
            return EntryType.task.symbol
        } else if let type = EntryType(rawValue: entry.entryType ?? "") {
            return type.symbol
        }
        return "•" // Default
    }
    
    /// Toggles the task completion status
    private func toggleTaskStatus() {
        guard entry.entryType == EntryType.task.rawValue else { return }
        
        if entry.taskStatus == TaskStatus.completed.rawValue {
            entry.taskStatus = TaskStatus.pending.rawValue
        } else {
            entry.taskStatus = TaskStatus.completed.rawValue
        }
        
        do {
            try viewContext.save()
        } catch {
            #if DEBUG
            print("Error saving context: \(error)")
            #endif
        }
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let entry = JournalEntry(context: context)
    entry.content = "→ Sample migrated task"
    entry.entryType = "task"
    entry.taskStatus = "pending"
    entry.originalDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
    
    return EntryRowView(entry: entry)
        .environment(\.managedObjectContext, context)
        .padding()
}
