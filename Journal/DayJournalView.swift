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
            VStack(spacing: 0) {
                // Date selector (custom — keep as-is, works well)
                dateSelector

                // Quick add note bar
                quickAddNoteBar

                // Main content
                List {
                    // Binary habits (compact completed icons)
                    if !viewModel.binaryHabits.isEmpty {
                        Section("Completed") {
                            FlowLayout(spacing: 12) {
                                ForEach(viewModel.binaryHabits) { entry in
                                    BinaryHabitIcon(entry: entry)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
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
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingExportView = true }) {
                            Label("Export Journal...", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(action: { viewModel.exportDayData() }) {
                            Label("Quick Export This Day", systemImage: "doc.text")
                        }
                        Button(action: { viewModel.exportMonthData() }) {
                            Label("Quick Export This Month", systemImage: "calendar")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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

    // MARK: - Date Selector

    private var dateSelector: some View {
        VStack(spacing: 6) {
            // Month/Year header with navigation
            HStack {
                Button(action: { viewModel.goToPreviousWeek() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Text(viewModel.monthYearString)
                    .font(.headline)

                Spacer()

                Button("Today") {
                    viewModel.goToToday()
                }
                .font(.caption)
                .frame(width: 50)
                .opacity(viewModel.isToday ? 0 : 1)
                .disabled(viewModel.isToday)

                Button(action: { viewModel.goToNextWeek() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(viewModel.isToday ? Color.secondary : Color.accentColor)
                        .frame(width: 32, height: 32)
                }
                .disabled(viewModel.isToday)
            }
            .padding(.horizontal, 8)

            // Horizontal day slider
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.visibleDays, id: \.self) { date in
                            DayCell(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                                isToday: Calendar.current.isDateInToday(date),
                                onTap: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.selectDate(date)
                                    }
                                }
                            )
                            .id(date)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .onChange(of: viewModel.selectedDate) { _, newDate in
                    withAnimation {
                        proxy.scrollTo(calendar.startOfDay(for: newDate), anchor: .center)
                    }
                }
                .onAppear {
                    proxy.scrollTo(calendar.startOfDay(for: viewModel.selectedDate), anchor: .center)
                }
            }
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var calendar: Calendar { Calendar.current }

    // MARK: - Quick Add Note Bar

    private var quickAddNoteBar: some View {
        HStack(spacing: 12) {
            TextField("Add a note...", text: $newNoteText)
                .textFieldStyle(.plain)
                .focused($isNoteFieldFocused)
                .submitLabel(.done)
                .onSubmit {
                    saveQuickNote()
                }

            if !newNoteText.isEmpty {
                Button(action: saveQuickNote) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    private func saveQuickNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.addNote(trimmed)
        newNoteText = ""
        isNoteFieldFocused = false
    }
}

// MARK: - Day Cell Component

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    private var dayNumber: String {
        DateFormatters.dayNumber.string(from: date)
    }

    private var dayOfWeek: String {
        DateFormatters.shortDayOfWeek.string(from: date).prefix(3).uppercased()
    }

    private var isFuture: Bool {
        date > Date()
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.system(size: 18, weight: isSelected ? .bold : .semibold))
                    .foregroundStyle(textColor)

                Text(dayOfWeek)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(width: 44, height: 56)
            .background(backgroundView)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.4 : 1.0)
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .accentColor
        } else {
            return .primary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor)
        } else if isToday {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.1))
                )
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        }
    }
}

// MARK: - Data Habit Row (for habits with captured data)

struct DataHabitRow: View {
    let entry: JournalHabitEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: entry.icon)
                    .font(.body)
                    .foregroundStyle(Color(hex: entry.color))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: entry.color).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

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
                                .foregroundStyle(.orange)
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
                .font(.system(size: 20))
                .foregroundStyle(iconColor)

            Text(entry.habitName)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 44)
    }

    private var iconColor: Color {
        if entry.isNegativeHabit {
            return entry.completionState > 0 ? .red : .green
        }
        return .green
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
                    .foregroundStyle(.tertiary)
                    .frame(width: 60, alignment: .leading)

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
        let entries = allEntries
            .filter { entry in
                guard let date = entry.date else { return false }
                return date >= startOfDay && date < endOfDay && entry.completionState > 0
            }
            .sorted { ($0.habit?.order ?? 0) < ($1.habit?.order ?? 0) }

        var withData: [JournalHabitEntry] = []
        var binary: [JournalHabitEntry] = []

        for entry in entries {
            guard let habit = entry.habit else { continue }

            let parsed = parseDetails(entry.details)
            let journalEntry = JournalHabitEntry(
                id: entry.id ?? UUID(),
                habitName: habit.name ?? "Unknown",
                icon: habit.icon ?? "circle",
                color: habit.color ?? "#007AFF",
                completionState: Int(entry.completionState),
                isNegativeHabit: habit.isNegativeHabit,
                rawDetails: entry.details,
                parsedDetails: parsed
            )

            if journalEntry.hasData {
                withData.append(journalEntry)
            } else {
                binary.append(journalEntry)
            }
        }

        habitsWithData = withData
        binaryHabits = binary
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

    func exportDayData() {
        let export = buildExportData(for: [selectedDate])
        shareText(export)
    }

    func exportMonthData() {
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            return
        }

        var dates: [Date] = []
        var currentDate = startOfMonth
        while currentDate <= endOfMonth {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endOfMonth
        }

        let export = buildExportData(for: dates)
        shareText(export)
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
                guard let entryDate = entry.date else { return false }
                return entryDate >= startOfDay && entryDate < endOfDay && entry.completionState > 0
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

                    if let details = entry.details, !details.isEmpty {
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

    private func shareText(_ text: String) {
        guard !text.isEmpty else { return }

        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

#Preview {
    DayJournalView()
}
