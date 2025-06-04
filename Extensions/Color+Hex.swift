//
//  Color+Hex.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//

import SwiftUI

extension Color {
    // MARK: - Initialization
    
    /// Creates a Color from a hex string
    /// - Parameter hex: A hex color string in format "RGB", "RRGGBB", or "AARRGGBB"
    /// - Note: The # prefix is optional and will be stripped if present
    init(hex: String) {
        // Remove any non-alphanumeric characters (like # prefix)
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        // Parse hex string to integer
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        // Extract color components based on hex string length
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit) - Each character represents 4 bits, expand to 8 bits
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit) - Standard 6-character hex
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit) - Includes alpha channel
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: // Invalid format - return clear color
            (a, r, g, b) = (0, 0, 0, 0)
        }
        
        // Initialize Color with normalized values
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
