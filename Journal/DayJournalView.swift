//
//  DayJournalView.swift
//  Bullet Tracker
//
//  View a complete picture of any day - habits data and notes.
//
//  SwiftData migration (bt-0002 Wave 3b): fetches go through the VM's stored
//  `ModelContext` (set in `.onAppear`, matching `JournalExportView` / `SettingsView`).
//  Full-table `FetchDescriptor` + in-memory date filter mirrors Wave 3a
//  (`BackupManager` / `JournalPDFGenerator`) — sidesteps the `#Predicate`-over-
//  optional-relationships fiddle named in bt-0002 watch-item (e).
//

import SwiftUI
import SwiftData

struct DayJournalView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DayJournalViewModel()
    @State private var showingAddNote = false
    @State private var showingExportView = false
    @State private var newNoteText = ""
    @State private var hasLoadedOnce = false
    @FocusState private var isNoteFieldFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            // The date strip is a `safeAreaBar`: a custom bar the system treats like
            // its own — pinned below the nav bar, list scrolls under it with the
            // standard scroll-edge blur. Replaces a VStack + `.ultraThinMaterial`.
            List {
                    // Quick add note — a list row, Reminders-style, so it gets
                    // the system insets and sits inside the grouped list instead
                    // of straddling the header seam (bt-0009).
                    Section {
                        quickAddNoteRow
                    }

                    // Binary habits (compact icons). Avoidance entries mean a
                    // slip, so they get their own section instead of "Completed".
                    // Same win rule as Today: success / partial = completed,
                    // a multi-state "Tried" is its own section.
                    let completedIcons = viewModel.binaryHabits.filter { !$0.isNegativeHabit && $0.completionState != 3 && $0.completionState != 4 }
                    let triedIcons = viewModel.binaryHabits.filter { !$0.isNegativeHabit && $0.completionState == 3 }
                    let restIcons = viewModel.binaryHabits.filter { !$0.isNegativeHabit && $0.completionState == 4 }
                    let slippedIcons = viewModel.binaryHabits.filter { $0.isNegativeHabit }
                    if !completedIcons.isEmpty {
                        iconSection("Completed", entries: completedIcons)
                    }
                    if !triedIcons.isEmpty {
                        iconSection("Tried", entries: triedIcons)
                    }
                    if !restIcons.isEmpty {
                        iconSection("Rest", entries: restIcons)
                    }
                    if !slippedIcons.isEmpty {
                        iconSection("Slipped", entries: slippedIcons)
                    }

                    // Habits with data (workout, diet, etc.)
                    if !viewModel.habitsWithData.isEmpty {
                        Section("Activity Details") {
                            ForEach(viewModel.habitsWithData) { entry in
                                DataHabitRow(entry: entry)
                            }
                        }
                    }

                    // Notes section
                    if !viewModel.notes.isEmpty {
                        Section("Notes") {
                            ForEach(viewModel.notes) { note in
                                NoteRow(note: note, onTap: {
                                    viewModel.selectedNote = note
                                })
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    viewModel.deleteNote(viewModel.notes[index])
                                }
                            }
                        }
                    }

                    // Empty state
                    if viewModel.habitsWithData.isEmpty && viewModel.binaryHabits.isEmpty && viewModel.notes.isEmpty {
                        Section {
                            ContentUnavailableView {
                                Label("No Entries", systemImage: "doc.text")
                            } description: {
                                Text("Complete habits or add notes to see them here.")
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
            }
            .listStyle(.insetGrouped)
            .safeAreaBar(edge: .top) {
                dateSelector
            }
            .navigationTitle("Journal")
            .keepNavigationBarVisible() // large title like the other tabs; never minimises
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showingExportView = true }) {
                            Label("Export Journal...", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        // ShareLink presents from this view's own window, so it
                        // works in any window size / multi-window setup. Menu
                        // content is built when the menu opens, so the export
                        // text is only generated on demand.
                        ShareLink(item: viewModel.dayExportText()) {
                            Label("Quick Export This Day", systemImage: "doc.text")
                        }
                        ShareLink(item: viewModel.monthExportText()) {
                            Label("Quick Export This Month", systemImage: "calendar")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExportView) {
                JournalExportView()
            }
            .sheet(item: $viewModel.selectedNote, onDismiss: {
                viewModel.loadData()
            }) { note in
                EditNoteView(note: note)
            }
            .onAppear {
                viewModel.modelContext = modelContext
                if !hasLoadedOnce {
                    viewModel.loadData()
                    hasLoadedOnce = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    viewModel.loadData()
                }
            }
        }
    }

    // MARK: - Icon Section

    private func iconSection(_ title: String, entries: [JournalHabitEntry]) -> some View {
        Section(title) {
            FlowLayout(spacing: 12) {
                ForEach(entries) { entry in
                    BinaryHabitIcon(entry: entry)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        VStack(spacing: 6) {
            // Month/Year header with navigation
            HStack {
                Button("Previous week", systemImage: "chevron.left") {
                    viewModel.goToPreviousWeek()
                }
                .labelStyle(.iconOnly)
                .font(.footnote.weight(.semibold))
                .frame(minWidth: 32, minHeight: 32)

                Spacer()

                Text(viewModel.monthYearString)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button("Today") {
                    viewModel.goToToday()
                }
                .font(.caption)
                .opacity(viewModel.isToday ? 0 : 1)
                .disabled(viewModel.isToday)
                .accessibilityHidden(viewModel.isToday)

                Button("Next week", systemImage: "chevron.right") {
                    viewModel.goToNextWeek()
                }
                .labelStyle(.iconOnly)
                .font(.footnote.weight(.semibold))
                .frame(minWidth: 32, minHeight: 32)
                .disabled(viewModel.isToday)
            }
            .padding(.horizontal, 8)

            // One week of day squares with the weekday letters above — the same
            // square family as the Today grid (bt-0015 rule 3). The window is
            // anchored to today and the week arrows page it.
            let days = WeekGridMetrics.windowDays(for: viewModel.selectedDate, calendar: calendar)
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .sectionLabel()
                            .frame(maxWidth: .infinity)
                    }
                }
                .accessibilityHidden(true)

                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        JournalDayButton(
                            date: day,
                            isSelected: calendar.isDate(day, inSameDayAs: viewModel.selectedDate),
                            isToday: calendar.isDateInToday(day)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectDate(day)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
    }

    private var calendar: Calendar { Calendar.current }

    // MARK: - Quick Add Note Row

    private var quickAddNoteRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(.secondary)

            TextField("Add a note…", text: $newNoteText)
                .focused($isNoteFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    saveQuickNote()
                }

            if !newNoteText.isEmpty {
                Button("Add note", systemImage: "arrow.up.circle.fill", action: saveQuickNote)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .buttonStyle(.borderless)
            }
        }
    }

    private func saveQuickNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.addNote(trimmed)
        newNoteText = ""
        isNoteFieldFocused = false
    }
}

