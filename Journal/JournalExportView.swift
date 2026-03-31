//
//  JournalExportView.swift
//  Bullet Tracker
//
//  Export journal data with flexible date ranges and formats
//

import SwiftUI
import CoreData
import PDFKit
import UniformTypeIdentifiers

// MARK: - Export View

struct JournalExportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = JournalExportViewModel()

    var body: some View {
        NavigationStack {
            Form {
                dateRangeSection
                formatSection
                optionsSection
                previewSection
            }
            .navigationTitle("Export Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isExporting {
                        ProgressView()
                    } else {
                        Button("Export") {
                            viewModel.performExport()
                        }
                        .disabled(!viewModel.canExport)
                    }
                }
            }
            .onChange(of: viewModel.rangeType) { _, _ in
                viewModel.updatePreview()
            }
            .onChange(of: viewModel.customStartDate) { _, _ in
                viewModel.updatePreview()
            }
            .onChange(of: viewModel.customEndDate) { _, _ in
                viewModel.updatePreview()
            }
            .sheet(isPresented: $viewModel.showingShareSheet) {
                if let url = viewModel.exportedFileURL {
                    ShareSheet(url: url) {
                        viewModel.showingSuccess = true
                    }
                }
            }
            .alert("Export Complete", isPresented: $viewModel.showingSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your journal has been saved successfully.")
            }
            .alert("Export Failed", isPresented: $viewModel.showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    // MARK: - Date Range Section

    private var dateRangeSection: some View {
        Section {
            Picker("Range", selection: $viewModel.rangeType) {
                Text("Today").tag(DateRangeType.today)
                Text("This Week").tag(DateRangeType.thisWeek)
                Text("This Month").tag(DateRangeType.thisMonth)
                Text("Custom").tag(DateRangeType.custom)
            }
            .pickerStyle(.segmented)

            if viewModel.rangeType == .custom {
                DatePicker("Start Date", selection: $viewModel.customStartDate, displayedComponents: .date)
                DatePicker("End Date", selection: $viewModel.customEndDate, displayedComponents: .date)
            }

            // Show selected range
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text(viewModel.dateRangeDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Date Range")
        }
    }

    // MARK: - Format Section

    private var formatSection: some View {
        Section {
            ForEach(ExportFormat.allCases, id: \.self) { format in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(format.title)
                            .font(.body)
                        Text(format.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if viewModel.selectedFormat == format {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedFormat = format
                }
            }
        } header: {
            Text("Format")
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        Section {
            if viewModel.selectedFormat == .pdf {
                Toggle(isOn: $viewModel.includeSummaryDashboard) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Include Summary Dashboard")
                            .font(.body)
                        Text("Adds overview page with stats & analytics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Options")
        } footer: {
            if viewModel.selectedFormat == .pdf && viewModel.includeSummaryDashboard {
                Text("The PDF will start with a dashboard showing completion rates, streaks, and habit performance, followed by daily details.")
            }
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("\(viewModel.previewDayCount) days", systemImage: "calendar")
                    Spacer()
                }

                HStack {
                    Label("\(viewModel.previewHabitCount) habit entries", systemImage: "checkmark.circle")
                    Spacer()
                }

                HStack {
                    Label("\(viewModel.previewNoteCount) notes", systemImage: "note.text")
                    Spacer()
                }

                if viewModel.selectedFormat == .pdf && viewModel.includeSummaryDashboard {
                    HStack {
                        Label("Summary dashboard", systemImage: "chart.bar.fill")
                        Spacer()
                    }
                    .foregroundColor(.blue)
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        } header: {
            Text("Export Preview")
        } footer: {
            Text("The export will include all completed habits and notes for the selected date range.")
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    var onComplete: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if completed {
                onComplete?()
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Types

enum DateRangeType: String, CaseIterable {
    case today
    case thisWeek
    case thisMonth
    case custom
}

enum ExportFormat: String, CaseIterable {
    case pdf
    case json

    var title: String {
        switch self {
        case .pdf: return "PDF Document"
        case .json: return "JSON Backup"
        }
    }

    var description: String {
        switch self {
        case .pdf: return "Nicely formatted for reading & archiving"
        case .json: return "Complete data backup for restore"
        }
    }

    var fileExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .json: return "json"
        }
    }
}

// MARK: - View Model

@MainActor
class JournalExportViewModel: ObservableObject {
    // MARK: - Static Formatters

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    static let fileNameDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    // Date range
    @Published var rangeType: DateRangeType = .thisWeek
    @Published var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var customEndDate: Date = Date()

    // Format
    @Published var selectedFormat: ExportFormat = .pdf

    // Options
    @Published var includeSummaryDashboard: Bool = true

    // Preview counts
    @Published var previewDayCount: Int = 0
    @Published var previewHabitCount: Int = 0
    @Published var previewNoteCount: Int = 0

    // Export state
    @Published var isExporting = false
    @Published var showingShareSheet = false
    @Published var showingSuccess = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var exportedFileURL: URL?

    private let calendar = Calendar.current

    var canExport: Bool {
        previewHabitCount > 0 || previewNoteCount > 0
    }

    var dateRangeDescription: String {
        let (start, end) = getDateRange()
        let formatter = Self.mediumDateFormatter

        if calendar.isDate(start, inSameDayAs: end) {
            return formatter.string(from: start)
        } else {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        }
    }

    init() {
        updatePreview()
    }

    func getDateRange() -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: Date())

        switch rangeType {
        case .today:
            return (today, today)

        case .thisWeek:
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
            return (weekStart, today)

        case .thisMonth:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
            return (monthStart, today)

        case .custom:
            let start = calendar.startOfDay(for: customStartDate)
            let end = calendar.startOfDay(for: customEndDate)
            return (min(start, end), max(start, end))
        }
    }

    func updatePreview() {
        let (startDate, endDate) = getDateRange()

        // Count days
        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        previewDayCount = dayCount + 1

        // Count habits and notes
        let context = CoreDataManager.shared.container.viewContext
        guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDate) else { return }

        // Habit entries
        let habitRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        habitRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND completionState > 0",
            startDate as NSDate, endOfRange as NSDate
        )
        previewHabitCount = (try? context.count(for: habitRequest)) ?? 0

        // Notes
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startDate as NSDate, endOfRange as NSDate
        )
        previewNoteCount = (try? context.count(for: noteRequest)) ?? 0
    }

    func performExport() {
        let (startDate, endDate) = getDateRange()
        isExporting = true

        // Capture values before background thread
        let format = selectedFormat
        let includeSummary = includeSummaryDashboard

        // Run export on background thread
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            switch format {
            case .pdf:
                await self.exportToPDF(startDate: startDate, endDate: endDate, includeSummary: includeSummary)
            case .json:
                await self.exportToJSON(startDate: startDate, endDate: endDate)
            }

            await MainActor.run {
                self.isExporting = false
            }
        }
    }

    // MARK: - PDF Export

    private func exportToPDF(startDate: Date, endDate: Date, includeSummary: Bool) async {

        // Generate PDF on background thread
        let pdfData = JournalPDFGenerator.generatePDF(
            startDate: startDate,
            endDate: endDate,
            includeSummary: includeSummary
        )

        let fmt = Self.fileNameDateFormatter

        let fileName: String
        if calendar.isDate(startDate, inSameDayAs: endDate) {
            fileName = "BulletTracker_Journal_\(fmt.string(from: startDate)).pdf"
        } else {
            fileName = "BulletTracker_Journal_\(fmt.string(from: startDate))-\(fmt.string(from: endDate)).pdf"
        }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

        do {
            try pdfData.write(to: tempURL)
            await MainActor.run {
                exportedFileURL = tempURL
                showingShareSheet = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save PDF: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    // MARK: - JSON Export

    private func exportToJSON(startDate: Date, endDate: Date) async {
        guard let jsonData = JournalJSONExporter.exportJournalData(startDate: startDate, endDate: endDate) else {
            await MainActor.run {
                errorMessage = "Failed to create JSON export"
                showingError = true
            }
            return
        }

        let fmt = Self.fileNameDateFormatter

        let fileName: String
        if calendar.isDate(startDate, inSameDayAs: endDate) {
            fileName = "BulletTracker_Journal_\(fmt.string(from: startDate)).json"
        } else {
            fileName = "BulletTracker_Journal_\(fmt.string(from: startDate))-\(fmt.string(from: endDate)).json"
        }

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)

        do {
            try jsonData.write(to: tempURL)
            await MainActor.run {
                exportedFileURL = tempURL
                showingShareSheet = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to save JSON: \(error.localizedDescription)"
                showingError = true
            }
        }
    }
}

// MARK: - PDF Generator

struct JournalPDFGenerator {
    static let pageWidth: CGFloat = 612  // US Letter
    static let pageHeight: CGFloat = 792
    static let margin: CGFloat = 50
    static var contentWidth: CGFloat { pageWidth - (margin * 2) }

    // MARK: - Static Formatters

    private static let summaryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter
    }()

    private static let dayHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let iso8601Formatter: ISO8601DateFormatter = {
        ISO8601DateFormatter()
    }()

    static func generatePDF(startDate: Date, endDate: Date, includeSummary: Bool = false) -> Data {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = pdfRenderer.pdfData { context in
            // Draw summary dashboard first if enabled
            if includeSummary {
                drawSummaryDashboard(startDate: startDate, endDate: endDate, context: context)
            }

            // Draw daily details - continuous flow
            let calendar = Calendar.current
            var currentDate = startDate
            var yPosition: CGFloat = 0

            // Start first details page
            context.beginPage()
            yPosition = margin

            // Add "Daily Details" header on first page
            let detailsHeaderAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 22),
                .foregroundColor: UIColor.black
            ]
            "Daily Details".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: detailsHeaderAttrs)
            yPosition += 35

            var hasAnyData = false

            while currentDate <= endDate {
                let dayData = fetchDayData(for: currentDate)

                // Only draw if there's data for this day
                if !dayData.habits.isEmpty || !dayData.notes.isEmpty {
                    hasAnyData = true

                    // Estimate space needed for this day
                    let estimatedHeight = estimateDayHeight(habits: dayData.habits, notes: dayData.notes)

                    // Check if we need a new page
                    if yPosition + estimatedHeight > pageHeight - margin {
                        context.beginPage()
                        yPosition = margin
                    }

                    // Draw day header
                    yPosition = drawDayHeader(currentDate, at: yPosition, margin: margin, width: contentWidth, context: context)

                    // Draw completed habits
                    if !dayData.habits.isEmpty {
                        yPosition = drawHabitsSection(dayData.habits, at: yPosition, margin: margin, width: contentWidth, pageHeight: pageHeight, context: context)
                    }

                    // Draw notes
                    if !dayData.notes.isEmpty {
                        yPosition = drawNotesSection(dayData.notes, at: yPosition, margin: margin, width: contentWidth, pageHeight: pageHeight, context: context)
                    }

                    // Add spacing between days
                    yPosition += 25
                }

                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(86400)
            }

            // If no data at all, show message
            if !hasAnyData {
                let noDataText = "No journal entries found for the selected date range."
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.gray
                ]
                noDataText.draw(at: CGPoint(x: margin, y: yPosition + 20), withAttributes: attrs)
            }
        }

        return data
    }

    private static func estimateDayHeight(habits: [PDFHabitEntry], notes: [PDFNoteEntry]) -> CGFloat {
        var height: CGFloat = 50 // Header + divider

        // Habits section - now horizontal, so much more compact
        if !habits.isEmpty {
            let simpleHabits = habits.filter { $0.details == nil || $0.details?.isEmpty == true }
            let detailedHabits = habits.filter { $0.details != nil && $0.details?.isEmpty == false }

            // Simple habits: estimate ~2 rows max for horizontal flow
            if !simpleHabits.isEmpty {
                let estimatedRows = min(3, (simpleHabits.count / 4) + 1)
                height += CGFloat(estimatedRows) * 18 + 8
            }

            // Detailed habits: one line each (compact now)
            height += CGFloat(detailedHabits.count) * 18
            height += 8
        }

        // Notes section
        if !notes.isEmpty {
            height += 25 // Section header
            for note in notes {
                let lines = max(1, note.content.count / 60)
                height += CGFloat(lines) * 16 + 8
            }
        }

        return height
    }

    // MARK: - Summary Dashboard

    private static func drawSummaryDashboard(startDate: Date, endDate: Date, context: UIGraphicsPDFRendererContext) {
        context.beginPage()
        var yPos: CGFloat = margin

        // Fetch all data for stats calculation
        let stats = calculateStats(startDate: startDate, endDate: endDate)

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: UIColor.black
        ]
        "Habit Report".draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttrs)
        yPos += 40

        // Date range subtitle
        let rangeText = "\(summaryDateFormatter.string(from: startDate)) - \(summaryDateFormatter.string(from: endDate))"
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        rangeText.draw(at: CGPoint(x: margin, y: yPos), withAttributes: subtitleAttrs)
        yPos += 35

        // Divider
        drawDivider(at: yPos, margin: margin, width: contentWidth)
        yPos += 25

        // Overview Stats Box
        yPos = drawOverviewStats(stats: stats, at: yPos)
        yPos += 30

        // Habit Performance Table
        _ = drawHabitPerformanceTable(stats: stats, at: yPos, context: context)
    }

    private static func drawOverviewStats(stats: ReportStats, at y: CGFloat) -> CGFloat {
        var yPos = y

        let sectionHeaderAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        "Overview".draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionHeaderAttrs)
        yPos += 30

        let statAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.darkGray
        ]

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.black
        ]

        // Stats grid - 2 columns
        let col1X = margin
        let col2X = margin + contentWidth / 2

        // Row 1
        "Total Days:".draw(at: CGPoint(x: col1X, y: yPos), withAttributes: statAttrs)
        "\(stats.totalDays)".draw(at: CGPoint(x: col1X + 100, y: yPos), withAttributes: valueAttrs)

        "Habits Tracked:".draw(at: CGPoint(x: col2X, y: yPos), withAttributes: statAttrs)
        "\(stats.totalHabits)".draw(at: CGPoint(x: col2X + 110, y: yPos), withAttributes: valueAttrs)
        yPos += 22

        // Row 2
        "Overall Completion:".draw(at: CGPoint(x: col1X, y: yPos), withAttributes: statAttrs)
        "\(String(format: "%.0f%%", stats.overallCompletionRate * 100))".draw(at: CGPoint(x: col1X + 130, y: yPos), withAttributes: valueAttrs)

        "Total Completions:".draw(at: CGPoint(x: col2X, y: yPos), withAttributes: statAttrs)
        "\(stats.totalCompletions)".draw(at: CGPoint(x: col2X + 120, y: yPos), withAttributes: valueAttrs)
        yPos += 22

        // Row 3
        "Notes Added:".draw(at: CGPoint(x: col1X, y: yPos), withAttributes: statAttrs)
        "\(stats.totalNotes)".draw(at: CGPoint(x: col1X + 100, y: yPos), withAttributes: valueAttrs)

        if let bestStreak = stats.bestStreak {
            "Best Streak:".draw(at: CGPoint(x: col2X, y: yPos), withAttributes: statAttrs)
            "\(bestStreak.streak) days (\(bestStreak.habitName))".draw(at: CGPoint(x: col2X + 85, y: yPos), withAttributes: valueAttrs)
        }
        yPos += 22

        return yPos
    }

    private static func drawHabitPerformanceTable(stats: ReportStats, at y: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var yPos = y + 15

        let sectionHeaderAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        "Habit Performance".draw(at: CGPoint(x: margin, y: yPos), withAttributes: sectionHeaderAttrs)
        yPos += 30

        // Table header
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]

        let rowAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]

        // Column positions
        let col1 = margin // Habit name
        let col2 = margin + 180 // Completion rate
        let col3 = margin + 280 // Completed
        let col4 = margin + 360 // Expected

        "Habit".draw(at: CGPoint(x: col1, y: yPos), withAttributes: headerAttrs)
        "Rate".draw(at: CGPoint(x: col2, y: yPos), withAttributes: headerAttrs)
        "Done".draw(at: CGPoint(x: col3, y: yPos), withAttributes: headerAttrs)
        "Expected".draw(at: CGPoint(x: col4, y: yPos), withAttributes: headerAttrs)
        yPos += 20

        // Draw line under header
        drawDivider(at: yPos - 5, margin: margin, width: contentWidth)
        yPos += 5

        // Sort habits by completion rate (highest first)
        let sortedHabits = stats.habitStats.sorted { $0.completionRate > $1.completionRate }

        for habitStat in sortedHabits {
            if yPos > pageHeight - 80 {
                context.beginPage()
                yPos = margin
            }

            // Truncate long names
            let displayName = habitStat.name.count > 25 ? String(habitStat.name.prefix(22)) + "..." : habitStat.name

            displayName.draw(at: CGPoint(x: col1, y: yPos), withAttributes: rowAttrs)

            let rateText = String(format: "%.0f%%", habitStat.completionRate * 100)
            rateText.draw(at: CGPoint(x: col2, y: yPos), withAttributes: rowAttrs)

            "\(habitStat.completed)".draw(at: CGPoint(x: col3, y: yPos), withAttributes: rowAttrs)
            "\(habitStat.expected)".draw(at: CGPoint(x: col4, y: yPos), withAttributes: rowAttrs)

            yPos += 18
        }

        return yPos + 10
    }

    private static func drawDivider(at y: CGFloat, margin: CGFloat, width: CGFloat) {
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: y))
        linePath.addLine(to: CGPoint(x: margin + width, y: y))
        UIColor.lightGray.setStroke()
        linePath.lineWidth = 0.5
        linePath.stroke()
    }

    // MARK: - Stats Calculation

    private static func calculateStats(startDate: Date, endDate: Date) -> ReportStats {
        let context = CoreDataManager.shared.container.viewContext
        let calendar = Calendar.current
        guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDate) else {
            return ReportStats(totalDays: 0, totalHabits: 0, totalCompletions: 0, totalNotes: 0, overallCompletionRate: 0, habitStats: [], bestStreak: nil)
        }

        // Calculate total days
        let totalDays = (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1

        // Fetch all habits
        let allHabits = CoreDataManager.shared.fetchAllHabits()
        let totalHabits = allHabits.count

        // Fetch entries in range
        let entryRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        entryRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND completionState > 0",
            startDate as NSDate, endOfRange as NSDate
        )
        let entries = (try? context.fetch(entryRequest)) ?? []
        let totalCompletions = entries.count

        // Fetch notes
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endOfRange as NSDate)
        let totalNotes = (try? context.count(for: noteRequest)) ?? 0

        // Calculate per-habit stats
        var habitStats: [HabitStat] = []
        var totalExpected = 0
        var totalActual = 0

        for habit in allHabits {
            guard let habitId = habit.id else { continue }

            // Calculate expected days for this habit
            var expected = 0
            var currentDate = startDate
            while currentDate <= endDate {
                if shouldPerformHabit(habit, on: currentDate) {
                    expected += 1
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(86400)
            }

            // Count actual completions
            let habitEntries = entries.filter { $0.habit?.id == habitId }
            let completed = habitEntries.count

            let completionRate = expected > 0 ? Double(completed) / Double(expected) : 0

            if expected > 0 {
                habitStats.append(HabitStat(
                    name: habit.name ?? "Unknown",
                    completed: completed,
                    expected: expected,
                    completionRate: completionRate,
                    isNegativeHabit: habit.isNegativeHabit
                ))

                totalExpected += expected
                totalActual += completed
            }
        }

        let overallCompletionRate = totalExpected > 0 ? Double(totalActual) / Double(totalExpected) : 0

        // Calculate best streak (simplified - current streak)
        var bestStreak: (habitName: String, streak: Int)?
        for habit in allHabits {
            let streak = HabitCalculationService.shared.calculateCurrentStreak(for: habit)
            if streak > 0 && (bestStreak.map { streak > $0.streak } ?? true) {
                bestStreak = (habit.name ?? "Unknown", streak)
            }
        }

        return ReportStats(
            totalDays: totalDays,
            totalHabits: totalHabits,
            totalCompletions: totalCompletions,
            totalNotes: totalNotes,
            overallCompletionRate: overallCompletionRate,
            habitStats: habitStats,
            bestStreak: bestStreak
        )
    }

    private static func shouldPerformHabit(_ habit: Habit, on date: Date) -> Bool {
        HabitFrequency.shouldTrack(
            frequency: habit.frequency,
            on: date,
            customDays: habit.customDays,
            startDate: habit.startDate
        )
    }



    // MARK: - Day Data

    private static func fetchDayData(for date: Date) -> (habits: [PDFHabitEntry], notes: [PDFNoteEntry]) {
        let context = CoreDataManager.shared.container.viewContext
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return ([], [])
        }

        // Fetch habit entries
        let habitRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        habitRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND completionState > 0",
            startOfDay as NSDate, endOfDay as NSDate
        )
        habitRequest.sortDescriptors = [NSSortDescriptor(key: "habit.order", ascending: true)]

        var habits: [PDFHabitEntry] = []
        if let entries = try? context.fetch(habitRequest) {
            for entry in entries {
                guard let habit = entry.habit else { continue }
                habits.append(PDFHabitEntry(
                    name: habit.name ?? "Unknown",
                    icon: habit.icon ?? "circle",
                    color: habit.color ?? "#007AFF",
                    details: entry.details,
                    completionState: Int(entry.completionState),
                    isNegativeHabit: habit.isNegativeHabit
                ))
            }
        }

        // Fetch notes
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startOfDay as NSDate, endOfDay as NSDate
        )
        noteRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        var notes: [PDFNoteEntry] = []
        if let fetchedNotes = try? context.fetch(noteRequest) {
            for note in fetchedNotes {
                notes.append(PDFNoteEntry(
                    content: note.content ?? "",
                    time: timeFormatter.string(from: note.date ?? Date())
                ))
            }
        }

        return (habits, notes)
    }

    private static func drawDayHeader(_ date: Date, at y: CGFloat, margin: CGFloat, width: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var yPos = y

        // Date title
        let dateString = dayHeaderFormatter.string(from: date)

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]

        dateString.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttrs)
        yPos += 30

        // Divider line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: yPos))
        linePath.addLine(to: CGPoint(x: margin + width, y: yPos))
        UIColor.lightGray.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()

        yPos += 20

        return yPos
    }

    private static func drawHabitsSection(_ habits: [PDFHabitEntry], at y: CGFloat, margin: CGFloat, width: CGFloat, pageHeight: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var yPos = y

        // Separate habits with and without details
        let simpleHabits = habits.filter { $0.details == nil || $0.details?.isEmpty == true }
        let detailedHabits = habits.filter { $0.details != nil && $0.details?.isEmpty == false }

        let habitAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]

        let detailAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]

        // Draw simple habits horizontally (wrapped flow)
        if !simpleHabits.isEmpty {
            var xPos = margin
            let itemSpacing: CGFloat = 8
            let rowHeight: CGFloat = 18

            for habit in simpleHabits {
                let stateIcon = habit.isNegativeHabit ? "✗" : "✓"
                let habitText = "\(stateIcon) \(habit.name)"
                let textSize = (habitText as NSString).size(withAttributes: habitAttrs)

                // Check if we need to wrap to next line
                if xPos + textSize.width > margin + width {
                    xPos = margin
                    yPos += rowHeight

                    // Check if we need a new page
                    if yPos > pageHeight - 80 {
                        context.beginPage()
                        yPos = margin
                    }
                }

                habitText.draw(at: CGPoint(x: xPos, y: yPos), withAttributes: habitAttrs)
                xPos += textSize.width + itemSpacing
            }
            yPos += rowHeight + 8
        }

        // Draw detailed habits (these need more space, show vertically but compact)
        if !detailedHabits.isEmpty {
            for habit in detailedHabits {
                // Check if we need a new page
                if yPos > pageHeight - 80 {
                    context.beginPage()
                    yPos = margin
                }

                let stateIcon = habit.isNegativeHabit ? "✗" : "✓"
                let habitText = "\(stateIcon) \(habit.name): "

                // Build detail string inline
                var detailString = ""
                if let details = habit.details,
                   let data = details.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                    var parts: [String] = []
                    if let types = json["types"] as? [String], !types.isEmpty {
                        parts.append(types.joined(separator: ", "))
                    }
                    if let duration = json["duration"] as? String, !duration.isEmpty {
                        parts.append("\(duration) min")
                    }
                    if let intensity = json["intensity"] as? Int {
                        parts.append("Intensity \(intensity)/5")
                    }
                    if let notes = json["notes"] as? String, !notes.isEmpty {
                        parts.append(notes)
                    }
                    detailString = parts.joined(separator: " • ")
                } else if let details = habit.details {
                    detailString = details
                }

                // Draw habit name
                habitText.draw(at: CGPoint(x: margin, y: yPos), withAttributes: habitAttrs)
                let nameWidth = (habitText as NSString).size(withAttributes: habitAttrs).width

                // Draw details inline
                let maxDetailWidth = width - nameWidth
                let wrappedDetails = wrapText(detailString, width: maxDetailWidth, font: UIFont.systemFont(ofSize: 10))

                for (index, line) in wrappedDetails.enumerated() {
                    let xOffset = index == 0 ? margin + nameWidth : margin + 15
                    line.draw(at: CGPoint(x: xOffset, y: yPos), withAttributes: detailAttrs)
                    if index < wrappedDetails.count - 1 {
                        yPos += 14
                    }
                }
                yPos += 16
            }
        }

        yPos += 8
        return yPos
    }

    private static func drawNotesSection(_ notes: [PDFNoteEntry], at y: CGFloat, margin: CGFloat, width: CGFloat, pageHeight: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var yPos = y

        // Section header
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        "Notes".draw(at: CGPoint(x: margin, y: yPos), withAttributes: headerAttrs)
        yPos += 25

        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]

        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]

        for note in notes {
            // Check if we need a new page
            if yPos > pageHeight - 100 {
                context.beginPage()
                yPos = margin
            }

            // Time
            note.time.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: timeAttrs)

            // Note content (wrapped)
            let wrappedLines = wrapText(note.content, width: width - 80, font: UIFont.systemFont(ofSize: 12))
            for (index, line) in wrappedLines.enumerated() {
                let xOffset: CGFloat = index == 0 ? margin + 70 : margin + 70
                line.draw(at: CGPoint(x: xOffset, y: yPos), withAttributes: noteAttrs)
                yPos += 16
            }

            yPos += 8
        }

        return yPos
    }

    private static func wrapText(_ text: String, width: CGFloat, font: UIFont) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var currentLine = ""

        for word in words {
            let testLine = currentLine.isEmpty ? word : "\(currentLine) \(word)"
            let testSize = (testLine as NSString).size(withAttributes: [.font: font])

            if testSize.width > width && !currentLine.isEmpty {
                lines.append(currentLine)
                currentLine = word
            } else {
                currentLine = testLine
            }
        }

        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines.isEmpty ? [""] : lines
    }
}

