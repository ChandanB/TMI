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
    // MARK: - Brand Colors
    static let tmiPrimary = Color(hex: "#D4930D")         // Gold
    static let tmiPrimaryDeep = Color(hex: "#B87A0A")     // Deep gold
    static let tmiSecondary = Color(hex: "#3B6FA0")       // Warm blue
    static let tmiBackground = Color(hex: "#FDF8F3")      // Warm cream

    // MARK: - Text Colors
    static let tmiTextPrimary = Color(hex: "#2D3436")
    static let tmiTextSecondary = Color(hex: "#636E72")
    static let tmiTextTertiary = Color(hex: "#94908B")
    static let tmiTextBrand = Color(hex: "#D4930D")
    static let tmiTextOnPrimary = Color(hex: "#FFFFFF")
    static let tmiTextOnSecondary = Color(hex: "#FFFFFF")

    // MARK: - Surface Colors
    static let tmiSurface = Color(hex: "#FFFFFF")
    static let tmiSurfaceElevated = Color(hex: "#FFFFFF")
    static let tmiSurfaceTinted = Color(hex: "#F8F3ED")    // Warm tint for section headers
    static let tmiCardBackground = Color(hex: "#FFFFFF")
    static let tmiInputBackground = Color(hex: "#F5F0EB")

    // MARK: - Border Colors
    static let tmiBorder = Color(hex: "#E8E2DA")
    static let tmiBorderStrong = Color(hex: "#D9D2C9")    // Warmer, more visible card border
    static let tmiDivider = Color(hex: "#F0EBE4")

    // MARK: - Semantic Colors
    static let tmiSuccess = Color(hex: "#2D9F6F")
    static let tmiWarning = Color(hex: "#E8A817")
    static let tmiError = Color(hex: "#DC3545")
    static let tmiInfo = Color(hex: "#3B6FA0")
}

