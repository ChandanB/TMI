//
//  TMIDesignTokens.swift
//  TMI
//
//  Design system tokens for the TMI redesign
//

import SwiftUI

// MARK: - Color Tokens (Additional)

extension Color {
    // MARK: - Additional UI Colors

    // Surface variations
    static let tmiSurfaceElevated = Color(light: .white, dark: Color(red: 0.18, green: 0.18, blue: 0.24))

    // Text variations
    static let tmiTextPrimary = Color(light: Color(hex: "#1A1A1A"), dark: Color(hex: "#F9FAFB"))
    static let tmiTextTertiary = Color(light: Color(hex: "#6B7280"), dark: Color(hex: "#D1D5DB"))

    // UI Elements
    static let tmiBorder = Color(light: Color(hex: "#E5E7EB"), dark: Color(hex: "#374151"))
    static let tmiDivider = Color(light: Color(hex: "#F3F4F6"), dark: Color(hex: "#1F2937"))

    // MARK: - Helper Initializers

    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

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

enum TMIElevation {
    case flat
    case raised
    case elevated
    case floating

    var shadowRadius: CGFloat {
        switch self {
        case .flat: return 0
        case .raised: return 2
        case .elevated: return 8
        case .floating: return 16
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .flat: return 0
        case .raised: return 0.08
        case .elevated: return 0.12
        case .floating: return 0.16
        }
    }

    var shadowOffset: CGSize {
        switch self {
        case .flat: return .zero
        case .raised: return CGSize(width: 0, height: 1)
        case .elevated: return CGSize(width: 0, height: 4)
        case .floating: return CGSize(width: 0, height: 8)
        }
    }
}

// MARK: - Typography (Additional)
// Note: Most typography is defined in FontConstants.swift
// These are additional specific use cases for the redesign

extension Font {
    // Additional specialized fonts
    static let tmiButton = Font.system(size: 16, weight: .semibold)
    static let tmiNavTitle = Font.system(size: 20, weight: .bold)
}

// Note: TMIAnimation already exists - see TMI/Helpers/TMIAnimation.swift

// MARK: - Sizing Constants

enum TMISizing {
    static let iconSm: CGFloat = 16
    static let iconMd: CGFloat = 24
    static let iconLg: CGFloat = 32

    static let avatarSm: CGFloat = 40
    static let avatarMd: CGFloat = 56
    static let avatarLg: CGFloat = 80

    static let buttonHeight: CGFloat = 48
    static let textFieldHeight: CGFloat = 48
    static let listRowHeight: CGFloat = 64
    static let tabBarHeight: CGFloat = 72

    static let fabSize: CGFloat = 56
    static let minTouchTarget: CGFloat = 44
}
