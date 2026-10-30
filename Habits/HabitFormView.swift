//
//  HabitFormView.swift
//  Bullet Tracker
//
//  Shared form component for AddHabitView and EditHabitView
//

import SwiftUI

// MARK: - CompletionStyle — UI extension
//
// The enum's data definition lives in `Data/Models.swift` (Wave 2 — moved
// there so storage can reference it). UI affordances (label / description /
// icon / icon color) stay here in the SwiftUI-importing module so
// `Data/Models.swift` doesn't need to depend on SwiftUI. The `.from(useMultipleStates:isNegativeHabit:)`
// + `.asBools` bool-conversion helpers from the pre-Wave-2 enum are deleted —
// the storage layer now speaks `CompletionStyle` directly.

// MARK: - DetailKind — UI extension
//
// Display names for the four detail kinds. Lives here in the SwiftUI-importing
// module (rather than next to the enum's data definition in `Data/Models.swift`)
// for the same reason `CompletionStyle`'s affordances do — keeps the data
// model free of presentation strings.

extension DetailKind {
    var displayName: String {
        switch self {
        case .notes:   return "General Notes"
        case .workout: return "Workout Details"
        case .reading: return "Reading Log"
        case .mood:    return "Mood Tracking"
        }
    }
}

extension CompletionStyle {
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
        case .simple: return AppTheme.success
        case .multiState: return AppTheme.partial
        case .avoidance: return AppTheme.failed
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
    /// `nil` = no detail capture; otherwise specifies which kind. Replaces the
    /// pre-Wave-2 `@Binding var trackDetails: Bool` + `@Binding var detailType: String` pair.
    @Binding var detailKind: DetailKind?
    @Binding var completionStyle: CompletionStyle
    @Binding var showingIconSheet: Bool

    // bt-0018 — automatic grading. `nil` kind = off; `nil` target = default.
    @Binding var gradingKind: GradingKind?
    @Binding var targetProteinGrams: Double?
    @Binding var targetCalorieLow: Double?
    @Binding var targetCalorieHigh: Double?
    @Binding var targetWorkoutMinutes: Double?
    @Binding var targetSteps: Double?
    // bt-0022 — ring ceilings for the Dashboard; not part of the grade.
    @Binding var targetCarbsGrams: Double?
    @Binding var targetFatGrams: Double?
    /// The habit's current go-live day, for the footer ("since Oct 27").
    var gradingSince: Date? = nil

    /// Swatch / icon tiles scale with the user's text size (Dynamic Type).
    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var quickIconSize: CGFloat = 30
    @ScaledMetric(relativeTo: .title3) private var iconTileSize: CGFloat = 36

    // MARK: - Body

    var body: some View {
        Group {
            nameAndAppearanceSection
            scheduleSection
            completionStyleSection
            if completionStyle == .multiState {
                gradingSection
            }
            detailLoggingSection
            notesSection
        }
    }

    // MARK: - Section 3b: Automatic Grading (bt-0018)

    private var gradingSection: some View {
        Section {
            Picker("Graded by", selection: $gradingKind) {
                Text("Off").tag(GradingKind?.none)
                Text("Diet").tag(GradingKind?.some(.diet))
                Text("Workout").tag(GradingKind?.some(.workout))
            }

            switch gradingKind {
            case .diet?:
                targetRow("Protein at least", value: $targetProteinGrams, unit: "g", placeholder: GradingTargets.defaults.proteinFloorGrams)
                targetRow("Calories from", value: $targetCalorieLow, unit: "cal", placeholder: GradingTargets.defaults.calorieFloor)
                targetRow("Calories to", value: $targetCalorieHigh, unit: "cal", placeholder: GradingTargets.defaults.calorieCeiling)
                targetRow("Carbs up to", value: $targetCarbsGrams, unit: "g", placeholder: GradingTargets.defaults.carbsCeilingGrams)
                targetRow("Fat up to", value: $targetFatGrams, unit: "g", placeholder: GradingTargets.defaults.fatCeilingGrams)
            case .workout?:
                targetRow("Workout minutes", value: $targetWorkoutMinutes, unit: "min", placeholder: GradingTargets.defaults.workoutMinutes)
                targetRow("Steps for partial", value: $targetSteps, unit: "steps", placeholder: GradingTargets.defaults.steps)
            case nil:
                EmptyView()
            }
        } header: {
            Text("Automatic Grading")
        } footer: {
            switch gradingKind {
            case nil:
                Text("Diet is graded from protein and calories; Workout from minutes and steps. Only the iPhone writes grades.")
            case .diet?:
                if let gradingSince {
                    Text("Grading since \(gradingSince.formatted(.dateTime.month(.abbreviated).day())). Earlier days stay as you set them. Blank = the default shown. Calories from, carbs and fat show on the Dashboard only; they never change the grade.")
                } else {
                    Text("Grading starts today. Earlier days stay as you set them. Blank = the default shown. Calories from, carbs and fat show on the Dashboard only; they never change the grade.")
                }
            case .some:
                if let gradingSince {
                    Text("Grading since \(gradingSince.formatted(.dateTime.month(.abbreviated).day())). Earlier days stay as you set them. Blank = the default shown.")
                } else {
                    Text("Grading starts today. Earlier days stay as you set them. Blank = the default shown.")
                }
            }
        }
    }

