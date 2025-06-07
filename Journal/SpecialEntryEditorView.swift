//
//  SpecialEntryEditorView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 6/5/25.
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
    @State private var lastSavedContent = ""
    @State private var autoSaveTask: Task<Void, Never>?
    @FocusState private var isEditorFocused: Bool
    
    // MARK: - Constants
    
    private enum Layout {
        static let editorPadding: CGFloat = 4
        static let placeholderHorizontalPadding: CGFloat = 8
        static let placeholderVerticalPadding: CGFloat = 12
        static let placeholderOpacity: Double = 0.6
        static let autoSaveInterval: TimeInterval = 30.0
    }
    
    // MARK: - Computed Properties
    
    private var editorTitle: String {
        SpecialEntryTemplates.title(for: specialType, month: targetMonth)
    }
    
    private var placeholderText: String {
        specialType == "review"
            ? "Reflect on your month..."
            : "Plan for the month ahead..."
    }
    
    private var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }
    
    private var hasUnsavedChanges: Bool {
        !content.isEmpty && content != lastSavedContent
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                editorSection
                bottomToolbar
            }
            .navigationTitle(editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                toolbarContent
            }
            .confirmationDialog("Use Template?", isPresented: $showingTemplate) {
                templateDialogButtons
            } message: {
                Text("Would you like to insert the template at your cursor or replace all content?")
            }
        }
        .onAppear {
            lastSavedContent = content
            isEditorFocused = true
        }
        .onDisappear {
            autoSaveTask?.cancel()
        }
    }
    
    // MARK: - View Components
    
    private var editorSection: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $content)
                .padding(Layout.editorPadding)
                .focused($isEditorFocused)
                .onChange(of: content) { _, _ in
                    scheduleAutoSave()
                }
            
            if content.isEmpty {
                Text(placeholderText)
                    .foregroundStyle(.secondary.opacity(Layout.placeholderOpacity))
                    .padding(.horizontal, Layout.placeholderHorizontalPadding)
                    .padding(.vertical, Layout.placeholderVerticalPadding)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private var bottomToolbar: some View {
        HStack {
            Button(action: { showingTemplate = true }) {
                Label("Use Template", systemImage: "doc.text")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            
            Spacer()
            
            Text("\(wordCount) words")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                handleCancel()
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
    
    @ViewBuilder
    private var templateDialogButtons: some View {
        Button("Insert Template") {
            insertTemplate()
        }
        
        Button("Replace Content with Template", role: .destructive) {
            replaceWithTemplate()
        }
    }
    
    // MARK: - Helper Methods
    
    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(Layout.autoSaveInterval * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            if hasUnsavedChanges {
                await MainActor.run {
                    isDraft = true
                    onSave()
                    lastSavedContent = content
                }
            }
        }
    }
    
    private func handleCancel() {
        if hasUnsavedChanges {
            isDraft = true
            onSave()
        }
        dismiss()
    }
    
    private func insertTemplate() {
        guard let template = SpecialEntryTemplates.template(for: specialType) else { return }
        
        if content.isEmpty {
            content = template
        } else {
            content += "\n\n" + template
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

#Preview {
    SpecialEntryEditorView(
        content: .constant(""),
        specialType: "review",
        targetMonth: Date(),
        isDraft: .constant(false),
        onSave: {}
    )
}