// MARK: - Stats Data Types

struct ReportStats {
    let totalDays: Int
    let totalHabits: Int
    let totalCompletions: Int
    let totalNotes: Int
    let overallCompletionRate: Double
    let habitStats: [HabitStat]
    let bestStreak: (habitName: String, streak: Int)?
}

struct HabitStat {
    let name: String
    let completed: Int
    let expected: Int
    let completionRate: Double
    let isNegativeHabit: Bool
}

// MARK: - Data Types for PDF

struct PDFHabitEntry {
    let name: String
    let icon: String
    let color: String
    let details: String?
    let completionState: Int
    let isNegativeHabit: Bool
}

struct PDFNoteEntry {
    let content: String
    let time: String
}

// MARK: - JSON Exporter

struct JournalJSONExporter {

    private static let iso8601Formatter = ISO8601DateFormatter()

    static func exportJournalData(startDate: Date, endDate: Date) -> Data? {
        let context = CoreDataManager.shared.container.viewContext
        let calendar = Calendar.current
        guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDate) else { return nil }

        var exportData: [String: Any] = [
            "exportDate": iso8601Formatter.string(from: Date()),
            "startDate": iso8601Formatter.string(from: startDate),
            "endDate": iso8601Formatter.string(from: endDate),
            "version": 1
        ]

