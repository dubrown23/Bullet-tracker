//
//  DashboardComponents.swift
//  Bullet Tracker
//
//  Reusable UI components for dashboard views
//

import SwiftUI

// MARK: - Calendar Heatmap View

struct CalendarHeatmapView: View {
    let dates: [Date]
    let completionData: [Date: Double]
    var habitColor: Color = Color(hex: "#4CAF50")

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day labels
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                ForEach(dates, id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        completionRate: completionData[date] ?? 0,
                        color: habitColor
                    )
                }
            }
        }
    }

    private var leadingEmptyCells: Int {
        guard let firstDate = dates.first else { return 0 }
        let weekday = Calendar.current.component(.weekday, from: firstDate)
        return weekday - 1
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let completionRate: Double
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
            .aspectRatio(1, contentMode: .fit)
    }

    private var cellColor: Color {
        if completionRate >= 1.0 {
            return color
        } else if completionRate > 0 {
            return color.opacity(0.5)
        } else {
            return Color(.systemGray5)
        }
    }
}
