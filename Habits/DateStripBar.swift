//
//  DateStripBar.swift
//  Bullet Tracker
//
//  bt-0023 — the Journal's date picker as one shared piece: month + year
//  with week arrows and a Today button, the weekday letters, then seven
//  `DaySquare` day buttons anchored to today (`WeekGridMetrics.windowDays`).
//  Meant for `.safeAreaBar(edge: .top)` under a large title. The Dashboard
//  uses it; the Journal keeps its own copy until its reassessment turn.
//
//  App target only (it leans on `WeekGridMetrics` and `JournalDayButton`),
//  which is why it isn't in `DesignSystem.swift`, a file the widget shares.
//

import SwiftUI

struct DateStripBar: View {
    @Binding var selectedDate: Date

    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(selectedDate) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button("Previous week", systemImage: "chevron.left") { move(days: -7) }
                    .labelStyle(.iconOnly)
                    .font(.footnote.weight(.semibold))
                    .frame(minWidth: 32, minHeight: 32)

                Spacer()

                Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Spacer()

                Button("Today") { select(calendar.startOfDay(for: Date())) }
                    .font(.caption)
                    .opacity(isToday ? 0 : 1)
                    .disabled(isToday)
                    .accessibilityHidden(isToday)

                Button("Next week", systemImage: "chevron.right") { move(days: 7) }
                    .labelStyle(.iconOnly)
                    .font(.footnote.weight(.semibold))
                    .frame(minWidth: 32, minHeight: 32)
                    .disabled(isToday)
            }
            .padding(.horizontal, 8)

            let days = WeekGridMetrics.windowDays(for: selectedDate, calendar: calendar)
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
                            isSelected: calendar.isDate(day, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(day)
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) { select(day) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
    }

    private func select(_ day: Date) {
        selectedDate = calendar.startOfDay(for: day)
    }

    /// A week back or forward, never past today.
    private func move(days: Int) {
        guard let moved = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        select(min(moved, Date()))
    }
}
