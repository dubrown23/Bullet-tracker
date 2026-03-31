//
//  AppTheme.swift
//  Bullet Tracker
//
//  Centralized theme and styling for the app
//

import SwiftUI

// MARK: - App Theme

enum AppTheme {

    // MARK: - Accent Colors

    /// Primary accent color - warm orange
    static let accent = Color(hex: "#FF8C42")

    /// Secondary accent - softer orange for backgrounds
    static let accentLight = Color(hex: "#FFB380")

    /// Tertiary accent - very light for subtle backgrounds
    static let accentSubtle = Color(hex: "#FFF3E6")

    // MARK: - Semantic Colors

    /// Success state - warm green
    static let success = Color(hex: "#4CAF50")

    /// Partial/in-progress - warm yellow
    static let partial = Color(hex: "#FFB300")

    /// Failed/negative - soft red
    static let failed = Color(hex: "#EF5350")

    // MARK: - Background Colors

    /// Card background for light mode
    static let cardBackground = Color(UIColor.secondarySystemBackground)

    /// Elevated card background
    static let cardBackgroundElevated = Color(UIColor.tertiarySystemBackground)

    /// Subtle highlight for today/active items
    static let todayHighlight = accent.opacity(0.12)

    // MARK: - Text Colors

    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
    }

    // MARK: - Corner Radius

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let xl: CGFloat = 20
    }

    // MARK: - Shadows

    enum Shadow {
        static let small = ShadowStyle(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        static let medium = ShadowStyle(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        static let large = ShadowStyle(color: .black.opacity(0.12), radius: 12, x: 0, y: 4)
    }

    // MARK: - Typography

    enum Font {
        static let largeTitle = SwiftUI.Font.system(size: 28, weight: .bold)
        static let title = SwiftUI.Font.system(size: 22, weight: .bold)
        static let headline = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 15, weight: .regular)
        static let callout = SwiftUI.Font.system(size: 14, weight: .medium)
        static let caption = SwiftUI.Font.system(size: 12, weight: .regular)
        static let captionBold = SwiftUI.Font.system(size: 12, weight: .semibold)
    }
}

// MARK: - Shadow Style

struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - View Extensions

extension View {
    /// Apply app card styling with subtle shadow
    func appCard(padding: CGFloat = AppTheme.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .shadow(
                color: AppTheme.Shadow.small.color,
                radius: AppTheme.Shadow.small.radius,
                x: AppTheme.Shadow.small.x,
                y: AppTheme.Shadow.small.y
            )
    }

    /// Apply elevated card styling
    func appCardElevated(padding: CGFloat = AppTheme.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(AppTheme.cardBackgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            .shadow(
                color: AppTheme.Shadow.medium.color,
                radius: AppTheme.Shadow.medium.radius,
                x: AppTheme.Shadow.medium.x,
                y: AppTheme.Shadow.medium.y
            )
    }

    /// Apply accent-tinted card for highlighted items
    func appCardAccent(padding: CGFloat = AppTheme.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(AppTheme.todayHighlight)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
    }
}

// Note: Color(hex:) extension is defined in Color+Hex.swift
