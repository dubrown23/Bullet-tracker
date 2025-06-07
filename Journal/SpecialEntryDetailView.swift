//
//  SpecialEntryDetailView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/5/25.
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
    
    // MARK: - Constants
    
    private enum Layout {
        static let verticalSpacing: CGFloat = 20
        static let headerSpacing: CGFloat = 8
        static let minSpacerHeight: CGFloat = 50
        static let backgroundOpacity: Double = 0.05
    }
    
    // MARK: - Computed Properties
    
    private var entryTitle: String {
        if let targetMonth = entry.targetMonth {
            return SpecialEntryTemplates.title(for: entry.specialEntryType ?? "", month: targetMonth)
        }
        return entry.specialEntryType == "review" ? "Monthly Review" : "Monthly Outlook"
    }
    
    private var backgroundColor: Color {
        let baseColor = entry.specialEntryType == "review" ? Color.purple : Color.green
        return baseColor.opacity(Layout.backgroundOpacity)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.verticalSpacing) {
                    headerSection
                    
                    Divider()
                    
                    Text(entry.content ?? "")
                        .padding(.horizontal)
                        .textSelection(.enabled)
                    
                    Spacer(minLength: Layout.minSpacerHeight)
                }
                .padding(.vertical)
            }
            .navigationTitle(entryTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done", action: dismiss.callAsFunction)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "pencil")
                    }
                }
            }
            .background(backgroundColor.ignoresSafeArea())
        }
        .sheet(isPresented: $showingEditSheet) {
            editSheet
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Layout.headerSpacing) {
            if entry.isDraft {
                Label("Draft", systemImage: "doc.badge.clock")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            if let date = entry.date {
                Text("Created \(date.formatted(date: .long, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }
    
    private var editSheet: some View {
        SpecialEntryEditorView(
            content: Binding(
                get: { entry.content ?? "" },
                set: { newContent in
                    updateEntry(with: newContent)
                }
            ),
            specialType: entry.specialEntryType ?? "review",
            targetMonth: entry.targetMonth ?? Date(),
            isDraft: Binding(
                get: { entry.isDraft },
                set: { entry.isDraft = $0 }
            ),
            onSave: saveEntry
        )
    }
    
    // MARK: - Helper Methods
    
    private func updateEntry(with newContent: String) {
        entry.content = newContent
        entry.isDraft = false // Publishing when edited
        saveEntry()
    }
    
    private func saveEntry() {
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
