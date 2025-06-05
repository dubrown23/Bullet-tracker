//
//  SpecialEntryDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/5/25.
//


//
//  SpecialEntryDetailView.swift
//  Bullet Tracker
//
//  Created for Phase 5: Reviews & Outlooks
//

import SwiftUI

struct SpecialEntryDetailView: View {
    // MARK: - Properties
    
    @ObservedObject var entry: JournalEntry
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // MARK: - State
    
    @State private var showingEditSheet = false
    
    // MARK: - Computed Properties
    
    private var entryTitle: String {
        if let targetMonth = entry.targetMonth {
            return SpecialEntryTemplates.title(for: entry.specialEntryType ?? "", month: targetMonth)
        }
        return entry.specialEntryType == "review" ? "Monthly Review" : "Monthly Outlook"
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header info
                    VStack(alignment: .leading, spacing: 8) {
                        if entry.isDraft {
                            Label("Draft", systemImage: "doc.badge.clock")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        if let date = entry.date {
                            Text("Created \(date.formatted(date: .long, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Content
                    Text(entry.content ?? "")
                        .padding(.horizontal)
                        .textSelection(.enabled)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle(entryTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "pencil")
                    }
                }
            }
            .background(
                Color(entry.specialEntryType == "review" 
                      ? UIColor.systemPurple.withAlphaComponent(0.05)
                      : UIColor.systemGreen.withAlphaComponent(0.05))
                .ignoresSafeArea()
            )
        }
        .sheet(isPresented: $showingEditSheet) {
            SpecialEntryEditorView(
                content: Binding(
                    get: { entry.content ?? "" },
                    set: { newContent in
                        entry.content = newContent
                        entry.isDraft = false // Publishing when edited
                        try? viewContext.save()
                    }
                ),
                specialType: entry.specialEntryType ?? "review",
                targetMonth: entry.targetMonth ?? Date(),
                isDraft: Binding(
                    get: { entry.isDraft },
                    set: { entry.isDraft = $0 }
                ),
                onSave: {
                    try? viewContext.save()
                }
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.container.viewContext
    let entry = JournalEntry(context: context)
    entry.content = """
    ## What went well this month:
    - Completed all my planned habits
    - Started a new morning routine
    - Read 3 books
    
    ## Challenges faced:
    - Struggled with consistency on weekends
    - Time management during busy work weeks
    
    ## Key moments to remember:
    - Finally hit my 30-day streak!
    - Discovered meditation really helps
    """
    entry.isSpecialEntry = true
    entry.specialEntryType = "review"
    entry.targetMonth = Date()
    entry.date = Date()
    
    return SpecialEntryDetailView(entry: entry)
        .environment(\.managedObjectContext, context)
}