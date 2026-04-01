//
//  Colors.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import SwiftUI

// MARK: - Color Definitions
// Note: These are programmatic definitions. In a real app, you'd define these in the asset catalog.

extension Color {
    // Gentle blue that works well in both light and dark modes
    static let tmiPrimary = Color(red: 0.2901960784, green: 0.5647058824, blue: 0.8862745098)
    static let tmiPrimaryDark = Color(red: 0.2196078431, green: 0.4431372549, blue: 0.7058823529)
    static let tmiSecondary = Color(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529)
    static let tmiBackground = Color(red: 0, green: 0, blue: 0)
    static let tmiText = Color(red: 0.8498495817, green: 0.9484829307, blue: 0.9581733346)
    static let backgroundTop = Color(red: 0.0, green: 0.47, blue: 0.75)
    static let backgroundBottom = Color(red: 0.0, green: 0.35, blue: 0.65)
    static let cardBackground = Color.black.opacity(0.5)
}

#if DEBUG
extension Color {
    static let debugTMIPrimary = Color(red: 0.0653751418, green: 0.004413233139, blue: 0.238399297)
    static let debugTMISecondary = Color(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529)
    static let debugTMIBackground = Color(red: 1, green: 1, blue: 1)
    static let debugTMIText = Color(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006)
}
#endif

extension Color {

    // MARK: - Surface Colors

    /// Primary surface color - background for cards and elevated surfaces
    static var tmiSurface: Color {
        Color(light: Color(hex: "#F9FAFB"), dark: Color(hex: "#000f24"))
    }

    /// Secondary text color
    static var tmiTextSecondary: Color {
        Color(light: Color(hex: "#6B7280"), dark: Color(hex: "#9CA3AF"))
    }

    // MARK: - Semantic Colors

    /// Success color
    static var tmiSuccess: Color {
        Color(light: Color(hex: "#10B981"), dark: Color(hex: "#34D399"))
    }

    /// Warning color
    static var tmiWarning: Color {
        Color(light: Color(hex: "#F59E0B"), dark: Color(hex: "#FBBF24"))
    }

    /// Error color
    static var tmiError: Color {
        Color(light: Color(hex: "#EF4444"), dark: Color(hex: "#F87171"))
    }

    /// Info color
    static var tmiInfo: Color {
        Color(light: Color(hex: "#3B82F6"), dark: Color(hex: "#60A5FA"))
    }
}

extension ShapeStyle where Self == Color {
    static var tmiPrimary: Color { .tmiPrimary }
    static var tmiSecondary: Color { .tmiSecondary }
    static var tmiSurface: Color { .tmiSurface }
    static var tmiBackground: Color { .tmiBackground }
    static var tmiText: Color { .tmiText }
    static var tmiTextSecondary: Color { .tmiTextSecondary }
    static var tmiSuccess: Color { .tmiSuccess }
    static var tmiWarning: Color { .tmiWarning }
    static var tmiError: Color { .tmiError }
    static var tmiInfo: Color { .tmiInfo }
}
