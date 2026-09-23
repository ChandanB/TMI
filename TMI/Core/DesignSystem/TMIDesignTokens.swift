//
//  TMIDesignTokens.swift
//  TMI
//
//  Design system tokens for the TMI redesign
//

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Color Tokens (Additional)

nonisolated extension Color {

    // MARK: - Helper Initializers

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Spacing & Radius
// Note: TMISpacing, TMIRadius, and TMIAnimation already exist in separate files
// See TMI/Helpers/TMISpacing.swift, TMIRadius.swift, TMIAnimation.swift

// MARK: - Elevation & Shadows

/// One elevation per role. In dark mode shadows all but vanish, so edges come
/// from `TMIColors.separator` hairlines instead (see `tmiSurface`).
enum TMIElevation {
    /// Flush with the canvas; separated by hairlines only.
    case flat
    /// Cards and rows that sit on the canvas.
    case raised
    /// Popovers, menus and hovered cards.
    case elevated
    /// Floating controls and sheets.
    case floating

    var shadowColor: Color {
        Color(light: 0x1C1917, dark: 0x000000)
    }

    var shadowRadius: CGFloat {
        switch self {
        case .flat: 0
        case .raised: 3
        case .elevated: 14
        case .floating: 28
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .flat: 0
        case .raised: 0.05
        case .elevated: 0.09
        case .floating: 0.16
        }
    }

    var shadowOffset: CGSize {
        switch self {
        case .flat: .zero
        case .raised: CGSize(width: 0, height: 1)
        case .elevated: CGSize(width: 0, height: 6)
        case .floating: CGSize(width: 0, height: 12)
        }
    }

    /// Contact shadow under the main one for crisp edges.
    var secondaryShadowRadius: CGFloat {
        switch self {
        case .flat: 0
        case .raised: 1
        case .elevated: 2
        case .floating: 4
        }
    }

    var secondaryShadowOpacity: Double {
        switch self {
        case .flat: 0
        case .raised: 0.04
        case .elevated: 0.05
        case .floating: 0.08
        }
    }
}

// MARK: - Typography (roles beyond the base ramp)

extension Font {
    /// Button labels.
    static let tmiButton = Font.body.weight(.semibold)
    /// Inline navigation titles.
    static let tmiNavTitle = Font.title3.weight(.bold)

    /// New York serif for greetings, people's names and record titles.
    /// Use sparingly: one editorial moment per screen.
    static func tmiEditorial(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif, weight: .semibold)
    }

    /// Key figures in metric tiles. Tabular digits so values don't jitter.
    static let tmiMetric = Font.system(.title, design: .default, weight: .semibold).monospacedDigit()
    /// Hero figures (report headline numbers).
    static let tmiMetricLarge = Font.system(.largeTitle, design: .default, weight: .semibold).monospacedDigit()
    /// Small uppercase labels above titles (apply `.tmiEyebrow()` for tracking).
    static let tmiEyebrow = Font.caption.weight(.semibold)
}

// MARK: - Sizing Constants

enum TMISizing {
    static let iconSm: CGFloat = 16
    static let iconMd: CGFloat = 24
    static let iconLg: CGFloat = 32

    static let avatarSm: CGFloat = 40
    static let avatarMd: CGFloat = 56
    static let avatarLg: CGFloat = 80

#if os(macOS)
    /// Regular-size Mac controls are compact; pointers are precise.
    static let buttonHeight: CGFloat = 32
    static let textFieldHeight: CGFloat = 30
    static let listRowHeight: CGFloat = 44
#else
    static let buttonHeight: CGFloat = 50
    static let textFieldHeight: CGFloat = 50
    static let listRowHeight: CGFloat = 60
#endif
    static let tabBarHeight: CGFloat = 72

    static let fabSize: CGFloat = 56
    static let minTouchTarget: CGFloat = 44
    /// Readable content width for forms and long text on wide windows.
    static let readableWidth: CGFloat = 720
    /// Maximum width for composed dashboards before margins grow instead.
    static let maxContentWidth: CGFloat = 1180
}
