//
//  DayJournalView.swift
//  Bullet Tracker
//
//  View a complete picture of any day - habits data and notes
//

import SwiftUI
import CoreData
import Combine

struct DayJournalView: View {
    @StateObject private var viewModel = DayJournalViewModel()
    @State private var showingAddNote = false
    @State private var showingExportView = false
    @State private var newNoteText = ""
    @State private var hasLoadedOnce = false
    @FocusState private var isNoteFieldFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Date selector
                dateSelector

                // Quick add note bar at top
                quickAddNoteBar

                // Binary habits right under add note (quick glance)
                if !viewModel.binaryHabits.isEmpty {
                    binaryHabitsBar
                }

                // Content for selected day
                ScrollView {
                    VStack(spacing: 16) {
                        // Habits with data (workout, diet, etc.)
                        if !viewModel.habitsWithData.isEmpty {
                            dataHabitsSection
                        }

                        // Notes section
                        if !viewModel.notes.isEmpty {
                            notesSection
                        }

                        // Empty state
                        if viewModel.habitsWithData.isEmpty && viewModel.binaryHabits.isEmpty && viewModel.notes.isEmpty {
                            emptyState
                        }
                    }
                    .padding()
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
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
                    .accessibilityLabel("Export options")
                    .accessibilityHint("Export journal data")
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
                // Only load on first appear, not every tab switch
                if !hasLoadedOnce {
                    viewModel.loadData()
                    hasLoadedOnce = true
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Reload when app becomes active (to catch widget changes)
                if newPhase == .active {
                    viewModel.loadData()
                }
            }
        }
    }

    // MARK: - Date Selector

    private var dateSelector: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Month/Year header with navigation
            HStack {
                Button(action: { viewModel.goToPreviousWeek() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.accent)
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Text(viewModel.monthYearString)
                    .font(AppTheme.Font.headline)

                Spacer()

                // Today button - always show but disable/hide when already on today
                Button(action: {
                    viewModel.goToToday()
                }) {
                    Text("Today")
                        .font(AppTheme.Font.caption)
                        .foregroundColor(AppTheme.accent)
                }
                .frame(width: 50)
                .opacity(viewModel.isToday ? 0 : 1)
                .disabled(viewModel.isToday)

                Button(action: { viewModel.goToNextWeek() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(viewModel.isToday ? .gray.opacity(0.5) : AppTheme.accent)
                        .frame(width: 32, height: 32)
                }
                .disabled(viewModel.isToday)
            }
            .padding(.horizontal, AppTheme.Spacing.sm)

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
        HStack(spacing: AppTheme.Spacing.md) {
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
                        .foregroundColor(AppTheme.accent)
                }
            }
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(AppTheme.cardBackground)
    }

    private func saveQuickNote() {
        let trimmed = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        viewModel.addNote(trimmed)
        newNoteText = ""
        isNoteFieldFocused = false
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.accent)
            }

            Text("No entries for this day")
                .font(AppTheme.Font.title)
                .foregroundColor(AppTheme.textPrimary)

            Text("Complete habits or add notes above")
                .font(AppTheme.Font.body)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    // MARK: - Data Habits Section (Workout, Diet, etc.)

    private var dataHabitsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.caption)
                    .foregroundColor(AppTheme.accent)
                Text("Activity Details")
                    .font(AppTheme.Font.callout)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.xs)

            ForEach(viewModel.habitsWithData) { entry in
                DataHabitCard(entry: entry)
            }
        }
    }

    // MARK: - Binary Habits Bar (compact wrapping grid at top)

    private var binaryHabitsBar: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(AppTheme.success)
                Text("Completed")
                    .font(AppTheme.Font.callout)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.sm)

            FlowLayout(spacing: AppTheme.Spacing.md) {
                ForEach(viewModel.binaryHabits) { entry in
                    BinaryHabitIcon(entry: entry)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.bottom, AppTheme.Spacing.md)
        }
        .background(AppTheme.cardBackground)
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundColor(AppTheme.accentLight)
                Text("Notes")
                    .font(AppTheme.Font.callout)
                    .foregroundColor(AppTheme.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.xs)

            VStack(spacing: 1) {
                ForEach(viewModel.notes) { note in
                    NoteRow(note: note, onTap: {
                        viewModel.selectedNote = note
                    }, onDelete: {
                        viewModel.deleteNote(note)
                    })
                }
            }
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.Radius.medium)
            .shadow(color: AppTheme.Shadow.small.color, radius: AppTheme.Shadow.small.radius, x: AppTheme.Shadow.small.x, y: AppTheme.Shadow.small.y)
        }
    }
}

