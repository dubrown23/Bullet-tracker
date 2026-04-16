//
//  HabitCompletionDetailView.swift
//  Bullet Tracker
//
//  Native iOS Form-based detail entry for habit logging
//

import SwiftUI

struct HabitCompletionDetailView: View {
    // MARK: - Properties

    let habit: Habit
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(HabitDataRepository.self) private var dataRepository

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
        habit.useMultipleStates
    }

    private var detailType: String {
        habit.detailType ?? "general"
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
                switch detailType {
                case "workout":
                    workoutSection
                case "reading":
                    readingSection
                case "mood":
                    moodSection
                default:
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
        if let entry = dataRepository.getEntry(for: habit, on: date) {
            entryExists = true
            loadEntryData(from: entry)
        } else {
            entryExists = false
        }
    }

    private func loadEntryData(from entry: HabitEntry) {
        completionState = Int(entry.completionState)

        guard let existingDetails = entry.details,
              let data = existingDetails.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            notes = entry.details ?? ""
            return
        }

        if let existingNotes = json["notes"] as? String { notes = existingNotes }

        switch detailType {
        case "workout":
            if let types = json["types"] as? [String] {
                selectedWorkoutTypes = Set(types)
            } else if let type = json["type"] as? String, !type.isEmpty {
                selectedWorkoutTypes = [type]
            }
            if let d = json["duration"] as? String { duration = d }
            if let i = json["intensity"] as? Int { intensity = i }
        case "reading":
            if let title = json["bookTitle"] as? String { bookTitle = title }
            if let pages = json["pagesRead"] as? String { pagesRead = pages }
        case "mood":
            if let mood = json["mood"] as? Int { selectedMood = mood }
        default:
            break
        }
    }

    private func saveAndDismiss() {
        let detailsJSON = buildDetailsJSON()
        dataRepository.updateEntryDetails(for: habit, on: date, state: completionState, details: detailsJSON)
        dismiss()
    }

    private func buildDetailsJSON() -> String {
        var data: [String: Any] = ["notes": notes]

        switch detailType {
        case "workout":
            data["types"] = Array(selectedWorkoutTypes)
            data["type"] = selectedWorkoutTypes.first ?? ""
            data["duration"] = duration
            data["intensity"] = intensity
        case "reading":
            data["bookTitle"] = bookTitle
            data["pagesRead"] = pagesRead
        case "mood":
            data["mood"] = selectedMood
        default:
            break
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return notes
    }

    private func clearEntry() {
        dataRepository.removeEntry(for: habit, on: date)
        dismiss()
    }
}
