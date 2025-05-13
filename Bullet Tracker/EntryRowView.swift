//
//  EntryRowView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

struct EntryRowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var entry: JournalEntry
    @State private var showingEditSheet = false
    
    var body: some View {
        HStack(alignment: .top) {
            // Entry symbol
            if entry.entryType == EntryType.task.rawValue {
                Button(action: toggleTaskStatus) {
                    Text(getSymbol())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(entry.priority ? .red : .primary)
                        .frame(width: 30)
                }
            } else {
                Text(getSymbol())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 30)
            }
            
            // Entry content
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.content ?? "")
                    .strikethrough(entry.taskStatus == TaskStatus.completed.rawValue)
                
                if let tags = entry.tags as? Set<Tag>, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(tags), id: \.self) { tag in
                                Text("#\(tag.name ?? "")")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .frame(height: 24)
                }
            }
            
            Spacer()
            
            Button(action: {
                showingEditSheet = true
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(.gray)
            }
            .padding(.leading)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .sheet(isPresented: $showingEditSheet) {
            EditEntryView(entry: entry)
        }
    }
    
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
    
    private func toggleTaskStatus() {
        if entry.entryType == EntryType.task.rawValue {
            if entry.taskStatus == TaskStatus.completed.rawValue {
                entry.taskStatus = TaskStatus.pending.rawValue
            } else {
                entry.taskStatus = TaskStatus.completed.rawValue
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
}