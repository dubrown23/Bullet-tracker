//
//  HabitCompletionDetailView.swift
//  Bullet Tracker
//
//  Native iOS Form-based detail entry for habit logging
//

import SwiftUI
import SwiftData

struct HabitCompletionDetailView: View {
    // MARK: - Properties

    let habit: Habit
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - State

    @State private var notes: String = ""
    @State private var completionState: Int = 1
    @State private var entryExists: Bool = false

    // Workout
    @State private var duration: String = ""
    @State private var selectedWorkoutTypes: Set<String> = []
    @State private var intensity: Int = 3

    // Reading
    @State private var pagesRead: String = ""
    @State private var bookTitle: String = ""

    // Mood
    @State private var selectedMood: Int = 3

    // MARK: - Constants

    private let workoutTypes = ["Cardio", "Strength", "Functional", "Core/Pre-Hab", "HIIT/Jump", "Other"]
    private let durationOptions = ["15", "30", "45", "60", "75", "90"]

    // MARK: - Computed

    private var habitColor: Color { Color(hex: habit.color ?? "#FF8C42") }

    private var useMultipleStates: Bool {
        habit.completionStyle == .multiState
    }

    /// `nil` is treated as `.notes` for UI purposes (the "general notes" surface).
    private var detailKind: DetailKind {
        habit.detailKind ?? .notes
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Habit header
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: habit.icon ?? "circle.fill")
                            .font(.title3)
                            .foregroundStyle(habitColor)

                        VStack(alignment: .leading) {
                            Text(habit.name ?? "Habit")
                                .font(.headline)
                            Text(DateFormatters.weekdayMonthDay.string(from: date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Completion state
                if useMultipleStates {
                    Section("How'd it go?") {
                        Picker("State", selection: $completionState) {
                            Label("Success", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .tag(1)
                            Label("Partial", systemImage: "circle.lefthalf.filled")
                                .foregroundStyle(.orange)
                                .tag(2)
                            Label("Tried", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .tag(3)
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }

                // Type-specific sections
                switch detailKind {
                case .workout:
                    workoutSection
                case .reading:
                    readingSection
                case .mood:
                    moodSection
                case .notes:
                    EmptyView()
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                // Clear entry
                if entryExists {
                    Section {
                        Button("Clear Entry", role: .destructive) {
                            clearEntry()
                        }
                    }
                }
            }
            .navigationTitle("Log Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: loadExistingDetails)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Workout

    @ViewBuilder
    private var workoutSection: some View {
        Section("Workout Type") {
            FlowLayout(spacing: 8) {
                ForEach(workoutTypes, id: \.self) { type in
                    let isSelected = selectedWorkoutTypes.contains(type)
                    Button(action: {
                        if isSelected { selectedWorkoutTypes.remove(type) }
                        else { selectedWorkoutTypes.insert(type) }
                    }) {
                        Text(type)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? habitColor : Color(.systemGray5))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }

        Section("Duration") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(durationOptions, id: \.self) { mins in
                        let isSelected = duration == mins
                        Button(action: { duration = mins }) {
                            Text("\(mins) min")
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(isSelected ? habitColor : Color(.systemGray5))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        }

        Section {
            HStack {
                Text("Intensity")
                Spacer()
                Picker("Intensity", selection: $intensity) {
                    ForEach(1...5, id: \.self) { level in
                        Text("\(level)").tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
    }

    // MARK: - Reading

    @ViewBuilder
    private var readingSection: some View {
        Section("Reading") {
            TextField("Book or article title", text: $bookTitle)
            HStack {
                Text("Pages read")
                Spacer()
                TextField("0", text: $pagesRead)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
        }
    }

    // MARK: - Mood

    @ViewBuilder
    private var moodSection: some View {
        Section("How are you feeling?") {
            Picker("Mood", selection: $selectedMood) {
                Label("Rough", systemImage: "cloud.rain").tag(1)
                Label("Low", systemImage: "cloud").tag(2)
                Label("Okay", systemImage: "cloud.sun").tag(3)
                Label("Good", systemImage: "sun.max").tag(4)
                Label("Great", systemImage: "sun.max.fill").tag(5)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }
    }

    // MARK: - Data

    private func loadExistingDetails() {
        if let entry = HabitStore.entry(for: habit, on: date) {
            entryExists = true
            loadEntryData(from: entry)
        } else {
            entryExists = false
        }
    }

    private func loadEntryData(from entry: HabitEntry) {
        completionState = Int(entry.completionState.rawValue)

        guard let details = entry.details else { return }

        // Pattern-match the typed payload directly — no more hand-parsed JSON.
        // Each case lifts its own fields into local @State; the `notes` field is
        // shared across all four cases.
        switch details {
        case .notes(let n):
            notes = n
        case .workout(let types, let dur, let intens, let n):
            selectedWorkoutTypes = Set(types)
            duration = dur
            intensity = intens
            notes = n
        case .reading(let title, let pages, let n):
            bookTitle = title
            pagesRead = pages
            notes = n
        case .mood(let mood, let n):
            selectedMood = mood
            notes = n
        }
    }

    private func saveAndDismiss() {
        let details = buildDetails()
        HabitStore.updateEntryDetails(for: habit, on: date, state: completionState, details: details, in: modelContext)
        dismiss()
    }

    private func buildDetails() -> HabitEntryDetails {
        switch detailKind {
        case .workout:
            return .workout(
                types: Array(selectedWorkoutTypes),
                duration: duration,
                intensity: intensity,
                notes: notes
            )
        case .reading:
            return .reading(bookTitle: bookTitle, pagesRead: pagesRead, notes: notes)
        case .mood:
            return .mood(mood: selectedMood, notes: notes)
        case .notes:
            return .notes(notes: notes)
        }
    }

    private func clearEntry() {
        HabitStore.removeEntry(for: habit, on: date, in: modelContext)
        dismiss()
    }
}
