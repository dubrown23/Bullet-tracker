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
    
    // MARK: - Constants
    
    private enum AgeThreshold {
        static let singleDay = 1
        static let fewDays = 2...3
        static let manyDays = 4
        static let oldTask = 5
    }
    
    private enum Layout {
        static let iconSize: CGFloat = 20
        static let tapTargetSize: CGFloat = 44
        static let cornerRadius: CGFloat = 10
        static let backgroundOpacity: Double = 0.1
        static let tagHeight: CGFloat = 24
        static let verticalPadding: CGFloat = 4
        static let specialEntryPadding: CGFloat = 12
    }
    
    private let maxPreviewLength = 100
    
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
        case AgeThreshold.singleDay:
            return " •"
        case AgeThreshold.fewDays:
            return " ••"
        case AgeThreshold.manyDays...:
            return " •••"
        default:
            return ""
        }
    }
    
    /// Determine if task is old (5+ days)
    private var isOldTask: Bool {
        guard let age = taskAge else { return false }
        return age >= AgeThreshold.oldTask
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
            return String(firstLine.prefix(maxPreviewLength)) + (firstLine.count > maxPreviewLength ? "..." : "")
        }
        return "No content"
    }
    
    /// Get icon name based on entry type and status
    private var iconName: String {
        switch entry.entryType ?? "note" {
        case EntryType.task.rawValue:
            return entry.taskStatus == TaskStatus.completed.rawValue ? "checkmark.circle.fill" : "circle"
        case EntryType.event.rawValue:
            return "calendar"
        default:
            return "note.text"
        }
    }
    
    /// Get icon color based on entry type and status
    private var iconColor: Color {
        switch entry.entryType ?? "note" {
        case EntryType.task.rawValue:
            if entry.taskStatus == TaskStatus.completed.rawValue {
                return .green
            }
            return isOldTask ? .red : (entry.priority ? .red : .blue)
        case EntryType.event.rawValue:
            return .orange
        default:
            return .gray
        }
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
        HStack(alignment: .top, spacing: 8) {
            // Entry icon
            Group {
                if entry.entryType == EntryType.task.rawValue {
                    Button(action: toggleTaskStatus) {
                        Image(systemName: iconName)
                            .font(.system(size: Layout.iconSize))
                            .foregroundStyle(iconColor)
                            .frame(width: Layout.tapTargetSize, height: Layout.tapTargetSize)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Image(systemName: iconName)
                        .font(.system(size: Layout.iconSize))
                        .foregroundStyle(iconColor)
                        .frame(width: Layout.tapTargetSize, height: Layout.tapTargetSize)
                }
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
            
            Button(action: { showingEditSheet = true }) {
                Image(systemName: "pencil")
                    .foregroundStyle(.gray)
                    .frame(width: Layout.tapTargetSize, height: Layout.tapTargetSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, Layout.verticalPadding)
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
            .padding(.vertical, Layout.specialEntryPadding)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius)
                    .fill(entry.specialEntryType == "review"
                          ? Color.purple.opacity(Layout.backgroundOpacity)
                          : Color.green.opacity(Layout.backgroundOpacity))
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
                        .background(Color.blue.opacity(Layout.backgroundOpacity))
                        .cornerRadius(4)
                }
            }
        }
        .frame(height: Layout.tagHeight)
    }
    
    // MARK: - Helper Methods
    
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
            // Handle error silently in production
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
