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
//  • Seven days   — `DaySquare` + `WeekdayLetterStrip`, shared by the Today
//                   grid and the Journal date strip.
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
