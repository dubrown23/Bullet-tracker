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

    private var habitColorHex: String { habit.color ?? AppTheme.accentHex }
    private var habitColor: Color { Color(hex: habitColorHex) }

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
                            .accessibilityHidden(true)

                        VStack(alignment: .leading) {
                            Text(habit.name ?? "Habit")
                                .font(.headline)
                            Text(DateFormatters.weekdayMonthDay.string(from: date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Completion state — only offered once the day is actually
                // logged. Done never changes the day's state on its own (bt-0014).
                if useMultipleStates && entryExists {
                    Section("How'd it go?") {
                        Picker("State", selection: $completionState) {
                            Label("Success", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.success)
                                .tag(1)
                            Label("Partial", systemImage: "circle.lefthalf.filled")
                                .foregroundStyle(AppTheme.partial)
                                .tag(2)
                            Label("Tried", systemImage: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.failed)
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
        // System chips: toggles in the button style, capsule-shaped, tinted
        // with the habit colour (bt-0015 rule 4). The system handles the
        // on/off fill, label contrast, press feedback and VoiceOver.
        Section("Workout Type") {
            FlowLayout(spacing: 8) {
                ForEach(workoutTypes, id: \.self) { type in
                    Toggle(type, isOn: workoutTypeBinding(type))
                        .toggleStyle(.button)
                        .buttonStyle(.bordered) // off = outlined capsule, on = tint fill
                        .buttonBorderShape(.capsule)
                        .tint(habitColor)
                }
            }
            .padding(.vertical, 4)
        }

        Section("Duration") {
            FlowLayout(spacing: 8) {
                ForEach(durationOptions, id: \.self) { mins in
                    Toggle("\(mins) min", isOn: durationBinding(mins))
                        .toggleStyle(.button)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(habitColor)
                        .accessibilityLabel("\(mins) minutes")
                }
            }
            .padding(.vertical, 4)
        }

        Section("Intensity") {
            // Segmented picker fills the row instead of a fixed 200pt frame
            // that squeezed the label at narrow widths (bt-0009).
            Picker("Intensity", selection: $intensity) {
                ForEach(1...5, id: \.self) { level in
                    Text("\(level)").tag(level)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func workoutTypeBinding(_ type: String) -> Binding<Bool> {
        Binding(
            get: { selectedWorkoutTypes.contains(type) },
            set: { isOn in
                if isOn { selectedWorkoutTypes.insert(type) } else { selectedWorkoutTypes.remove(type) }
            }
        )
    }

    /// Single-select: turning one duration on clears the others.
    private func durationBinding(_ mins: String) -> Binding<Bool> {
        Binding(
            get: { duration == mins },
            set: { isOn in duration = isOn ? mins : "" }
        )
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
                    .frame(minWidth: 60, maxWidth: 120)
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
        completionState = Int(entry.effectiveCompletionState.rawValue)

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
        // Done saves the details and keeps whatever state the day already has.
        // If nothing was logged yet, the entry is created as `.notDone` with
        // the notes attached — the square is the only thing that marks a day.
        let state = entryExists ? completionState : 0
        HabitStore.updateEntryDetails(for: habit, on: date, state: state, details: details, in: modelContext)
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
