//
//  TMIColors.swift
//  TMI
//
//  Canonical light-mode color system.
//

import SwiftUI

enum TMIColors {
    // MARK: - Foundation

    static let background = Color(hex: "#F7F6FA")
    static let surface = Color(hex: "#FFFFFF")
    static let textPrimary = Color(hex: "#1F1A24")
    static let textSecondary = Color(hex: "#514A57")
    static let border = Color(hex: "#C7C0CF")

    // MARK: - Brand and action

    static let aubergine = Color(hex: "#5B2A5B")
    static let aubergineForeground = Color(hex: "#FFFFFF")
    static let teal = Color(hex: "#0F766E")
    static let tealForeground = Color(hex: "#FFFFFF")
    static let aubergineSoft = Color(hex: "#EDE1ED")

    // MARK: - Status

    static let successSurface = Color(hex: "#DFF3E7")
    static let successText = Color(hex: "#14532D")
    static let warningSurface = Color(hex: "#F4E8C8")
    static let warningText = Color(hex: "#6B4306")
    static let errorSurface = Color(hex: "#FCE8E6")
    static let errorText = Color(hex: "#8F2118")
    static let infoSurface = Color(hex: "#DFF1EF")
    static let infoText = Color(hex: "#0D5B55")
}
