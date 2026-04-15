//
//  HabitGridCollectionView.swift
//  Bullet Tracker
//
//  Synchronized scrolling habit grid using ScrollPosition (iOS 17+)
//  - Date column fixed on left, scrolls vertically with checkboxes
//  - Habit headers scroll horizontally, synced with checkboxes
//  - Single vertical scroll for dates + checkboxes
//

import SwiftUI

// MARK: - Main Grid View

struct HabitGridView: View {
    let habits: [Habit]
    let dates: [Date]
    let dataRepository: HabitDataRepository
    let onHabitTap: (Habit) -> Void
    let onHabitLongPress: (Habit) -> Void

    // MARK: - Size Class Adaptation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Adaptive dimensions based on size class
    private var dateColumnWidth: CGFloat {
        horizontalSizeClass == .regular ? 72 : 52
    }

    private var habitColumnWidth: CGFloat {
        horizontalSizeClass == .regular ? 70 : 50
    }

    private var rowHeight: CGFloat {
        horizontalSizeClass == .regular ? 64 : 50
    }

    private var headerHeight: CGFloat {
        horizontalSizeClass == .regular ? 72 : 56
    }

    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 18 : 14
    }

    private var headerIconSize: CGFloat {
        horizontalSizeClass == .regular ? 40 : 32
    }

    // Shared scroll position for horizontal sync between header and checkboxes
    @State private var headerScrollPosition = ScrollPosition(edge: .leading)
    @State private var checkboxScrollPosition = ScrollPosition(edge: .leading)

    // Track which scroll is being dragged to prevent feedback loops
    @State private var isHeaderScrolling = false
    @State private var isCheckboxScrolling = false

    var body: some View {
        if dates.isEmpty {
            emptyState(message: "No dates to display")
        } else if habits.isEmpty {
            emptyState(message: "No habits to display")
        } else {
            mainGrid
                .environment(dataRepository)
        }
    }

    // MARK: - Empty State

    private func emptyState(message: String) -> some View {
        VStack {
            Text(message)
                .foregroundColor(.secondary)
                .padding()
            Spacer()
        }
        .environment(dataRepository)
    }

    // MARK: - Main Grid

    private var mainGrid: some View {
        GeometryReader { geometry in
            let checkboxAreaWidth = geometry.size.width - dateColumnWidth

            VStack(spacing: 0) {
                // FIXED HEADER ROW
                headerRow(checkboxAreaWidth: checkboxAreaWidth)

                Divider()

                // SCROLLABLE CONTENT
                ScrollViewReader { verticalProxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 0) {
                            // Date column
                            dateColumn

                            // Checkbox grid with horizontal scroll
                            checkboxGrid(width: checkboxAreaWidth)
                        }
                    }
                    .onAppear {
                        scrollToToday(proxy: verticalProxy)
                    }
                }
            }
        }
    }

    // MARK: - Header Row

    private func headerRow(checkboxAreaWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            // Top-left: "Date" label
            Text("Date")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: dateColumnWidth, height: headerHeight)
                .background(Color(UIColor.systemBackground))

            // Habit headers - scrollable, synced with checkbox grid
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        habitHeaderCell(habit: habit)
                            .id("header-\(index)")
                    }
                }
            }
            .scrollPosition($headerScrollPosition)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.x
            } action: { oldValue, newValue in
                guard !isCheckboxScrolling else { return }
                isHeaderScrolling = true
                checkboxScrollPosition.scrollTo(x: newValue)
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    isHeaderScrolling = false
                }
            }
            .frame(width: checkboxAreaWidth, height: headerHeight)
            .background(Color(UIColor.systemBackground))
        }
        .background(Color(UIColor.systemBackground))
    }

    private func habitHeaderCell(habit: Habit) -> some View {
        let color = Color(hex: habit.color ?? "#007AFF")
        let nameFontSize: CGFloat = horizontalSizeClass == .regular ? 11 : 9

        return Button(action: { onHabitTap(habit) }) {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: headerIconSize, height: headerIconSize)

                    Image(systemName: habit.icon ?? "circle")
                        .font(.system(size: iconSize))
                        .foregroundColor(color)
                }

                Text(habit.name ?? "")
                    .font(.system(size: nameFontSize, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: habitColumnWidth, height: headerHeight)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            onHabitLongPress(habit)
        }
    }

    // MARK: - Date Column

    private var dateColumn: some View {
        VStack(spacing: 4) {
            ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                dateLabelView(date: date)
                    .id("row-\(index)")
            }
        }
        .frame(width: dateColumnWidth)
        .padding(.vertical, 4)
        .background(Color(UIColor.systemBackground))
    }

    private func dateLabelView(date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isWeekend = Calendar.current.isDateInWeekend(date)

        let dayText = DateFormatters.shortDayOfWeek.string(from: date)
        let dateText = DateFormatters.dayNumber.string(from: date)

        // Adaptive font sizes
        let dayFontSize: CGFloat = horizontalSizeClass == .regular ? 12 : 10
        let dateFontSize: CGFloat = horizontalSizeClass == .regular ? 17 : 14

        return VStack(spacing: 1) {
            Text(dayText)
                .font(.system(size: dayFontSize, weight: .medium))
                .foregroundColor(isToday ? .white : (isWeekend ? AppTheme.accent : .secondary))

            Text(dateText)
                .font(.system(size: dateFontSize, weight: isToday ? .bold : .semibold))
                .foregroundColor(isToday ? .white : .primary)
        }
        .frame(width: dateColumnWidth - 4, height: rowHeight - 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .fill(isToday ? AppTheme.accent : (isWeekend ? AppTheme.accent.opacity(0.1) : Color(UIColor.tertiarySystemBackground)))
        )
        .shadow(
            color: isToday ? AppTheme.accent.opacity(0.3) : .clear,
            radius: 4,
            x: 0,
            y: 2
        )
        .frame(height: rowHeight)
    }

    // MARK: - Checkbox Grid

    private func checkboxGrid(width: CGFloat) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                    checkboxRow(date: date, rowIndex: index)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollPosition($checkboxScrollPosition)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.x
        } action: { oldValue, newValue in
            guard !isHeaderScrolling else { return }
            isCheckboxScrolling = true
            headerScrollPosition.scrollTo(x: newValue)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                isCheckboxScrolling = false
            }
        }
        .frame(width: width)
    }

    private func checkboxRow(date: Date, rowIndex: Int) -> some View {
        let isToday = Calendar.current.isDateInToday(date)

        return HStack(spacing: 0) {
            ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                HabitCheckboxView(habit: habit, date: date)
                    .frame(width: habitColumnWidth, height: rowHeight - 8)
                    .id("cell-\(rowIndex)-\(index)")
            }
        }
        .padding(.horizontal, 4)
        .frame(height: rowHeight)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .fill(isToday ? AppTheme.todayHighlight : AppTheme.cardBackground)
                .shadow(
                    color: Color.black.opacity(0.04),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        )
    }

    // MARK: - Scroll to Today

    private func scrollToToday(proxy: ScrollViewProxy) {
        if let todayIndex = dates.firstIndex(where: { Calendar.current.isDateInToday($0) }) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation {
                    proxy.scrollTo("row-\(todayIndex)", anchor: .center)
                }
            }
        }
    }
}
