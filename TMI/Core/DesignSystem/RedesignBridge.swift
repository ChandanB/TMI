//
//  RedesignBridge.swift
//  TMI
//
//  Bridges redesigned component names to existing components
//  This allows redesigned views to work with the existing design system
//

import SwiftUI

// MARK: - Font Mappings

extension Font {
    /// Title 1 - Large headlines (28pt bold) - map to Display1
    static var tmiTitle1: Font { .tmiDisplay1 }

    /// Title 2 - Medium headlines (22pt semibold) - map to Heading1
    static var tmiTitle2: Font { .tmiHeading1 }

    /// Title 3 - Small headlines (18pt semibold) - map to Heading3
    static var tmiTitle3: Font { .tmiHeading3 }

    /// Footnote text (use caption small)
    static var tmiFootnote: Font { .tmiCaptionSmall }
}

// MARK: - Color Mappings (aliases to existing colors)

// Note: Most colors already exist in Color+Extensions.swift
// We're just adding convenience properties if they don't exist yet

// MARK: - Spacing Extensions

extension TMISpacing {
    /// Card padding (maps to md)
    static var cardPadding: CGFloat { md }

    /// Section spacing (maps to lg)
    static var sectionSpacing: CGFloat { lg }

    /// Screen padding (maps to md)
    static var screenPadding: CGFloat { md }

    /// Convenience aliases
    static var small: CGFloat { sm }
    static var medium: CGFloat { md }
    static var large: CGFloat { lg }
    static var extraLarge: CGFloat { xl }
}

// MARK: - Radius Extensions

extension TMIRadius {
    /// Card radius
    static var card: CGFloat { md }

    /// Button radius
    static var button: CGFloat { sm }

    /// Modal radius
    static var modal: CGFloat { lg }

    /// Sheet radius
    static var sheet: CGFloat { xl }

    /// Pill radius (fully rounded)
    static var pill: CGFloat { full }

    /// Convenience aliases
    static var small: CGFloat { sm }
    static var medium: CGFloat { md }
}

// MARK: - Animation Extensions

extension TMIAnimation {
    /// Interactive spring animation
    static var springInteractive: Animation {
        Animation.spring(response: 0.35, dampingFraction: 0.75)
    }

    /// Standard ease in/out
    static var easeInOutStandard: Animation {
        Animation.easeInOut(duration: 0.25)
    }

    /// Quick ease in/out
    static var easeInOutQuick: Animation {
        Animation.easeInOut(duration: 0.15)
    }
}

// Note: TMISizing and TMIElevation are defined in TMIDesignTokens.swift already

// MARK: - Component Notes
// TMIEmptyState and TMISearchBar components are now unified
// All views should use TMIEmptyState and TMISearchBar (no "Redesigned" suffix)

// MARK: - View Extension for Card Modifier

extension View {
    /// Apply TMI card styling using existing components
    func tmiCard(style: TMICardStyle = .elevated, padding: CGFloat = TMISpacing.cardPadding) -> some View {
        self
            .padding(padding)
            .background(Color.tmiSurface)
            .cornerRadius(TMIRadius.card)
            .shadow(
                color: .black.opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                x: 0,
                y: style.shadowOffset
            )
    }
}

enum TMICardStyle {
    case `default`
    case elevated
    case outlined

    var shadowRadius: CGFloat {
        switch self {
        case .default: return 2
        case .elevated: return 8
        case .outlined: return 0
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .default: return 0.08
        case .elevated: return 0.12
        case .outlined: return 0
        }
    }

    var shadowOffset: CGFloat {
        switch self {
        case .default: return 1
        case .elevated: return 4
        case .outlined: return 0
        }
    }
}