// MARK: - Day Cell Component

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let onTap: () -> Void

    // Size class adaptation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Adaptive dimensions
    private var cellWidth: CGFloat {
        horizontalSizeClass == .regular ? 56 : 44
    }

    private var cellHeight: CGFloat {
        horizontalSizeClass == .regular ? 68 : 56
    }

    private var dayNumberSize: CGFloat {
        horizontalSizeClass == .regular ? 22 : 18
    }

    private var dayOfWeekSize: CGFloat {
        horizontalSizeClass == .regular ? 12 : 10
    }

    private var dayNumber: String {
        DateFormatters.dayNumber.string(from: date)
    }

    private var dayOfWeek: String {
        DateFormatters.shortDayOfWeek.string(from: date).prefix(3).uppercased()
    }

    private var isWeekend: Bool {
        Calendar.current.isDateInWeekend(date)
    }

    private var isFuture: Bool {
        date > Date()
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.system(size: dayNumberSize, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(textColor)

                Text(dayOfWeek)
                    .font(.system(size: dayOfWeekSize, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
            }
            .frame(width: cellWidth, height: cellHeight)
            .background(backgroundView)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .opacity(isFuture ? 0.4 : 1.0)
        .accessibilityLabel("\(dayOfWeek) \(dayNumber)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return AppTheme.accent
        } else if isWeekend {
            return AppTheme.accentLight
        } else {
            return AppTheme.textPrimary
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .fill(AppTheme.accent)
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 4, x: 0, y: 2)
        } else if isToday {
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .strokeBorder(AppTheme.accent, lineWidth: 2)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .fill(AppTheme.accent.opacity(0.1))
                )
        } else {
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .fill(AppTheme.cardBackground)
        }
    }
}

// MARK: - Data Habit Card (for habits with captured data)

struct DataHabitCard: View {
    let entry: JournalHabitEntry

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            // Header with icon
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: entry.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: entry.color))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: entry.color).opacity(0.15))
                    .cornerRadius(AppTheme.Radius.small)

                Text(entry.habitName)
                    .font(AppTheme.Font.callout)
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()
            }

            // Data content
            if let details = entry.parsedDetails {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    // Workout types as tags
                    if let types = details.workoutTypes, !types.isEmpty {
                        FlowLayout(spacing: AppTheme.Spacing.sm) {
                            ForEach(types, id: \.self) { type in
                                Text(type)
                                    .font(AppTheme.Font.caption)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .padding(.horizontal, AppTheme.Spacing.md)
                                    .padding(.vertical, AppTheme.Spacing.xs)
                                    .background(Color(UIColor.tertiarySystemFill))
                                    .cornerRadius(AppTheme.Radius.small)
                            }
                        }
                    }

                    // Duration and intensity in a row
                    HStack(spacing: AppTheme.Spacing.lg) {
                        if let duration = details.duration, !duration.isEmpty {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text("\(duration) min")
                                    .font(AppTheme.Font.body)
                            }
                            .foregroundColor(AppTheme.textPrimary)
                        }

                        if let intensity = details.intensity {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                Image(systemName: "flame.fill")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.accent)
                                Text("\(intensity)/5")
                                    .font(AppTheme.Font.body)
                            }
                            .foregroundColor(AppTheme.textPrimary)
                        }
                    }

                    // Notes
                    if let notes = details.notes, !notes.isEmpty {
                        Text(notes)
                            .font(AppTheme.Font.body)
                            .foregroundColor(AppTheme.textPrimary)
                            .padding(.top, AppTheme.Spacing.xxs)
                    }
                }
            } else if let rawDetails = entry.rawDetails, !rawDetails.isEmpty {
                Text(rawDetails)
                    .font(AppTheme.Font.body)
                    .foregroundColor(AppTheme.textPrimary)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.cardBackground)
        .cornerRadius(AppTheme.Radius.medium)
        .shadow(color: AppTheme.Shadow.small.color, radius: AppTheme.Shadow.small.radius, x: AppTheme.Shadow.small.x, y: AppTheme.Shadow.small.y)
    }
}

