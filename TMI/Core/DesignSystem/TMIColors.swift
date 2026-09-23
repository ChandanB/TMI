//
//  TMIColors.swift
//  TMI
//
//  Golden Hour color system. Every token adapts to light and dark appearance
//  (and to Increase Contrast where it matters), so screens never branch on
//  color scheme themselves. See docs/superpowers/specs/2026-09-23-golden-hour-redesign-design.md.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

nonisolated enum TMIColors {
    // MARK: - Canvas and surfaces

    /// The page behind everything: warm stone in light, the icon's charcoal in dark.
    static let background = Color(light: 0xF6F5F2, dark: 0x11100F)
    /// Cards, grouped rows, table bodies.
    static let surface = Color(light: 0xFFFFFF, dark: 0x1A1917)
    /// Inset areas: inspectors, table headers, secondary panes.
    static let surfaceSecondary = Color(light: 0xFAF9F6, dark: 0x201E1C)
    /// Sheets, popovers and anything floating above a surface.
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x252321)
    /// Control fills: search fields, segmented tracks, quiet buttons.
    static let fill = Color(light: 0xEFEDE8, dark: 0x2A2826)
    /// Hovered or pressed control fills.
    static let fillStrong = Color(light: 0xE6E3DD, dark: 0x34312E)

    // MARK: - Text

    static let textPrimary = Color(light: 0x1C1917, dark: 0xF5F2EE)
    static let textSecondary = Color(light: 0x5C5650, dark: 0xADA69F, lightHighContrast: 0x3F3A35, darkHighContrast: 0xD4CEC8)
    /// Metadata and placeholders. Still meets 4.5:1 on `surface` in both appearances.
    static let textTertiary = Color(light: 0x78716B, dark: 0x8A837C, lightHighContrast: 0x57514B, darkHighContrast: 0xB3ACA5)

    // MARK: - Lines

    /// Hairline between rows and around cards.
    static let separator = Color(light: 0x292524, dark: 0xFFF6E6, lightAlpha: 0.10, darkAlpha: 0.09, highContrastAlpha: 0.28)
    /// Card and container outlines that must read as an edge.
    static let border = Color(light: 0x292524, dark: 0xFFF6E6, lightAlpha: 0.16, darkAlpha: 0.15, highContrastAlpha: 0.40)
    /// Input and control outlines. Meets 3:1 against the canvas (WCAG 1.4.11).
    static let interactiveBorder = Color(light: 0x8F8881, dark: 0x6F6862)

    // MARK: - Brand

    /// The schoolhouse amber. A fill color only; never use it for text on light surfaces.
    static let brand = Color(light: 0xF5A524, dark: 0xF5AE35)
    /// Text and symbols placed on `brand`.
    static let onBrand = Color(light: 0x1C1917, dark: 0x1C1917)
    /// "Amber ink": tint, links and accent text. AA on every surface.
    static let accent = Color(light: 0xA35F00, dark: 0xF7B84A, lightHighContrast: 0x7F4A00, darkHighContrast: 0xFFCB6B)
    /// Text on an `accent` fill.
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x1C1917)
    /// Soft amber wash: selected chips, icon tiles, highlights.
    static let accentSoft = Color(light: 0xFCEFD8, dark: 0xF5AA32, lightAlpha: 1, darkAlpha: 0.15)
    /// Selected rows in lists and tables.
    static let selection = Color(light: 0xFBEFD9, dark: 0xF5AA32, lightAlpha: 1, darkAlpha: 0.13)

    // MARK: - Status (text + surface pairs; each text color is AA on its surface)

    static let successText = Color(light: 0x11703A, dark: 0x4ADE80)
    static let successSurface = Color(light: 0xE3F4E8, dark: 0x4ADE80, lightAlpha: 1, darkAlpha: 0.13)
    /// Attention is orange, deliberately distinct from the brand amber.
    static let warningText = Color(light: 0xB93C0B, dark: 0xFB923C)
    static let warningSurface = Color(light: 0xFDEBDF, dark: 0xFB923C, lightAlpha: 1, darkAlpha: 0.14)
    static let errorText = Color(light: 0xB42318, dark: 0xF87171)
    static let errorSurface = Color(light: 0xFDE7E4, dark: 0xF87171, lightAlpha: 1, darkAlpha: 0.14)
    static let infoText = Color(light: 0x1D4ED8, dark: 0x7AA2FF)
    static let infoSurface = Color(light: 0xE6EDFD, dark: 0x7AA2FF, lightAlpha: 1, darkAlpha: 0.14)

    // MARK: - Data visualization

    /// Primary series. Meets 3:1 against `surface` for marks.
    static let chartPrimary = Color(light: 0xC77C07, dark: 0xF5AE35)
    /// Tracks, gridlines and de-emphasized bars.
    static let chartTrack = Color(light: 0xE6E2DA, dark: 0x34312E)
    /// Categorical series in order. Use `chartSeries[index % count]`.
    static let chartSeries: [Color] = [
        chartPrimary,
        Color(light: 0x0F766E, dark: 0x2DD4BF),
        Color(light: 0x4F46E5, dark: 0x818CF8),
        Color(light: 0xBE185D, dark: 0xF472B6),
        Color(light: 0x4D7C0F, dark: 0xA3E635),
        Color(light: 0x475569, dark: 0x94A3B8),
    ]

    // MARK: - Golden Hour gradient stops (brand moments only)

    static let goldenHourStops: [Color] = [
        Color(light: 0xFFD48A, dark: 0x6B4712),
        Color(light: 0xFFE3B0, dark: 0x4A3217),
        Color(light: 0xFFB8A3, dark: 0x5E2E28),
        Color(light: 0xFFE7BD, dark: 0x3A2A16),
        Color(light: 0xFFF4E4, dark: 0x1F1A15),
        Color(light: 0xFBD3D6, dark: 0x3E2231),
        Color(light: 0xFFF1DA, dark: 0x2A2118),
        Color(light: 0xFDE6E0, dark: 0x2E1F24),
        Color(light: 0xF7C9DE, dark: 0x4A2346),
    ]
    static let goldenHourText = Color(light: 0x1C1917, dark: 0xFFF7EA)
    static let goldenHourSecondaryText = Color(light: 0x6A5438, dark: 0xE6D2B6)
}