// MARK: - Journal Day Button

/// A day in the Journal strip: the shared `DaySquare` with the day number
/// inside. Selected = accent fill, today = accent outline, else empty.
struct JournalDayButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    /// Scales with text size, capped so seven still fit a folded phone.
    @ScaledMetric(relativeTo: .callout) private var scaledSize: CGFloat = 36
    private var size: CGFloat { min(scaledSize, 44) }

    private var isFuture: Bool { date > Date() }

    var body: some View {
        Button(action: onTap) {
            DaySquare(size: size, style: style) {
                Text(date.formatted(.dateTime.day()))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(textColor)
            }
            .frame(minHeight: 44) // comfortable tap target
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.35 : 1)
        .accessibilityLabel(accessibilityDateLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var style: DaySquare<Text>.Style {
        if isSelected { return .filled(AppTheme.accent) }
        if isToday { return .outlined(AppTheme.accent) }
        return .empty
    }

    private var textColor: Color {
        if isSelected { return AppTheme.readableForeground(onHex: AppTheme.accentHex) }
        if isToday { return AppTheme.accent }
        return .primary
    }

    /// "Saturday, October 24" (+ "Today" when it is).
    private var accessibilityDateLabel: String {
        let base = date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return isToday ? "\(base), Today" : base
    }
}

// MARK: - Data Habit Row (for habits with captured data)

struct DataHabitRow: View {
    let entry: JournalHabitEntry
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 10) {
                HabitIconTile(systemImage: entry.icon, colorHex: entry.color, size: tileSize)

                Text(entry.habitName)
                    .font(.body)
            }

            // Data content
            if let details = entry.parsedDetails {
                VStack(alignment: .leading, spacing: 6) {
                    if let types = details.workoutTypes, !types.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(types, id: \.self) { type in
                                Text(type)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        if let duration = details.duration, !duration.isEmpty {
                            Label("\(duration) min", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let intensity = details.intensity {
                            Label("\(intensity)/5", systemImage: "flame.fill")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.accent)
                        }
                    }

                    if let notes = details.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let rawDetails = entry.rawDetails, !rawDetails.isEmpty {
                Text(rawDetails)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Binary Habit Icon (simple completed indicator)

struct BinaryHabitIcon: View {
    let entry: JournalHabitEntry

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: entry.icon)
                .font(.title3)
                .foregroundStyle(iconColor)

            Text(entry.habitName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 44, maxWidth: 72)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        if entry.isNegativeHabit {
            return "\(entry.habitName), \(entry.completionState > 0 ? "slipped" : "avoided")"
        }
        switch entry.completionState {
        case 2: return "\(entry.habitName), partial"
        case 3: return "\(entry.habitName), tried"
        case 4: return "\(entry.habitName), rest day"
        case 5: return "\(entry.habitName), active day"
        default: return "\(entry.habitName), completed"
        }
    }

    /// Brand state colours, same as the Today squares.
    private var iconColor: Color {
        if entry.isNegativeHabit {
            return entry.completionState > 0 ? AppTheme.failed : AppTheme.success
        }
        switch entry.completionState {
        case 2: return AppTheme.partial
        case 3: return AppTheme.failed
        case 4: return AppTheme.rest
        case 5: return AppTheme.activeDay
        default: return AppTheme.success
        }
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let note: Note
    let onTap: () -> Void

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private var timeString: String {
        Self.timeFormatter.string(from: note.date ?? Date())
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Text(timeString)
                    .font(.caption)
                    .foregroundStyle(.secondary) // .tertiary is ~2.2:1 on white
                    .fixedSize()
                    .frame(minWidth: 60, alignment: .leading)

                Text(note.content ?? "")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (for workout type tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + rowHeight)
        }
    }
}

// MARK: - Data Models

struct JournalHabitEntry: Identifiable {
    let id: UUID
    let habitName: String
    let icon: String
    let color: String
    let completionState: Int
    let isNegativeHabit: Bool
    let rawDetails: String?
    let parsedDetails: ParsedDetails?

    var hasData: Bool {
        return parsedDetails != nil || (rawDetails.map { !$0.isEmpty } ?? false)
    }

    struct ParsedDetails {
        let workoutTypes: [String]?
        let duration: String?
        let intensity: Int?
        let notes: String?
    }
}

// MARK: - View Model

@MainActor
@Observable
class DayJournalViewModel {
    var selectedDate: Date
    var habitsWithData: [JournalHabitEntry] = []
    var binaryHabits: [JournalHabitEntry] = []
    var notes: [Note] = []
    var selectedNote: Note?
    var visibleDays: [Date] = []

    /// Set by the view in `.onAppear`; SwiftData contexts can't be created in the VM's init.
    var modelContext: ModelContext?

    private let calendar = Calendar.current
    private let daysToShow = 60

    var dateString: String {
        DateFormatters.fullDate.string(from: selectedDate)
    }

    var dayOfWeekString: String {
        DateFormatters.dayOfWeek.string(from: selectedDate)
    }

    var monthYearString: String {
        DateFormatters.monthYear.string(from: selectedDate)
    }

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    init() {
        self.selectedDate = Calendar.current.startOfDay(for: Date())
        generateVisibleDays()
    }

    func loadData() {
        loadHabitEntries()
        loadNotes()
    }

    // MARK: - Day Slider Navigation

    private func generateVisibleDays() {
        var days: [Date] = []
        let today = calendar.startOfDay(for: Date())

        for offset in stride(from: -(daysToShow - 1), through: 0, by: 1) {
            if let date = calendar.date(byAdding: .day, value: offset, to: today) {
                days.append(date)
            }
        }

        visibleDays = days
    }

    func selectDate(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        loadData()
    }

    func goToPreviousWeek() {
        if let newDate = calendar.date(byAdding: .day, value: -7, to: selectedDate) {
            let startOfNewDate = calendar.startOfDay(for: newDate)
            if let firstVisible = visibleDays.first,
               startOfNewDate < firstVisible {
                var newDays: [Date] = []
                for offset in stride(from: -7, through: -1, by: 1) {
                    if let date = calendar.date(byAdding: .day, value: offset, to: firstVisible) {
                        newDays.append(date)
                    }
                }
                visibleDays = newDays + visibleDays
            }
            selectedDate = newDate
            loadData()
        }
    }

    func goToNextWeek() {
        if let newDate = calendar.date(byAdding: .day, value: 7, to: selectedDate),
           newDate <= Date() {
            selectedDate = newDate
            loadData()
        }
    }

    func goToPreviousDay() {
        if let newDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) {
            selectedDate = newDate
            loadData()
        }
    }

    func goToNextDay() {
        if let newDate = calendar.date(byAdding: .day, value: 1, to: selectedDate),
           newDate <= Date() {
            selectedDate = newDate
            loadData()
        }
    }

    func goToToday() {
        selectedDate = calendar.startOfDay(for: Date())
        loadData()
    }

    private func loadHabitEntries() {
        guard let context = modelContext else { return }
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        // Full fetch + in-Swift filter (Wave 3a pattern; see file header).
        let allEntries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []
        // Logged days AND note-only days (bt-0014: Log Details → Done can save
        // notes against a day that isn't marked).
        let entries = allEntries
            .filter { entry in
                entry.date >= startOfDay && entry.date < endOfDay
                    && (entry.effectiveCompletionState != .notDone || entry.details != nil)
            }
            .sorted { ($0.habit?.order ?? 0) < ($1.habit?.order ?? 0) }

        var withData: [JournalHabitEntry] = []
        var binary: [JournalHabitEntry] = []

        for entry in entries {
            guard let habit = entry.habit else { continue }

            let legacyString = legacyDetailsString(from: entry.details)
            let parsed = parseDetails(legacyString)
            let journalEntry = JournalHabitEntry(
                id: entry.id ?? UUID(),
                habitName: habit.name ?? "Unknown",
                icon: habit.icon ?? "circle",
                color: habit.color ?? "#007AFF",
                completionState: Int(entry.effectiveCompletionState.rawValue),
                isNegativeHabit: habit.completionStyle == .avoidance,
                rawDetails: legacyString,
                parsedDetails: parsed
            )

            if journalEntry.hasData {
                withData.append(journalEntry)
            } else if entry.effectiveCompletionState != .notDone {
                binary.append(journalEntry)
            }
        }

        habitsWithData = withData
        binaryHabits = binary
    }

    /// Convert the typed `HabitEntryDetails` back to the legacy JSON-string shape
    /// that the existing parsing code (`parseDetails` + the export-to-text path)
    /// was written against. Same wire format `BackupManager` emits — keeps the
    /// rendering/export downstream unchanged while the model goes typed.
    private func legacyDetailsString(from details: HabitEntryDetails?) -> String? {
        guard let details else { return nil }
        var dict: [String: Any] = [:]
        switch details {
        case .notes(let notes):
            dict["notes"] = notes
        case .workout(let types, let duration, let intensity, let notes):
            dict["types"] = types
            dict["type"] = types.first ?? ""
            dict["duration"] = duration
            dict["intensity"] = intensity
            dict["notes"] = notes
        case .reading(let bookTitle, let pagesRead, let notes):
            dict["bookTitle"] = bookTitle
            dict["pagesRead"] = pagesRead
            dict["notes"] = notes
        case .mood(let mood, let notes):
            dict["mood"] = mood
            dict["notes"] = notes
        }
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private func parseDetails(_ details: String?) -> JournalHabitEntry.ParsedDetails? {
        guard let details = details,
              let data = details.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let types = json["types"] as? [String]
        let duration = json["duration"] as? String
        let intensity = json["intensity"] as? Int
        let notes = json["notes"] as? String

        if types != nil || duration != nil || intensity != nil || (notes.map { !$0.isEmpty } ?? false) {
            return JournalHabitEntry.ParsedDetails(
                workoutTypes: types,
                duration: duration,
                intensity: intensity,
                notes: notes
            )
        }

        return nil
    }

    private func loadNotes() {
        guard let context = modelContext else { return }
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        notes = allNotes
            .filter { note in
                guard let date = note.date else { return false }
                return date >= startOfDay && date < endOfDay
            }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
    }

    func addNote(_ content: String) {
        guard let context = modelContext else { return }

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: Date())

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        let noteDate = calendar.date(from: combined) ?? selectedDate
        let note = Note(date: noteDate, content: content)
        context.insert(note)

        do {
            try context.save()
            loadNotes()
        } catch {
            debugLog("Failed to save note: \(error.localizedDescription)")
        }
    }

    func deleteNote(_ note: Note) {
        guard let context = modelContext else { return }
        context.delete(note)

        do {
            try context.save()
            loadNotes()
        } catch {
            debugLog("Failed to delete note: \(error.localizedDescription)")
        }
    }

    // MARK: - Export

    /// Plain-text export of the selected day, for `ShareLink`.
    func dayExportText() -> String {
        buildExportData(for: [selectedDate])
    }

    /// Plain-text export of the selected day's whole month, for `ShareLink`.
    func monthExportText() -> String {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return ""
        }

        var dates: [Date] = []
        var currentDate = startOfMonth
        while currentDate <= endOfMonth {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endOfMonth
        }

        return buildExportData(for: dates)
    }

    private func buildExportData(for dates: [Date]) -> String {
        var lines: [String] = []
        guard let context = modelContext else { return "" }
        let dateFormatter = DateFormatters.iso

        // Fetch the full tables once, filter per-day in Swift (Wave 3a pattern).
        let allHabitEntries = (try? context.fetch(FetchDescriptor<HabitEntry>())) ?? []
        let allNotes = (try? context.fetch(FetchDescriptor<Note>())) ?? []

        for date in dates {
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }

            let habitEntries = allHabitEntries.filter { entry in
                entry.date >= startOfDay && entry.date < endOfDay && entry.effectiveCompletionState != .notDone
            }

            let notes = allNotes.filter { note in
                guard let noteDate = note.date else { return false }
                return noteDate >= startOfDay && noteDate < endOfDay
            }

            if !habitEntries.isEmpty || !notes.isEmpty {
                lines.append("=== \(dateFormatter.string(from: date)) ===")
                lines.append("")

                for entry in habitEntries {
                    let habitName = entry.habit?.name ?? "Unknown"
                    lines.append("• \(habitName)")

                    if let details = legacyDetailsString(from: entry.details), !details.isEmpty {
                        if let data = details.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let types = json["types"] as? [String], !types.isEmpty {
                                lines.append("  Types: \(types.joined(separator: ", "))")
                            }
                            if let duration = json["duration"] as? String, !duration.isEmpty {
                                lines.append("  Duration: \(duration) min")
                            }
                            if let intensity = json["intensity"] as? Int {
                                lines.append("  Intensity: \(intensity)/5")
                            }
                            if let notes = json["notes"] as? String, !notes.isEmpty {
                                lines.append("  Notes: \(notes)")
                            }
                        } else {
                            lines.append("  \(details)")
                        }
                    }
                }

                if !notes.isEmpty {
                    lines.append("")
                    lines.append("Notes:")
                    for note in notes {
                        lines.append("- \(note.content ?? "")")
                    }
                }

                lines.append("")
            }
        }

        return lines.joined(separator: "\n")
    }
}

#Preview {
    DayJournalView()
}
