//
//  DesignSystem.swift
//  Bullet Tracker
//
//  The handful of shared pieces that keep the app visually consistent
//  (bt-0015). Everything here is built from system styles; the point is that
//  each decision is made once:
//
//  • Palette      — `AppTheme` (App/AppTheme.swift): accent, success, partial,
//                   failed. No literal colours in app code; `.red` only as the
//                   destructive tint.
//  • Shape        — `AppShape`: continuous corners at 22% of the element size.
//  • Icon tile    — `HabitIconTile`: an SF Symbol on a tint of its habit colour.
//  • Seven days   — `DaySquare` + `WeekdayLetterStrip`: the Journal and
//                   Dashboard date strips.
//  • One day      — `DayMark` (what happened, in palette colours only),
//                   `DayControl` (the round mark-it control) and `DayDot`
//                   / `DayDotStrip` (quiet history). The Today row (bt-0026);
//                   the shared style the Journal and Dashboard adopt later.
//  • Labels       — `.sectionLabel()`: the grouped-list header look (footnote,
//                   uppercase, secondary) for column/day labels.
//

import SwiftUI

// MARK: - Shape

enum AppShape {
    /// Corner radius for a square-ish element of `size` points.
    static func radius(for size: CGFloat) -> CGFloat { size * 0.22 }

    static func rounded(_ size: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius(for: size), style: .continuous)
    }
}

// MARK: - Icon tile

/// A habit's SF Symbol on a soft tint of its colour. Decorative: callers put
/// the habit's name right next to it, so it's hidden from VoiceOver.
struct HabitIconTile: View {
    let systemImage: String
    let colorHex: String
    var size: CGFloat = 28
    var font: Font = .subheadline

    var body: some View {
        let color = Color(hex: colorHex)
        Image(systemName: systemImage)
            .font(font)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.12), in: AppShape.rounded(size))
            .accessibilityHidden(true)
    }
}

// MARK: - Day square

/// One day in a seven-day strip. The same square draws Today's completion
/// grid and the Journal's date picker; only the content differs.
struct DaySquare<Content: View>: View {
    enum Style {
        /// Not logged / not selected: light fill with a hairline edge so it
        /// reads in dark mode too.
        case empty
        /// A win or a selection: solid colour.
        case filled(Color)
        /// The current / selected day before anything happened: outline only.
        case outlined(Color)
    }

    let size: CGFloat
    let style: Style
    @ViewBuilder var content: () -> Content

    init(size: CGFloat, style: Style, @ViewBuilder content: @escaping () -> Content = { EmptyView() }) {
        self.size = size
        self.style = style
        self.content = content
    }

    var body: some View {
        let shape = AppShape.rounded(size)
        ZStack {
            switch style {
            case .empty:
                shape
                    .fill(Color(.systemGray5))
                    .overlay(shape.strokeBorder(Color(.systemGray3), lineWidth: 1))
            case .filled(let color):
                shape.fill(color)
            case .outlined(let color):
                shape.strokeBorder(color, lineWidth: 2)
            }
            content()
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Day mark (bt-0026)

/// What happened on a day, reduced to the five things the palette can say.
/// Palette colours only: a win is green whatever the habit's colour, so a
/// red habit's done day never looks like a slip. The habit's colour stays
/// on its glyph.
enum DayMark: Equatable {
    case empty
    case done
    case partial
    /// A multi-state "Tried" or an avoidance slip.
    case missed
    case rest

    /// An entry's state → a mark. For an avoidance habit anything logged
    /// is a slip (`bt-0024`: only slips get marked).
    init(state: CompletionState?, isAvoidance: Bool) {
        guard let state, state != .notDone else { self = .empty; return }
        if isAvoidance { self = .missed; return }
        switch state {
        case .success: self = .done
        case .partial: self = .partial
        case .failure: self = .missed
        case .rest: self = .rest
        case .notDone: self = .empty
        }
    }

    /// `nil` for an empty day — callers pick their own grey.
    var color: Color? {
        switch self {
        case .empty: return nil
        case .done: return AppTheme.success
        case .partial: return AppTheme.partial
        case .missed: return AppTheme.failed
        case .rest: return AppTheme.rest
        }
    }

    /// The round control's symbol. An avoidance habit's empty state is a
    /// slashed circle, so the tap that means "I slipped" doesn't look like
    /// the tap that means "done".
    func controlSymbol(isAvoidance: Bool) -> String {
        switch self {
        case .empty: return isAvoidance ? "circle.slash" : "circle"
        case .done, .partial: return "checkmark.circle.fill"
        case .missed: return "xmark.circle.fill"
        case .rest: return "moon.circle.fill"
        }
    }

    /// Spoken state for VoiceOver.
    func spokenText(isAvoidance: Bool) -> String {
        switch self {
        case .empty: return isAvoidance ? "Clean so far" : "Not done"
        case .done: return "Done"
        case .partial: return "Partial"
        case .missed: return isAvoidance ? "Slipped" : "Tried"
        case .rest: return "Rest day"
        }
    }
}

/// The one control on a Today row: a round mark like Reminders'. Draws the
/// selected day's state; the caller wraps it in a 44 pt button. The symbol
/// swaps in place and bounces when `changeTick` moves.
struct DayControl: View {
    let mark: DayMark
    let isAvoidance: Bool
    var changeTick: Int = 0

    var body: some View {
        Image(systemName: mark.controlSymbol(isAvoidance: isAvoidance))
            .font(.title2)
            .foregroundStyle(mark.color ?? Color(.systemGray3))
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: changeTick)
    }
}

/// One quiet dot of history. Display only — too small to be a tap target.
struct DayDot: View {
    let mark: DayMark
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(mark.color ?? Color(.systemGray4))
            .frame(width: size, height: size)
    }
}

/// A row of `DayDot`s in fixed-width slots, yesterday first, so the dots
/// line up in straight columns from row to row. Each dot is keyed by its
/// day: when the selected day changes, the day that left the window fades
/// out, the one that entered fades in, and the rest slide a slot — so you
/// see the control's old mark become the first dot (2026-10-30).
struct DayDotStrip: View {
    /// The days shown, yesterday first; `marks` runs in the same order.
    let days: [Date]
    let marks: [DayMark]
    static let slotWidth: CGFloat = 14

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(days, marks)), id: \.0) { _, mark in
                DayDot(mark: mark)
                    .frame(width: Self.slotWidth)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .fixedSize()
        .animation(.snappy, value: days)
        .accessibilityHidden(true) // the row speaks the six days as one value
    }
}

// MARK: - Weekday letters

/// Narrow weekday letters, one per slot, centred over a row of day squares.
struct WeekdayLetterStrip: View {
    let days: [Date]
    let slotWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .sectionLabel()
                    .frame(width: slotWidth)
            }
        }
        .fixedSize()
        .accessibilityHidden(true) // each square already speaks its weekday
    }
}

// MARK: - Section label

extension View {
    /// The grouped-list section-header look: footnote, uppercase, secondary.
    func sectionLabel() -> some View {
        self
            .font(.footnote)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
    }
}