    /// A number field with its unit, right-aligned like Settings. A blank
    /// field means the default, which is shown as the placeholder.
    private func targetRow(_ title: String, value: Binding<Double?>, unit: String, placeholder: Double) -> some View {
        LabeledContent(title) {
            HStack(spacing: 4) {
                TextField(placeholder.formatted(.number.grouping(.never)), value: value, format: .number.grouping(.never))
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
                Text(unit)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section 1: Name & Appearance

    private var nameAndAppearanceSection: some View {
        Section("Name & Appearance") {
            TextField("Habit Name", text: $name)

            // Icon row — shows current icon with change button
            // The tile itself opens the picker (bt-0012: one control, not three).
            Button {
                showingIconSheet = true
            } label: {
                LabeledContent("Icon") {
                    HStack(spacing: 8) {
                        HabitIconTile(systemImage: selectedIcon, colorHex: selectedColor, size: iconTileSize, font: .title3)
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle()) // whole row tappable, not just the tile
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Icon, \(selectedIcon.symbolDisplayName)")
            .accessibilityHint("Opens the icon picker")

            // Quick icon row — real Buttons (were Images with tap gestures), each
            // named for VoiceOver and marked selected when it's the current icon.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HabitConstants.quickIconOptions, id: \.self) { icon in
                        let isSelected = selectedIcon == icon
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .foregroundStyle(Color(hex: selectedColor))
                                .frame(width: quickIconSize, height: quickIconSize)
                                .background(
                                    Circle()
                                        .fill(isSelected ? Color(.systemGray4) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(icon.symbolDisplayName)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                        ForEach(Array(HabitConstants.colorOptions.enumerated()), id: \.element) { index, color in
                            let isSelected = selectedColor == color
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: swatchSize, height: swatchSize)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: isSelected ? 2.5 : 0)
                                            .padding(1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Color \(index + 1) of \(HabitConstants.colorOptions.count)")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    let isOn = customDays.contains(day.0)
                    Button(action: { toggleCustomDay(day.0) }) {
                        HStack {
                            Text(day.1)
                            Spacer()
                            if isOn {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
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
                        .foregroundStyle(AppTheme.success)
                    Label("Partial — Did some but not all", systemImage: "circle.lefthalf.filled")
                        .foregroundStyle(AppTheme.partial)
                    Label("Tried — Attempted but struggled", systemImage: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.failed)
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
            Picker("Detail Logging", selection: $detailKind) {
                Text("Off").tag(DetailKind?.none)
                ForEach(DetailKind.allCases) { kind in
                    Text(kind.displayName).tag(DetailKind?.some(kind))
                }
            }

            if detailKind != nil {
                detailKindPreview
            }
        } header: {
            Text("Detail Logging")
        } footer: {
            if detailKind != nil {
                Text("A detail sheet will appear each time you complete this habit.")
            }
        }
    }

    @ViewBuilder
    private var detailKindPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("You'll log:")
                .font(.caption)
                .foregroundStyle(.secondary)
            switch detailKind {
            case .workout:
                Label("Workout type (Cardio, Strength, etc.)", systemImage: "figure.run")
                Label("Duration", systemImage: "clock")
                Label("Intensity (1-5)", systemImage: "flame.fill")
                Label("Notes", systemImage: "note.text")
            case .reading:
                Label("Book or article title", systemImage: "book.fill")
                Label("Pages read", systemImage: "number")
                Label("Notes", systemImage: "note.text")
            case .mood:
                Label("Mood level (Rough to Great)", systemImage: "sun.max.fill")
                Label("Notes", systemImage: "note.text")
            case .notes, .none:
                Label("Free-form notes", systemImage: "note.text")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Section 5: Notes

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
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

// MARK: - Toolbar visibility for form sheets

/// On the Duo simulator the New Habit sheet's Cancel/Save vanished once the
/// form was scrolled to the bottom (iOS 27 bar minimisation). The habit forms
/// are short and the actions must always be reachable, so opt the sheet's
/// navigation bar out of minimising. Gated: the modifier is iOS 27+.
struct KeepNavigationBarVisible: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            content
        }
    }
}

extension View {
    func keepNavigationBarVisible() -> some View {
        modifier(KeepNavigationBarVisible())
    }
}

// MARK: - SF Symbol display names

extension String {
    /// "figure.strengthtraining.traditional" → "Figure strengthtraining traditional";
    /// "heart.fill" → "Heart". Good enough for VoiceOver to say something human.
    var symbolDisplayName: String {
        let words = self
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".circle", with: "")
            .split(separator: ".")
            .map(String.init)
        return words.joined(separator: " ").capitalized
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

static let daysOfWeek = [
        (1, "Sunday"), (2, "Monday"), (3, "Tuesday"), (4, "Wednesday"),
        (5, "Thursday"), (6, "Friday"), (7, "Saturday")
    ]
}
