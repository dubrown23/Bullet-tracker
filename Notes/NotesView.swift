//
//  NotesView.swift
//  Bullet Tracker
//
//  Simple dated notes - write notes, browse by month, search
//

import SwiftUI
import CoreData
import Combine

struct NotesView: View {
    @StateObject private var viewModel = NotesViewModel()
    @State private var showingAddNote = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month selector
                monthSelector

                // Notes list
                if viewModel.notes.isEmpty && searchText.isEmpty {
                    emptyState
                } else if filteredNotes.isEmpty {
                    noResultsState
                } else {
                    notesList
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Notes")
            .searchable(text: $searchText, prompt: "Search notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddNote = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddNote, onDismiss: {
                viewModel.loadNotes()
            }) {
                AddNoteView()
            }
            .sheet(item: $viewModel.selectedNote, onDismiss: {
                viewModel.loadNotes()
            }) { note in
                EditNoteView(note: note)
            }
            .onAppear {
                viewModel.loadNotes()
            }
        }
    }

    // MARK: - Month Selector

    private var monthSelector: some View {
        HStack(spacing: 4) {
            Button(action: { viewModel.goToPreviousMonth() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
            }

            Text(viewModel.monthYearString)
                .font(.system(size: 16, weight: .semibold))
                .frame(minWidth: 140)

            Button(action: { viewModel.goToNextMonth() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(viewModel.isCurrentMonth ? .gray.opacity(0.5) : .blue)
                    .frame(width: 36, height: 36)
            }
            .disabled(viewModel.isCurrentMonth)

            Spacer()

            if !viewModel.isCurrentMonth {
                Button(action: { viewModel.goToToday() }) {
                    Text("Today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
    }

    // MARK: - Notes List

    private var notesList: some View {
        List {
            ForEach(groupedNotes.keys.sorted(by: >), id: \.self) { date in
                Section(header: Text(formatSectionDate(date))) {
                    ForEach(groupedNotes[date] ?? []) { note in
                        NoteRowView(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedNote = note
                            }
                    }
                    .onDelete { indexSet in
                        deleteNotes(at: indexSet, for: date)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "note.text")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Notes Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to add your first note")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: { showingAddNote = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Note")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top)

            Spacer()
        }
        .padding()
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Results")
                .font(.title3)
                .fontWeight(.medium)

            Text("No notes match '\(searchText)'")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Computed Properties

    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return viewModel.notes
        }
        return viewModel.notes.filter {
            $0.content?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }

    private var groupedNotes: [Date: [Note]] {
        let calendar = Calendar.current
        return Dictionary(grouping: filteredNotes) { note in
            calendar.startOfDay(for: note.date ?? Date())
        }
    }

    // MARK: - Helper Methods

    private static let sectionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.sectionDateFormatter.string(from: date)
        }
    }

    private func deleteNotes(at indexSet: IndexSet, for date: Date) {
        guard let notes = groupedNotes[date] else { return }
        for index in indexSet {
            let note = notes[index]
            viewModel.deleteNote(note)
        }
    }
}

// MARK: - Note Row View

struct NoteRowView: View {
    @ObservedObject var note: Note

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private var timeString: String {
        Self.timeFormatter.string(from: note.date ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.content ?? "")
                .font(.body)
                .lineLimit(3)

            Text(timeString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Note View

struct AddNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $content)
                    .focused($isFocused)
                    .padding()
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func saveNote() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }

        let context = CoreDataManager.shared.container.viewContext
        let note = Note(context: context)
        note.id = UUID()
        note.content = trimmedContent
        note.date = Date()

        do {
            try context.save()
        } catch {
            debugLog("Failed to save note: \(error.localizedDescription)")
        }

        dismiss()
    }
}

// MARK: - Edit Note View

struct EditNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var note: Note
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
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
            try note.managedObjectContext?.save()
        } catch {
            debugLog("Failed to save note: \(error.localizedDescription)")
        }

        dismiss()
    }
}

// MARK: - View Model

@MainActor
class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedDate = Date()
    @Published var selectedNote: Note?

    private let calendar = Calendar.current

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    var monthYearString: String {
        Self.monthYearFormatter.string(from: selectedDate)
    }

    var isCurrentMonth: Bool {
        calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }

    func loadNotes() {
        let context = CoreDataManager.shared.container.viewContext

        // Get start and end of selected month
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@",
                                         startOfMonth as NSDate,
                                         (calendar.date(byAdding: .day, value: 1, to: endOfMonth) ?? endOfMonth) as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        do {
            notes = try context.fetch(request)
        } catch {
            notes = []
        }
    }

    func goToPreviousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
            loadNotes()
        }
    }

    func goToNextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate),
           newDate <= Date() {
            selectedDate = newDate
            loadNotes()
        }
    }

    func goToToday() {
        selectedDate = Date()
        loadNotes()
    }

    func deleteNote(_ note: Note) {
        let context = CoreDataManager.shared.container.viewContext
        context.delete(note)

        do {
            try context.save()
            loadNotes()
        } catch {
            debugLog("Failed to delete note: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NotesView()
}