        // Export habits
        var habitsArray: [[String: Any]] = []
        let habitRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        habitRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND completionState > 0",
            startDate as NSDate, endOfRange as NSDate
        )
        habitRequest.sortDescriptors = [
            NSSortDescriptor(key: "date", ascending: true),
            NSSortDescriptor(key: "habit.order", ascending: true)
        ]

        if let entries = try? context.fetch(habitRequest) {
            for entry in entries {
                guard let habit = entry.habit else { continue }

                var entryDict: [String: Any] = [
                    "date": iso8601Formatter.string(from: entry.date ?? Date()),
                    "habitName": habit.name ?? "",
                    "habitIcon": habit.icon ?? "",
                    "habitColor": habit.color ?? "",
                    "completionState": entry.completionState,
                    "isNegativeHabit": habit.isNegativeHabit
                ]

                if let details = entry.details {
                    entryDict["details"] = details
                }

                habitsArray.append(entryDict)
            }
        }
        exportData["habitEntries"] = habitsArray

        // Export notes
        var notesArray: [[String: Any]] = []
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@",
            startDate as NSDate, endOfRange as NSDate
        )
        noteRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        if let notes = try? context.fetch(noteRequest) {
            for note in notes {
                notesArray.append([
                    "date": iso8601Formatter.string(from: note.date ?? Date()),
                    "content": note.content ?? ""
                ])
            }
        }
        exportData["notes"] = notesArray

        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
}

#Preview {
    JournalExportView()
}
