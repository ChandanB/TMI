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
    /// 12pt: row insets, tight stacks.
    static let ms: CGFloat = 12
    /// 20pt: card padding on iPhone, comfortable stacks.
    static let ml: CGFloat = 20

    /// Card padding.
    static var cardPadding: CGFloat { md }

    /// Space between sections of a screen.
    static var sectionSpacing: CGFloat { lg }

    /// Horizontal screen margin.
    static var screenPadding: CGFloat {
#if os(macOS)
        lg
#else
        md
#endif
    }

    /// Convenience aliases
    static var small: CGFloat { sm }
    static var medium: CGFloat { md }
    static var large: CGFloat { lg }
    static var extraLarge: CGFloat { xl }
}

// MARK: - Radius Extensions
//
// Always draw with `style: .continuous` (see `TMIShape`). iPhone uses softer,
// larger radii that echo the device corners; the Mac is tighter and crisper.

extension TMIRadius {
#if os(macOS)
    /// Cards, grouped containers, tables.
    static let card: CGFloat = 12
    /// Buttons, fields, segmented controls.
    static let control: CGFloat = 8
    /// Chips, badges, icon tiles.
    static let chip: CGFloat = 6
    /// Icon tiles in rows.
    static let tile: CGFloat = 7
#else
    static let card: CGFloat = 20
    static let control: CGFloat = 14
    static let chip: CGFloat = 8
    static let tile: CGFloat = 9
#endif

    /// Button radius
    static var button: CGFloat { control }

    /// Modal radius
    static var modal: CGFloat { card }

    /// Sheet radius
    static var sheet: CGFloat { card }

    /// Pill radius (fully rounded)
    static var pill: CGFloat { full }

    /// Convenience aliases
    static var small: CGFloat { sm }
    static var medium: CGFloat { md }
}

/// Continuous rounded shapes for the standard radii.
enum TMIShape {
    static var card: RoundedRectangle { RoundedRectangle(cornerRadius: TMIRadius.card, style: .continuous) }
    static var control: RoundedRectangle { RoundedRectangle(cornerRadius: TMIRadius.control, style: .continuous) }
    static var chip: RoundedRectangle { RoundedRectangle(cornerRadius: TMIRadius.chip, style: .continuous) }
    static var tile: RoundedRectangle { RoundedRectangle(cornerRadius: TMIRadius.tile, style: .continuous) }
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

    /// Default motion for state changes (0.35s, no bounce).
    static var smooth: Animation { .smooth(duration: 0.35) }

    /// Playful-but-controlled motion for celebrations and Student Mode.
    static var bouncy: Animation { .bouncy(duration: 0.45, extraBounce: 0.05) }

    /// Tight response for presses and toggles.
    static var snappy: Animation { .snappy(duration: 0.22) }
}

// Note: TMISizing and TMIElevation are defined in TMIDesignTokens.swift already

// MARK: - Component Notes
// TMIEmptyState and TMISearchBar components are now unified
// All views should use TMIEmptyState and TMISearchBar (no "Redesigned" suffix)

// Note: TMICardStyle and tmiCard(style:) are now defined in TMIComponentLibrary.swift
