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
    @State private var viewModel = JournalExportViewModel()

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
@Observable
class JournalExportViewModel {
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
    var rangeType: DateRangeType = .thisWeek
    var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    var customEndDate: Date = Date()

    // Format
    var selectedFormat: ExportFormat = .pdf

    // Options
    var includeSummaryDashboard: Bool = true

    // Preview counts
    var previewDayCount: Int = 0
    var previewHabitCount: Int = 0
    var previewNoteCount: Int = 0

    // Export state
    var isExporting = false
    var showingShareSheet = false
    var showingSuccess = false
    var showingError = false
    var errorMessage = ""
    var exportedFileURL: URL?

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

        let dayCount = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        previewDayCount = dayCount + 1

        let context = CoreDataManager.shared.container.viewContext
        guard let endOfRange = calendar.date(byAdding: .day, value: 1, to: endDate) else { return }

        let habitRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        habitRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND completionState > 0",
            startDate as NSDate, endOfRange as NSDate
        )
        previewHabitCount = (try? context.count(for: habitRequest)) ?? 0

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

        let format = selectedFormat
        let includeSummary = includeSummaryDashboard

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

#Preview {
    JournalExportView()
}
