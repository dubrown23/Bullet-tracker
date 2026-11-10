//
//  HabitCompletionDetailView.swift
//  Bullet Tracker
//
//  Native iOS Form-based detail entry for habit logging.
//
//  bt-0021 — for the two graded habits (Diet / Workout) the sheet leads with
//  the day's mode ("Auto · Done", or "Set by you, 2:14 PM · Partial" with a
//  Back to Auto button) and shows what dustin-health reported: the meals on
//  a Diet day, the sessions on a Workout day. That list comes from the row's
//  `health` block (today: the engine's live copy) and is never part of the
//  notes, so neither can wipe the other.
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
    /// Who wrote the day's row and when (bt-0018). Shown for graded habits
    /// on/after the go-live day; drives "Back to Auto".
    @State private var entrySource: EntrySource = .hand
    @State private var entryEditedAt: Date?
    /// A hand / voice row WITH a grade (bt-0021). A details-only row is Auto.
    @State private var entryIsOverride = false
    @State private var loadedState: Int = 1
    @State private var engine = HabitSyncEngine.shared
    /// dh's sessions / meals for the day (bt-0021).
    @State private var health: HealthSnapshot?

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

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    /// The mode section shows for a graded habit on/after its go-live day.
    private var showsMode: Bool { habit.isWithinGrading(date) }

    private var sessions: [HealthSnapshot.Session] {
        habit.gradingKind == .workout ? (health?.sessions ?? []) : []
    }

    private var meals: [HealthSnapshot.Meal] {
        habit.gradingKind == .diet ? (health?.meals ?? []) : []
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

                // bt-0021 — the mode first: who set the day, and the way back.
                if showsMode {
                    modeSection
                }

                // Diet: the meals come right under the numbers.
                if !meals.isEmpty {
                    mealsSection
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
                            // bt-0018 — Workout-graded habits only.
                            if habit.offersRest {
                                Label("Rest", systemImage: "zzz")
                                    .foregroundStyle(AppTheme.rest)
                                    .tag(4)
                                // bt-0029 — so an automatic Active day shows as picked.
                                Label("Active day", systemImage: "figure.walk")
                                    .foregroundStyle(AppTheme.activeDay)
                                    .tag(5)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }

                // Workout: the sessions, then the chips they lit.
                if !sessions.isEmpty {
                    sessionsSection
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

    // MARK: - Mode (bt-0021)

    /// The mode shown: a hand / voice row with a grade is that; anything
    /// else (no row, an auto row, a details-only row) is Auto. A state
    /// picked but not yet saved already reads "Set by you" — that is what
    /// Done will write.
    private var shownSource: EntrySource {
        guard entryExists else { return .auto }
        if entryIsOverride { return entrySource }
        return completionState != loadedState ? .hand : .auto
    }

    /// Whether the time belongs on the headline (a saved override only).
    private var showsEditTime: Bool { entryExists && entryIsOverride }

    /// "Auto · Done", "Set by you, 2:14 PM · Partial", "Auto · in progress".
    private var modeLine: String {
        var mode = GradeWording.mode(shownSource)
        if showsEditTime, let editedAt = entryEditedAt {
            mode += ", " + editedAt.formatted(date: .omitted, time: .shortened)
        }
        let state: String
        if entryExists, let typed = CompletionState(rawValue: Int16(completionState)), typed != .notDone {
            state = GradeWording.stateWord(typed)
        } else {
            state = isToday ? "in progress" : "no grade"
        }
        return mode + " · " + state
    }

    private var modeFooter: String {
        if entryExists && entryIsOverride {
            return "Back to Auto clears this grade so the automatic one comes back."
        }
        if shownSource != .auto {
            return "Done saves this as your grade."
        }
        switch habit.gradingKind {
        case .diet: return "Graded from the day's meals in Dustin's Health."
        case .workout: return "Graded from the day's workouts in Dustin's Health and steps from Health."
        case nil: return ""
        }
    }

    /// Diet only: "Protein 30 / 180 g · Calories 1,850 of 2,200". Today
    /// from the live numbers; a past day from the stored meals. The line
    /// describes the grade, so it names the ceiling only (the floor stopped
    /// grading 2026-10-30; the Dashboard band still shows it).
    private var dietNumbers: String? {
        guard habit.gradingKind == .diet else { return nil }
        let t = habit.gradingTargets
        var protein: Double?
        var calories: Double?
        if isToday, let id = habit.id, let live = engine.liveFacts[id] {
            protein = live.proteinGrams
            calories = live.calories
        } else {
            protein = health?.totalProtein
            calories = health?.totalCalories
        }
        guard protein != nil || calories != nil else { return nil }
        let proteinText = "Protein \(Self.whole(protein ?? 0)) / \(Self.whole(t.proteinFloorGrams)) g"
        let caloriesText = "Calories \(Self.whole(calories ?? 0)) of \(Self.whole(t.calorieCeiling))"
        return proteinText + " · " + caloriesText
    }

    @ViewBuilder
    private var modeSection: some View {
        Section {
            Text(modeLine)
                .font(.headline)
                .contentTransition(.numericText())
            if let dietNumbers {
                Text(dietNumbers)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            // Its own row, so the headline never wraps around it.
            if entryExists && entryIsOverride {
                Button("Back to Auto", systemImage: "arrow.uturn.backward") {
                    Task {
                        await engine.revertToAutomatic(habit: habit, day: date, in: modelContext)
                        dismiss()
                    }
                }
            }
        } footer: {
            if !modeFooter.isEmpty {
                Text(modeFooter)
            }
        }
    }

    // MARK: - From Dustin's Health (bt-0021)

    @ViewBuilder
    private var mealsSection: some View {
        Section("Meals from Dustin's Health") {
            ForEach(Array(meals.enumerated()), id: \.offset) { _, meal in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name)
                        if let at = meal.at {
                            Text(at.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text(Self.mealNumbers(calories: meal.calories, protein: meal.protein))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
            if meals.count > 1 {
                LabeledContent("Total", value: Self.mealNumbers(calories: health?.totalCalories, protein: health?.totalProtein))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var sessionsSection: some View {
        Section("From Dustin's Health") {
            ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.name)
                        Text(Self.sessionNumbers(session))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let start = session.start {
                        Text(start.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if sessions.count > 1 {
                LabeledContent("Total", value: "\(Self.whole(health?.totalMinutes ?? 0)) min")
                    .monospacedDigit()
            }
        }
    }

    /// "168 cal · 30 g"; a number dh doesn't know is a dash, never 0.
    static func mealNumbers(calories: Double?, protein: Double?) -> String {
        let cal = calories.map(whole) ?? "—"
        let pro = protein.map(whole) ?? "—"
        return "\(cal) cal · \(pro) g"
    }

    /// "66 min" / "23 min · 13 sets".
    static func sessionNumbers(_ session: HealthSnapshot.Session) -> String {
        var parts = ["\(whole(session.minutes)) min"]
        if session.sets > 0 { parts.append("\(session.sets) set\(session.sets == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    private static func whole(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    // MARK: - Workout

    @ViewBuilder
    private var workoutSection: some View {
        // System chips: toggles in the button style, capsule-shaped, tinted
        // with the habit colour (bt-0015 rule 4). The system handles the
        // on/off fill, label contrast, press feedback and VoiceOver.
        // bt-0021: the sync lights these from dh's session categories; the
        // ones Dustin adds stay.
        Section("Workout Type") {
            FlowLayout(spacing: 8) {
                ForEach(WorkoutTypeChips.all, id: \.self) { type in
                    Toggle(type, isOn: workoutTypeBinding(type))
                        .toggleStyle(.button)
                        .buttonStyle(.bordered) // off = outlined capsule, on = tint fill
                        .buttonBorderShape(.capsule)
                        .tint(habitColor)
                }
            }
            .padding(.vertical, 4)
        }

        // Duration chips only when dh has no sessions for the day; with
        // sessions, the minutes are dh's and sit in the list above.
        if sessions.isEmpty {
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
        let entry = HabitStore.entry(for: habit, on: date)
        if let entry {
            entryExists = true
            loadEntryData(from: entry)
        } else {
            entryExists = false
        }
        // bt-0021 — the row's dh list; today, the engine's live copy when
        // the row has none yet (or there is no row).
        health = entry?.health ?? (isToday ? engine.liveSnapshot(for: habit) : nil)
    }

    private func loadEntryData(from entry: HabitEntry) {
        completionState = Int(entry.effectiveCompletionState.rawValue)
        loadedState = completionState
        entrySource = entry.source
        entryEditedAt = entry.editedAt
        entryIsOverride = entry.isOverride

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
        // bt-0021 — looking is not logging: on a graded habit with no row
        // yet, Done with nothing typed writes nothing (a blank hand row
        // would have nothing to say and would only confuse the mode line).
        if !entryExists && habit.isAutoGraded && Self.isBlank(details) {
            dismiss()
            return
        }
        // Done saves the details and keeps whatever state the day already has.
        // If nothing was logged yet, the entry is created as `.notDone` with
        // the notes attached — the square is the only thing that marks a day.
        let state = entryExists ? completionState : 0
        // Adding notes to an automatic grade keeps it automatic; changing the
        // state makes it a hand grade ("overrides win").
        let source: EntrySource = (entryExists && entrySource == .auto && state == loadedState) ? .auto : .hand
        HabitStore.updateEntryDetails(for: habit, on: date, state: state, details: details, source: source, in: modelContext)
        dismiss()
    }

    /// Nothing typed or picked (the intensity default doesn't count).
    static func isBlank(_ details: HabitEntryDetails) -> Bool {
        switch details {
        case .notes(let n): return n.isEmpty
        case .workout(let types, let duration, _, let n): return types.isEmpty && duration.isEmpty && n.isEmpty
        case .reading(let title, let pages, let n): return title.isEmpty && pages.isEmpty && n.isEmpty
        case .mood(_, let n): return n.isEmpty
        }
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
