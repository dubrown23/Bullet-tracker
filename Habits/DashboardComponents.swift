//
//  DashboardComponents.swift
//  Bullet Tracker
//
//  Reusable UI components for dashboard views
//

import SwiftUI

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(Color(UIColor.tertiaryLabel))

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(UIColor.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
}

// MARK: - Habit Stat Row

struct HabitStatRow: View {
    let stat: HabitStatData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: stat.color).opacity(0.15))
                        .frame(width: 28, height: 28)

                    Image(systemName: stat.icon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: stat.color))
                }

                Text(stat.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(UIColor.label))

                Spacer()

                Text("\(stat.completionRate)%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(UIColor.secondaryLabel))

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: stat.color))
                        .frame(width: geometry.size.width * CGFloat(stat.completionRate) / 100, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Calendar Heatmap View

struct CalendarHeatmapView: View {
    let dates: [Date]
    let completionData: [Date: Double]
    var habitColor: Color = Color(hex: "#4CAF50")  // Green

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let dayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day labels
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 2) {
                // Add empty cells for alignment
                ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                }

                // Date cells
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

    private let calendar = Calendar.current

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
            return Color.gray.opacity(0.15)
        }
    }
}

// MARK: - Previews

#Preview("StatBox") {
    HStack {
        StatBox(title: "Completion", value: "85%", color: .blue)
        StatBox(title: "Streak", value: "12", color: .orange)
        StatBox(title: "Best", value: "30", color: .green)
    }
    .padding()
}

#Preview("StatCard") {
    HStack {
        StatCard(title: "Completion", value: "85%", subtitle: "this month", color: .blue)
        StatCard(title: "Streak", value: "12", subtitle: "days", color: .orange)
    }
    .padding()
}
