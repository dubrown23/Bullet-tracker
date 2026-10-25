//
//  AppTheme.swift
//  Bullet Tracker
//
//  App-wide brand colours plus one contrast helper. Everything else (spacing,
//  radii, shadows, fixed font sizes, card modifiers) was removed in bt-0008 —
//  none of it was used, and system styles / text styles are the right source.
//

import SwiftUI

// MARK: - App Theme

enum AppTheme {

    // Hex strings are kept alongside the Colors so the contrast helper below
    // can read them (SwiftUI `Color` doesn't expose its components portably).

    static let accentHex = "#FF8C42"
    static let successHex = "#4CAF50"
    static let partialHex = "#FFB300"
    static let failedHex = "#EF5350"

    /// Primary accent color - warm orange
    static let accent = Color(hex: accentHex)

    /// Success state - warm green
    static let success = Color(hex: successHex)

    /// Partial/in-progress - warm yellow
    static let partial = Color(hex: partialHex)

    /// Failed/negative - soft red
    static let failed = Color(hex: failedHex)

    // MARK: - Contrast

    /// Black or white, whichever reads better on a surface filled with `hex`.
    /// Uses WCAG relative luminance (bt-0012 contrast audit): pale habit
    /// colours (yellows, pastels) get dark symbols, deep ones get white.
    static func readableForeground(onHex hex: String) -> Color {
        relativeLuminance(ofHex: hex) > 0.3 ? .black : .white
    }

    /// WCAG 2.1 relative luminance of an sRGB hex colour ("#RRGGBB" or "RRGGBB").
    static func relativeLuminance(ofHex hex: String) -> Double {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else { return 0 }

        func linear(_ channel: UInt64) -> Double {
            let c = Double(channel) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let r = linear(value >> 16 & 0xFF)
        let g = linear(value >> 8 & 0xFF)
        let b = linear(value & 0xFF)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

// Note: Color(hex:) extension is defined in Color+Hex.swift
