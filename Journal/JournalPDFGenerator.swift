//
//  JournalPDFGenerator.swift
//  Bullet Tracker
//
//  PDF generation for journal export
//

import UIKit
import CoreData

// MARK: - Data Types

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

// MARK: - PDF Generator

struct JournalPDFGenerator {
    static let pageWidth: CGFloat = 612  // US Letter
    static let pageHeight: CGFloat = 792
    static let margin: CGFloat = 50
    static var contentWidth: CGFloat { pageWidth - (margin * 2) }

    // MARK: - Shared Text Attributes

    private enum TextStyle {
        static let pageTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: UIColor.black
        ]
        static let sectionTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 22),
            .foregroundColor: UIColor.black
        ]
        static let dayHeader: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]
        static let sectionHeader: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        static let noteHeader: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        static let subtitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.darkGray
        ]
        static let statLabel: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13),
            .foregroundColor: UIColor.darkGray
        ]
        static let statValue: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor.black
        ]
        static let noteContent: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        static let habit: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        static let tableHeader: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        static let tableRow: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        static let detail: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.darkGray
        ]
        static let noteTime: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        static let noData: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.gray
        ]
    }

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

    // MARK: - PDF Generation

    static func generatePDF(startDate: Date, endDate: Date, includeSummary: Bool = false) -> Data {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let data = pdfRenderer.pdfData { context in
            if includeSummary {
                drawSummaryDashboard(startDate: startDate, endDate: endDate, context: context)
            }

            let calendar = Calendar.current
            var currentDate = startDate
            var yPosition: CGFloat = 0

            context.beginPage()
            yPosition = margin

            "Daily Details".draw(at: CGPoint(x: margin, y: yPosition), withAttributes: TextStyle.sectionTitle)
            yPosition += 35

            var hasAnyData = false

            while currentDate <= endDate {
                let dayData = fetchDayData(for: currentDate)

                if !dayData.habits.isEmpty || !dayData.notes.isEmpty {
                    hasAnyData = true

                    let estimatedHeight = estimateDayHeight(habits: dayData.habits, notes: dayData.notes)

                    if yPosition + estimatedHeight > pageHeight - margin {
                        context.beginPage()
                        yPosition = margin
                    }

                    yPosition = drawDayHeader(currentDate, at: yPosition, context: context)

                    if !dayData.habits.isEmpty {
                        yPosition = drawHabitsSection(dayData.habits, at: yPosition, context: context)
                    }

                    if !dayData.notes.isEmpty {
                        yPosition = drawNotesSection(dayData.notes, at: yPosition, context: context)
                    }

                    yPosition += 25
                }

                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(86400)
            }

            if !hasAnyData {
                "No journal entries found for the selected date range.".draw(
                    at: CGPoint(x: margin, y: yPosition + 20),
                    withAttributes: TextStyle.noData
                )
            }
        }

        return data
    }

    // MARK: - Height Estimation

    private static func estimateDayHeight(habits: [PDFHabitEntry], notes: [PDFNoteEntry]) -> CGFloat {
        var height: CGFloat = 50

        if !habits.isEmpty {
            let simpleHabits = habits.filter { $0.details == nil || $0.details?.isEmpty == true }
            let detailedHabits = habits.filter { $0.details != nil && $0.details?.isEmpty == false }

            if !simpleHabits.isEmpty {
                let estimatedRows = min(3, (simpleHabits.count / 4) + 1)
                height += CGFloat(estimatedRows) * 18 + 8
            }

            height += CGFloat(detailedHabits.count) * 18
            height += 8
        }

        if !notes.isEmpty {
            height += 25
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

        let stats = calculateStats(startDate: startDate, endDate: endDate)

        "Habit Report".draw(at: CGPoint(x: margin, y: yPos), withAttributes: TextStyle.pageTitle)
        yPos += 40

        let rangeText = "\(summaryDateFormatter.string(from: startDate)) - \(summaryDateFormatter.string(from: endDate))"
        rangeText.draw(at: CGPoint(x: margin, y: yPos), withAttributes: TextStyle.subtitle)
        yPos += 35

        drawDivider(at: yPos)
        yPos += 25

        yPos = drawOverviewStats(stats: stats, at: yPos)
        yPos += 30

        _ = drawHabitPerformanceTable(stats: stats, at: yPos, context: context)
    }

    private static func drawOverviewStats(stats: ReportStats, at y: CGFloat) -> CGFloat {
        var yPos = y

        "Overview".draw(at: CGPoint(x: margin, y: yPos), withAttributes: TextStyle.sectionHeader)
        yPos += 30

        let col1X = margin
        let col2X = margin + contentWidth / 2

        // Row 1
        "Total Days:".draw(at: CGPoint(x: col1X, y: yPos), withAttributes: TextStyle.statLabel)
        "\(stats.totalDays)".draw(at: CGPoint(x: col1X + 100, y: yPos), withAttributes: TextStyle.statValue)
        "Habits Tracked:".draw(at: CGPoint(x: col2X, y: yPos), withAttributes: TextStyle.statLabel)
        "\(stats.totalHabits)".draw(at: CGPoint(x: col2X + 110, y: yPos), withAttributes: TextStyle.statValue)
        yPos += 22

        // Row 2
        "Overall Completion:".draw(at: CGPoint(x: col1X, y: yPos), withAttributes: TextStyle.statLabel)
        "\(String(format: "%.0f%%", stats.overallCompletionRate * 100))".draw(at: CGPoint(x: col1X + 130, y: yPos), withAttributes: TextStyle.statValue)
        "Total Completions:".draw(at: CGPoint(x: col2X, y: yPos), withAttributes: TextStyle.statLabel)
        "\(stats.totalCompletions)".draw(at: CGPoint(x: col2X + 120, y: yPos), withAttributes: TextStyle.statValue)
        yPos += 22

        // Row 3
        "Notes Added:".draw(at: CGPoint(x: col1X, y: yPos), withAttributes: TextStyle.statLabel)
        "\(stats.totalNotes)".draw(at: CGPoint(x: col1X + 100, y: yPos), withAttributes: TextStyle.statValue)
        if let bestStreak = stats.bestStreak {
            "Best Streak:".draw(at: CGPoint(x: col2X, y: yPos), withAttributes: TextStyle.statLabel)
            "\(bestStreak.streak) days (\(bestStreak.habitName))".draw(at: CGPoint(x: col2X + 85, y: yPos), withAttributes: TextStyle.statValue)
        }
        yPos += 22

        return yPos
    }

    private static func drawHabitPerformanceTable(stats: ReportStats, at y: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var yPos = y + 15

        "Habit Performance".draw(at: CGPoint(x: margin, y: yPos), withAttributes: TextStyle.sectionHeader)
        yPos += 30

        let col1 = margin
        let col2 = margin + 180
        let col3 = margin + 280
        let col4 = margin + 360

        "Habit".draw(at: CGPoint(x: col1, y: yPos), withAttributes: TextStyle.tableHeader)
        "Rate".draw(at: CGPoint(x: col2, y: yPos), withAttributes: TextStyle.tableHeader)
        "Done".draw(at: CGPoint(x: col3, y: yPos), withAttributes: TextStyle.tableHeader)
        "Expected".draw(at: CGPoint(x: col4, y: yPos), withAttributes: TextStyle.tableHeader)
        yPos += 20

        drawDivider(at: yPos - 5)
        yPos += 5

        let sortedHabits = stats.habitStats.sorted { $0.completionRate > $1.completionRate }

        for habitStat in sortedHabits {
            if yPos > pageHeight - 80 {
                context.beginPage()
                yPos = margin
            }

            let displayName = habitStat.name.count > 25 ? String(habitStat.name.prefix(22)) + "..." : habitStat.name
            displayName.draw(at: CGPoint(x: col1, y: yPos), withAttributes: TextStyle.tableRow)

            let rateText = String(format: "%.0f%%", habitStat.completionRate * 100)
            rateText.draw(at: CGPoint(x: col2, y: yPos), withAttributes: TextStyle.tableRow)
            "\(habitStat.completed)".draw(at: CGPoint(x: col3, y: yPos), withAttributes: TextStyle.tableRow)
            "\(habitStat.expected)".draw(at: CGPoint(x: col4, y: yPos), withAttributes: TextStyle.tableRow)

            yPos += 18
        }

        return yPos + 10
    }

    private static func drawDivider(at y: CGFloat) {
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: y))
        linePath.addLine(to: CGPoint(x: margin + contentWidth, y: y))
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

        let totalDays = (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0) + 1
        let allHabits = CoreDataManager.shared.fetchAllHabits()
        let totalHabits = allHabits.count

        let entryRequest: NSFetchRequest<HabitEntry> = HabitEntry.fetchRequest()
        entryRequest.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND completionState > 0",
            startDate as NSDate, endOfRange as NSDate
        )
        let entries = (try? context.fetch(entryRequest)) ?? []
        let totalCompletions = entries.count

        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        noteRequest.predicate = NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endOfRange as NSDate)
        let totalNotes = (try? context.count(for: noteRequest)) ?? 0

        var habitStats: [HabitStat] = []
        var totalExpected = 0
        var totalActual = 0

        for habit in allHabits {
            guard let habitId = habit.id else { continue }

            var expected = 0
            var currentDate = startDate
            while currentDate <= endDate {
                if shouldPerformHabit(habit, on: currentDate) {
                    expected += 1
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate.addingTimeInterval(86400)
            }

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

    // MARK: - Drawing Helpers

    private static func drawDayHeader(_ date: Date, at y: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var yPos = y

        dayHeaderFormatter.string(from: date).draw(at: CGPoint(x: margin, y: yPos), withAttributes: TextStyle.dayHeader)
        yPos += 30

        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: margin, y: yPos))
        linePath.addLine(to: CGPoint(x: margin + contentWidth, y: yPos))
        UIColor.lightGray.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()

        yPos += 20
        return yPos
    }

    private static func drawHabitsSection(_ habits: [PDFHabitEntry], at y: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var yPos = y

        let simpleHabits = habits.filter { $0.details == nil || $0.details?.isEmpty == true }
        let detailedHabits = habits.filter { $0.details != nil && $0.details?.isEmpty == false }

        // Draw simple habits horizontally (wrapped flow)
        if !simpleHabits.isEmpty {
            var xPos = margin
            let itemSpacing: CGFloat = 8
            let rowHeight: CGFloat = 18

            for habit in simpleHabits {
                let stateIcon = habit.isNegativeHabit ? "✗" : "✓"
                let habitText = "\(stateIcon) \(habit.name)"
                let textSize = (habitText as NSString).size(withAttributes: TextStyle.habit)

                if xPos + textSize.width > margin + contentWidth {
                    xPos = margin
                    yPos += rowHeight

                    if yPos > pageHeight - 80 {
                        context.beginPage()
                        yPos = margin
                    }
                }

                habitText.draw(at: CGPoint(x: xPos, y: yPos), withAttributes: TextStyle.habit)
                xPos += textSize.width + itemSpacing
            }
            yPos += rowHeight + 8
        }

        // Draw detailed habits vertically
        if !detailedHabits.isEmpty {
            for habit in detailedHabits {
                if yPos > pageHeight - 80 {
                    context.beginPage()
                    yPos = margin
                }

                let stateIcon = habit.isNegativeHabit ? "✗" : "✓"
                let habitText = "\(stateIcon) \(habit.name): "

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

                habitText.draw(at: CGPoint(x: margin, y: yPos), withAttributes: TextStyle.habit)
                let nameWidth = (habitText as NSString).size(withAttributes: TextStyle.habit).width

                let maxDetailWidth = contentWidth - nameWidth
                let wrappedDetails = wrapText(detailString, width: maxDetailWidth, font: UIFont.systemFont(ofSize: 10))

                for (index, line) in wrappedDetails.enumerated() {
                    let xOffset = index == 0 ? margin + nameWidth : margin + 15
                    line.draw(at: CGPoint(x: xOffset, y: yPos), withAttributes: TextStyle.detail)
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

    private static func drawNotesSection(_ notes: [PDFNoteEntry], at y: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var yPos = y

        "Notes".draw(at: CGPoint(x: margin, y: yPos), withAttributes: TextStyle.noteHeader)
        yPos += 25

        for note in notes {
            if yPos > pageHeight - 100 {
                context.beginPage()
                yPos = margin
            }

            note.time.draw(at: CGPoint(x: margin + 10, y: yPos), withAttributes: TextStyle.noteTime)

            let wrappedLines = wrapText(note.content, width: contentWidth - 80, font: UIFont.systemFont(ofSize: 12))
            for (_, line) in wrappedLines.enumerated() {
                line.draw(at: CGPoint(x: margin + 70, y: yPos), withAttributes: TextStyle.noteContent)
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
