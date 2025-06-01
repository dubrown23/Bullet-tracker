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
    
    // MARK: - Body
    
    var body: some View {
        HStack(alignment: .top) {
            // Entry symbol
            if entry.entryType == EntryType.task.rawValue {
                Button(action: toggleTaskStatus) {
                    Text(getSymbol())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(entry.priority ? .red : .primary)
                        .frame(width: 30)
                }
            } else {
                Text(getSymbol())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 30)
            }
            
            // Entry content
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.content ?? "")
                    .strikethrough(entry.taskStatus == TaskStatus.completed.rawValue)
                
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
    
    /// Returns the appropriate symbol for the entry type and status
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
    entry.content = "Sample task"
    entry.entryType = "task"
    entry.taskStatus = "pending"
    
    return EntryRowView(entry: entry)
        .environment(\.managedObjectContext, context)
        .padding()
}