// MARK: - Binary Habit Icon (simple completed indicator)

struct BinaryHabitIcon: View {
    let entry: JournalHabitEntry

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Image(systemName: entry.icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)

            Text(entry.habitName)
                .font(.system(size: 8))
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 44)
    }

    private var iconColor: Color {
        if entry.isNegativeHabit {
            // Negative habit marked = relapse (red)
            return entry.completionState > 0 ? AppTheme.failed : AppTheme.success
        }
        // Normal habit completed = green
        return AppTheme.success
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let note: Note
    let onTap: () -> Void
    let onDelete: () -> Void

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
            HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
                Text(timeString)
                    .font(AppTheme.Font.caption)
                    .foregroundColor(AppTheme.textTertiary)
                    .frame(width: 60, alignment: .leading)

                Text(note.content ?? "")
                    .font(AppTheme.Font.body)
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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
class DayJournalViewModel: ObservableObject {
    @Published var selectedDate: Date
    @Published var habitsWithData: [JournalHabitEntry] = []
    @Published var binaryHabits: [JournalHabitEntry] = []
    @Published var notes: [Note] = []
    @Published var selectedNote: Note?
    @Published var visibleDays: [Date] = []

    private let calendar = Calendar.current
    private let daysToShow = 60 // Show 60 days back

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
        // Initialize selectedDate to start of today
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

        // Generate days from 60 days ago to today
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
            // Extend visible days if needed
            let startOfNewDate = calendar.startOfDay(for: newDate)
            if let firstVisible = visibleDays.first,
               startOfNewDate < firstVisible {
                // Add more days to the beginning
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
        let context = CoreDataManager.shared.container.viewContext
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let request: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND completionState > 0",
            startOfDay as NSDate, endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(key: "habit.order", ascending: true)]

        do {
            let entries = try context.fetch(request)
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
        } catch {
            habitsWithData = []
            binaryHabits = []
        }
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
        let context = CoreDataManager.shared.container.viewContext
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date < %@",
                                        startOfDay as NSDate, endOfDay as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        do {
            notes = try context.fetch(request)
        } catch {
            notes = []
        }
    }

    func addNote(_ content: String) {
        let context = CoreDataManager.shared.container.viewContext
        let note = Note(context: context)
        note.id = UUID()
        note.content = content

        // Use selected date with current time
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: Date())

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        note.date = calendar.date(from: combined) ?? selectedDate

        do {
            try context.save()
            loadNotes()
        } catch {
            debugLog("Failed to save note: \(error.localizedDescription)")
        }
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
        let context = CoreDataManager.shared.container.viewContext
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for date in dates {
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }

            let habitRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
            habitRequest.predicate = NSPredicate(
                format: "date >= %@ AND date < %@ AND completionState > 0",
                startOfDay as NSDate, endOfDay as NSDate
            )

            let habitEntries = (try? context.fetch(habitRequest)) ?? []

            let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
            noteRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@",
                                                startOfDay as NSDate, endOfDay as NSDate)

            let notes = (try? context.fetch(noteRequest)) ?? []

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
