//
//  Colors.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

// MARK: - Color Definitions
// Compatibility aliases for existing views. New UI should use TMIColors directly.

extension Color {
    // MARK: - Brand Colors
    static let tmiPrimary = TMIColors.aubergine
    static let tmiPrimaryDeep = TMIColors.aubergine
    static let tmiSecondary = TMIColors.teal
    static let tmiBackground = TMIColors.background

    // MARK: - Text Colors
    static let tmiTextPrimary = TMIColors.textPrimary
    static let tmiTextSecondary = TMIColors.textSecondary
    static let tmiTextTertiary = TMIColors.textSecondary
    static let tmiTextBrand = TMIColors.aubergine
    static let tmiTextOnPrimary = TMIColors.aubergineForeground
    static let tmiTextOnSecondary = TMIColors.tealForeground

    // MARK: - Surface Colors
    static let tmiSurface = TMIColors.surface
    static let tmiSurfaceElevated = TMIColors.surface
    static let tmiSurfaceTinted = TMIColors.aubergineSoft
    static let tmiCardBackground = TMIColors.surface
    static let tmiInputBackground = TMIColors.surface

    // MARK: - Border Colors
    static let tmiBorder = TMIColors.border
    static let tmiBorderStrong = TMIColors.border
    static let tmiDivider = TMIColors.border

    // MARK: - Semantic Colors
    static let tmiSuccess = TMIColors.successText
    static let tmiWarning = TMIColors.warningText
    static let tmiError = TMIColors.errorText
    static let tmiInfo = TMIColors.infoText
}
