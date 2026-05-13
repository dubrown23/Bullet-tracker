//
//  HabitFormView.swift
//  Bullet Tracker
//
//  Shared form component for AddHabitView and EditHabitView
//

import SwiftUI

// MARK: - Completion Style

enum CompletionStyle: String, CaseIterable, Identifiable {
    case simple = "simple"
    case multiState = "multiState"
    case avoidance = "avoidance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simple: return "Simple"
        case .multiState: return "Multi-State"
        case .avoidance: return "Avoidance"
        }
    }

    var description: String {
        switch self {
        case .simple:
            return "Done or not done. Tap to complete."
        case .multiState:
            return "Track success, partial, and failure separately."
        case .avoidance:
            return "Track something you're trying not to do. Checking means you slipped."
        }
    }

    var icon: String {
        switch self {
        case .simple: return "checkmark.circle.fill"
        case .multiState: return "circle.lefthalf.filled"
        case .avoidance: return "xmark.octagon.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .simple: return .green
        case .multiState: return .orange
        case .avoidance: return .red
        }
    }

    /// Convert from stored Core Data bools
    static func from(useMultipleStates: Bool, isNegativeHabit: Bool) -> CompletionStyle {
        if isNegativeHabit { return .avoidance }
        if useMultipleStates { return .multiState }
        return .simple
    }

    /// Convert to stored Core Data bools
    var asBools: (useMultipleStates: Bool, isNegativeHabit: Bool) {
        switch self {
        case .simple: return (false, false)
        case .multiState: return (true, false)
        case .avoidance: return (false, true)
        }
    }
}

// MARK: - Shared Form Component

struct HabitFormView: View {
    // MARK: - Bindings

    @Binding var name: String
    @Binding var selectedIcon: String
    @Binding var selectedColor: String
    @Binding var selectedFrequency: String
    @Binding var customDays: [Int]
    @Binding var notes: String
    @Binding var trackDetails: Bool
    @Binding var detailType: String
    @Binding var completionStyle: CompletionStyle
    @Binding var showingIconSheet: Bool

    // MARK: - Body

    var body: some View {
        Group {
            nameAndAppearanceSection
            scheduleSection
            completionStyleSection
            detailLoggingSection
            notesSection
        }
    }

    // MARK: - Section 1: Name & Appearance

    private var nameAndAppearanceSection: some View {
        Section("Name & Appearance") {
            TextField("Habit Name", text: $name)

            // Icon row — shows current icon with change button
            HStack {
                Text("Icon")
                Spacer()
                Image(systemName: selectedIcon)
                    .font(.title3)
                    .foregroundStyle(Color(hex: selectedColor))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: selectedColor).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Change") {
                    showingIconSheet = true
                }
                .font(.subheadline)
            }

            // Quick icon row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HabitConstants.quickIconOptions, id: \.self) { icon in
                        Image(systemName: icon)
                            .foregroundStyle(Color(hex: selectedColor))
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(selectedIcon == icon ? Color(.systemGray4) : Color.clear)
                            )
                            .onTapGesture {
                                selectedIcon = icon
                            }
                    }
                }
            }

            // Color picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HabitConstants.colorOptions, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 2.5 : 0)
                                        .padding(1)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Section 2: Schedule

    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Frequency", selection: $selectedFrequency) {
                ForEach(HabitConstants.frequencyOptions, id: \.0) { option in
                    Text(option.1).tag(option.0)
                }
            }

            if selectedFrequency == HabitFrequency.custom.rawValue {
                ForEach(Array(HabitConstants.daysOfWeek.enumerated()), id: \.offset) { _, day in
                    Button(action: { toggleCustomDay(day.0) }) {
                        HStack {
                            Text(day.1)
                            Spacer()
                            if customDays.contains(day.0) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: - Section 3: Completion Style

    private var completionStyleSection: some View {
        Section {
            Picker("Completion Style", selection: $completionStyle) {
                ForEach(CompletionStyle.allCases) { style in
                    Label(style.title, systemImage: style.icon)
                        .tag(style)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            // Contextual description
            Label {
                Text(completionStyle.description)
                    .font(.caption)
            } icon: {
                Image(systemName: completionStyle.icon)
                    .foregroundStyle(completionStyle.iconColor)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Multi-state preview
            if completionStyle == .multiState {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Success — Full completion", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("Partial — Did some but not all", systemImage: "circle.lefthalf.filled")
                        .foregroundStyle(.orange)
                    Label("Tried — Attempted but struggled", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.caption)
            }
        } header: {
            Text("Completion Style")
        }
    }

    // MARK: - Section 4: Detail Logging

    private var detailLoggingSection: some View {
        Section {
            Toggle("Log details when completed", isOn: $trackDetails)

            if trackDetails {
                Picker("Detail Type", selection: $detailType) {
                    ForEach(HabitConstants.detailTypeOptions, id: \.0) { option in
                        Text(option.1).tag(option.0)
                    }
                }

                // Preview of what fields the user will see
                detailTypePreview
            }
        } header: {
            Text("Detail Logging")
        } footer: {
            if trackDetails {
                Text("A detail sheet will appear each time you complete this habit.")
            }
        }
    }

    @ViewBuilder
    private var detailTypePreview: some View {
        switch detailType {
        case "workout":
            VStack(alignment: .leading, spacing: 4) {
                Text("You'll log:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Workout type (Cardio, Strength, etc.)", systemImage: "figure.run")
                Label("Duration", systemImage: "clock")
                Label("Intensity (1-5)", systemImage: "flame.fill")
                Label("Notes", systemImage: "note.text")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case "reading":
            VStack(alignment: .leading, spacing: 4) {
                Text("You'll log:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Book or article title", systemImage: "book.fill")
                Label("Pages read", systemImage: "number")
                Label("Notes", systemImage: "note.text")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case "mood":
            VStack(alignment: .leading, spacing: 4) {
                Text("You'll log:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Mood level (Rough to Great)", systemImage: "sun.max.fill")
                Label("Notes", systemImage: "note.text")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("You'll log:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("Free-form notes", systemImage: "note.text")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Section 5: Notes

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(height: 80)
        }
    }

    // MARK: - Helpers

    private func toggleCustomDay(_ day: Int) {
        if let index = customDays.firstIndex(of: day) {
            customDays.remove(at: index)
        } else {
            customDays.append(day)
        }
    }
}

// MARK: - Constants

struct HabitConstants {
    static let colorOptions = [
        "#FF8C42", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#5856D6", "#FF2D55", "#5AC8FA",
        "#FFB380", "#F7D1A8", "#F7EFA8", "#A8E1A8", "#AFD0F5", "#D1A8F7", "#F7A8D1", "#A8F5F5",
        "#CC6B2E", "#804D00", "#806600", "#006633", "#004080", "#2E2B6B", "#80172B", "#0080A8",
        "#8E8E93", "#48484A", "#636366", "#A8A8A8", "#53433D", "#7A6E65", "#B3A395", "#D9C7B8"
    ]

    static let quickIconOptions = [
        "circle.fill", "heart.fill", "figure.run", "fork.knife",
        "thermometer.snowflake", "light.strip.2", "star.fill", "bell.fill"
    ]

    static let frequencyOptions: [(String, String)] = HabitFrequency.allCases.map { ($0.rawValue, $0.displayName) }

    static let detailTypeOptions = [
        ("general", "General Notes"),
        ("workout", "Workout Details"),
        ("reading", "Reading Log"),
        ("mood", "Mood Tracking")
    ]

    static let daysOfWeek = [
        (1, "Sunday"), (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"),
        (5, "Thursday"), (6, "Friday"), (7, "Saturday")
    ]
}