// MARK: - Adaptive color construction

nonisolated extension Color {
    /// An appearance-adaptive color from 24-bit RGB hex literals.
    ///
    /// High-contrast variants apply when the user turns on Increase Contrast.
    /// Alpha lets hairlines and washes stay translucent over any surface.
    init(
        light: UInt32,
        dark: UInt32,
        lightHighContrast: UInt32? = nil,
        darkHighContrast: UInt32? = nil,
        lightAlpha: Double = 1,
        darkAlpha: Double = 1,
        highContrastAlpha: Double? = nil
    ) {
        let lightRGBA = TMIRGBA(hex: light, alpha: lightAlpha)
        let darkRGBA = TMIRGBA(hex: dark, alpha: darkAlpha)
        let lightHC = TMIRGBA(hex: lightHighContrast ?? light, alpha: highContrastAlpha ?? lightAlpha)
        let darkHC = TMIRGBA(hex: darkHighContrast ?? dark, alpha: highContrastAlpha ?? darkAlpha)
#if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let isHighContrast = traits.accessibilityContrast == .high
            switch (isDark, isHighContrast) {
            case (false, false): return lightRGBA.uiColor
            case (true, false): return darkRGBA.uiColor
            case (false, true): return lightHC.uiColor
            case (true, true): return darkHC.uiColor
            }
        })
#elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [
                .aqua, .darkAqua,
                .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
            ])
            switch match {
            case .darkAqua: return darkRGBA.nsColor
            case .accessibilityHighContrastAqua: return lightHC.nsColor
            case .accessibilityHighContrastDarkAqua: return darkHC.nsColor
            default: return lightRGBA.nsColor
            }
        })
#endif
    }
}

/// A Sendable color value captured by dynamic providers.
nonisolated struct TMIRGBA: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(hex: UInt32, alpha: Double = 1) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }

#if canImport(UIKit)
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
#elseif canImport(AppKit)
    var nsColor: NSColor { NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }
#endif
}
