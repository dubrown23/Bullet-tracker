//
//  AppTheme.swift
//  Bullet Tracker
//
//  App-wide brand colours. Everything else (spacing, radii, shadows, fixed
//  font sizes, card modifiers) was removed in bt-0008 — none of it was used,
//  and system styles / text styles are the right source for those now.
//

import SwiftUI

// MARK: - App Theme

enum AppTheme {

    /// Primary accent color - warm orange
    static let accent = Color(hex: "#FF8C42")

    /// Success state - warm green
    static let success = Color(hex: "#4CAF50")

    /// Partial/in-progress - warm yellow
    static let partial = Color(hex: "#FFB300")

    /// Failed/negative - soft red
    static let failed = Color(hex: "#EF5350")
}

// Note: Color(hex:) extension is defined in Color+Hex.swift
