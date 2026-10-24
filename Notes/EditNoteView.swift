//
//  EditNoteView.swift
//  Bullet Tracker
//
//  Sheet for editing a Journal note's text. Presented from `DayJournalView`.
//
//  bt-0008: this file was `NotesView.swift` — a whole unused Notes tab
//  (`NotesView`, `NoteRowView`, `AddNoteView`, `NotesViewModel`) plus this
//  view. Only `EditNoteView` was referenced from live code, so the rest
//  was deleted and the file renamed.
//

import SwiftUI
import SwiftData

struct EditNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let note: Note
    @State private var content: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $content)
                    .focused($isFocused)
                    .padding()
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                content = note.content ?? ""
                isFocused = true
            }
        }
    }

    private func saveChanges() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        note.content = trimmedContent
        do {
            try modelContext.save()
        } catch {
            debugLog("Failed to save note: \(error.localizedDescription)")
        }

        dismiss()
    }
}
