//
//  SpecialEntryEditorView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/5/25.
//


//
//  SpecialEntryEditorView.swift
//  Bullet Tracker
//
//  Created for Phase 5: Reviews & Outlooks
//

import SwiftUI

struct SpecialEntryEditorView: View {
    // MARK: - Properties
    
    @Binding var content: String
    let specialType: String
    let targetMonth: Date
    @Binding var isDraft: Bool
    let onSave: () -> Void
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var showingTemplate = false
    @State private var wordCount = 0
    @State private var lastSavedContent = ""
    @State private var autoSaveTimer: Timer?
    
    // MARK: - Computed Properties
    
    private var editorTitle: String {
        SpecialEntryTemplates.title(for: specialType, month: targetMonth)
    }
    
    private var placeholderText: String {
        specialType == "review" 
            ? "Reflect on your month..."
            : "Plan for the month ahead..."
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Editor
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $content)
                        .padding(4)
                        .onChange(of: content) { newValue in
                            updateWordCount()
                            scheduleAutoSave()
                        }
                    
                    if content.isEmpty {
                        Text(placeholderText)
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                
                // Bottom toolbar with word count
                HStack {
                    Button(action: { showingTemplate = true }) {
                        Label("Use Template", systemImage: "doc.text")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Text("\(wordCount) words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Save as draft if content exists
                        if !content.isEmpty && content != lastSavedContent {
                            isDraft = true
                            onSave()
                        }
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: saveAsDraft) {
                            Label("Save as Draft", systemImage: "doc.badge.clock")
                        }
                        
                        Button(action: saveAndPublish) {
                            Label("Save & Publish", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .disabled(content.isEmpty)
                }
            }
            .confirmationDialog("Use Template?", isPresented: $showingTemplate) {
                Button("Insert Template") {
                    insertTemplate()
                }
                Button("Replace Content with Template", role: .destructive) {
                    replaceWithTemplate()
                }
            } message: {
                Text("Would you like to insert the template at your cursor or replace all content?")
            }
        }
        .onAppear {
            updateWordCount()
            lastSavedContent = content
        }
        .onDisappear {
            autoSaveTimer?.invalidate()
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateWordCount() {
        let words = content.split { $0.isWhitespace || $0.isNewline }
        wordCount = words.count
    }
    
    private func scheduleAutoSave() {
        // Cancel existing timer
        autoSaveTimer?.invalidate()
        
        // Schedule new auto-save in 30 seconds
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            if content != lastSavedContent && !content.isEmpty {
                isDraft = true
                onSave()
                lastSavedContent = content
            }
        }
    }
    
    private func insertTemplate() {
        if let template = SpecialEntryTemplates.template(for: specialType) {
            // Insert at current position (for simplicity, append)
            if content.isEmpty {
                content = template
            } else {
                content += "\n\n" + template
            }
        }
    }
    
    private func replaceWithTemplate() {
        if let template = SpecialEntryTemplates.template(for: specialType) {
            content = template
        }
    }
    
    private func saveAsDraft() {
        isDraft = true
        onSave()
        dismiss()
    }
    
    private func saveAndPublish() {
        isDraft = false
        onSave()
        dismiss()
    }
}

// MARK: - Preview

struct SpecialEntryEditorView_Previews: PreviewProvider {
    static var previews: some View {
        SpecialEntryEditorView(
            content: .constant(""),
            specialType: "review",
            targetMonth: Date(),
            isDraft: .constant(false),
            onSave: {}
        )
    }
}