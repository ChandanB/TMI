//
//  Colors.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

// MARK: - Color Definitions
// Compatibility aliases for existing views. New UI should use TMIColors directly.

nonisolated extension Color {
    // MARK: - Brand Colors
    /// Amber ink: tint, links, accent text and symbols.
    static let tmiPrimary = TMIColors.accent
    static let tmiPrimaryDeep = TMIColors.accent
    /// Schoolhouse amber fill (pair with `tmiTextOnBrand`).
    static let tmiBrand = TMIColors.brand
    static let tmiSecondary = TMIColors.accent
    static let tmiBackground = TMIColors.background

    // MARK: - Text Colors
    static let tmiTextPrimary = TMIColors.textPrimary
    static let tmiTextSecondary = TMIColors.textSecondary
    static let tmiTextTertiary = TMIColors.textTertiary
    static let tmiTextBrand = TMIColors.accent
    static let tmiTextOnPrimary = TMIColors.onAccent
    static let tmiTextOnSecondary = TMIColors.onAccent
    static let tmiTextOnBrand = TMIColors.onBrand

    // MARK: - Surface Colors
    static let tmiSurface = TMIColors.surface
    static let tmiSurfaceElevated = TMIColors.surfaceRaised
    static let tmiSurfaceSecondary = TMIColors.surfaceSecondary
    static let tmiSurfaceTinted = TMIColors.accentSoft
    static let tmiCardBackground = TMIColors.surface
    static let tmiInputBackground = TMIColors.fill
    static let tmiFill = TMIColors.fill

    // MARK: - Border Colors
    static let tmiBorder = TMIColors.border
    static let tmiBorderStrong = TMIColors.interactiveBorder
    static let tmiDivider = TMIColors.separator

    // MARK: - Semantic Colors
    static let tmiSuccess = TMIColors.successText
    static let tmiWarning = TMIColors.warningText
    static let tmiError = TMIColors.errorText
    static let tmiInfo = TMIColors.infoText
}
