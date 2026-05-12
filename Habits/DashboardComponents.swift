//
//  DashboardComponents.swift
//  Bullet Tracker
//
//  Reusable UI components for dashboard views
//

import SwiftUI

// MARK: - Contribution Heatmap View

struct ContributionHeatmapView: View {
    let dates: [Date]
    let completionData: [Date: Double]
    var habitColor: Color = Color(hex: "#4CAF50")

    private let dayLabelWidth: CGFloat = 16
    private let monthLabelHeight: CGFloat = 16
    private let maxCellSize: CGFloat = 32
    private let minCellSize: CGFloat = 7
    private static let monthSymbols = Calendar.current.shortMonthSymbols

    @State private var containerWidth: CGFloat = UIScreen.main.bounds.width - 40

    // MARK: - Week Columns

    private var weekColumns: [[Date?]] {
        let calendar = Calendar.current
        guard let firstDate = dates.first, let lastDate = dates.last else { return [] }

        let dateSet = Set(dates.map { calendar.startOfDay(for: $0) })
        let firstWeekday = calendar.component(.weekday, from: firstDate)
        guard let weekStart = calendar.date(byAdding: .day, value: -(firstWeekday - 1), to: firstDate) else { return [] }

        var columns: [[Date?]] = []
        var current = weekStart
        while current <= lastDate {
            var week: [Date?] = []
            for d in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: d, to: current) else {
                    week.append(nil)
                    continue
                }
                let normalized = calendar.startOfDay(for: day)
                week.append(dateSet.contains(normalized) ? normalized : nil)
            }
            columns.append(week)
            guard let next = calendar.date(byAdding: .day, value: 7, to: current) else { break }
            current = next
        }
        return columns
    }

    // MARK: - Month Groups

    private struct MonthGroup: Identifiable {
        let id = UUID()
        let label: String
        let columns: [[Date?]]
    }

    private var monthGroups: [MonthGroup] {
        let calendar = Calendar.current
        let columns = weekColumns
        guard !columns.isEmpty else { return [] }

        var groups: [MonthGroup] = []
        var currentMonth = -1
        var currentColumns: [[Date?]] = []
        var currentLabel = ""

        for column in columns {
            guard let firstDay = column.compactMap({ $0 }).first else {
                currentColumns.append(column)
                continue
            }

            let month = calendar.component(.month, from: firstDay)

            if month != currentMonth {
                if !currentColumns.isEmpty {
                    groups.append(MonthGroup(label: currentLabel, columns: currentColumns))
                }
                currentMonth = month
                currentLabel = Self.monthSymbols[month - 1]
                currentColumns = [column]
            } else {
                currentColumns.append(column)
            }
        }

        if !currentColumns.isEmpty {
            groups.append(MonthGroup(label: currentLabel, columns: currentColumns))
        }

        return groups
    }

    // MARK: - Dynamic Sizing

    private var computedCellSize: CGFloat {
        let cols = weekColumns
        let groups = monthGroups
        guard !cols.isEmpty, !groups.isEmpty else { return 14 }
        let totalWeeks = CGFloat(cols.count)
        let numGroups = CGFloat(groups.count)
        let cellSpacing: CGFloat = 2
        let monthGap: CGFloat = 6

        let available = containerWidth - dayLabelWidth - 4
        let spacingCost = (totalWeeks - numGroups) * cellSpacing + max(numGroups - 1, 0) * monthGap
        let size = (available - spacingCost) / totalWeeks
        return max(minCellSize, min(maxCellSize, size))
    }

    private var cellSpacing: CGFloat { computedCellSize <= 10 ? 1.5 : 2 }
    private var monthGap: CGFloat { computedCellSize <= 10 ? 4 : 6 }

    private var needsScroll: Bool {
        let cols = weekColumns
        let groups = monthGroups
        guard !cols.isEmpty, !groups.isEmpty else { return false }
        let totalWeeks = CGFloat(cols.count)
        let numGroups = CGFloat(groups.count)
        let available = containerWidth - dayLabelWidth - 4
        let spacingCost = (totalWeeks - numGroups) * 2 + max(numGroups - 1, 0) * 6
        return (available - spacingCost) / totalWeeks < minCellSize
    }

    // MARK: - Body

    var body: some View {
        let groups = monthGroups

        if groups.isEmpty {
            Text("No activity data")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            let size = computedCellSize

            VStack(spacing: 0) {
                // Width reader (zero height, full width)
                Color.clear
                    .frame(height: 0)
                    .frame(maxWidth: .infinity)
                    .background(GeometryReader { geo in
                        Color.clear
                            .onAppear { containerWidth = geo.size.width }
                            .onChange(of: geo.size.width) { _, w in containerWidth = w }
                    })

                // Grid
                HStack(alignment: .top, spacing: 4) {
                    dayLabelsColumn(cellSize: size)

                    if needsScroll {
                        ScrollView(.horizontal, showsIndicators: false) {
                            gridContent(groups: groups, cellSize: size)
                        }
                    } else {
                        gridContent(groups: groups, cellSize: size)
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private func gridContent(groups: [MonthGroup], cellSize: CGFloat) -> some View {
        HStack(alignment: .top, spacing: monthGap) {
            ForEach(groups) { group in
                monthGroupView(group, cellSize: cellSize)
            }
        }
    }

    private func dayLabelsColumn(cellSize: CGFloat) -> some View {
        VStack(spacing: cellSpacing) {
            Text("")
                .font(.caption)
                .frame(height: monthLabelHeight)
            ForEach(0..<7, id: \.self) { row in
                Text(dayLabel(for: row))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .frame(width: dayLabelWidth, height: cellSize)
            }
        }
    }

    private func monthGroupView(_ group: MonthGroup, cellSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: cellSpacing) {
            Text(group.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(height: monthLabelHeight)

            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(0..<group.columns.count, id: \.self) { col in
                        if let date = group.columns[col][row] {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(cellColor(for: date))
                                .frame(width: cellSize, height: cellSize)
                        } else {
                            Color.clear
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func dayLabel(for row: Int) -> String {
        switch row {
        case 1: return "M"
        case 3: return "W"
        case 5: return "F"
        default: return ""
        }
    }

    private func cellColor(for date: Date) -> Color {
        let rate = completionData[date] ?? 0
        if rate >= 1.0 { return habitColor }
        if rate > 0 { return habitColor.opacity(0.4) }
        return Color(.systemGray5)
    }
}
