//
//  Constants.swift
//  The-Stomping-Ground
//
//  Created by Chandan Brown on 3/8/23.
//

import SwiftUI

struct RegisterAccountConstants {
    static let aboutMeLimit = 140
    static let passwordLength = 6
}

struct FontConstants {
    enum FontName: String {
        // Standard fonts
        case thin = "Montserrat-Thin"
        case extraLight = "Montserrat-ExtraLight"
        case light = "Montserrat-Light"
        case regular = "Montserrat-Regular"
        case medium = "Montserrat-Medium"
        case semiBold = "Montserrat-SemiBold"
        case bold = "Montserrat-Bold"
        case extraBold = "Montserrat-ExtraBold"
        case black = "Montserrat-Black"
        
        // Italic versions
        case thinItalic = "Montserrat-ThinItalic"
        case extraLightItalic = "Montserrat-ExtraLightItalic"
        case lightItalic = "Montserrat-LightItalic"
        case italic = "Montserrat-Italic"
        case mediumItalic = "Montserrat-MediumItalic"
        case semiBoldItalic = "Montserrat-SemiBoldItalic"
        case boldItalic = "Montserrat-BoldItalic"
        case extraBoldItalic = "Montserrat-ExtraBoldItalic"
        case blackItalic = "Montserrat-BlackItalic"
    }
    
    enum Size: CGFloat {
        // Base sizes
        case tiny = 10
        case small = 12
        case regular = 14
        case medium = 16
        case large = 18
        case xLarge = 20
        case xxLarge = 24
        case xxxLarge = 28
    }
    
    // Base sizes
    static let tinySize: CGFloat    = Size.tiny.rawValue
    static let smallSize: CGFloat   = Size.small.rawValue
    static let regularSize: CGFloat = Size.regular.rawValue
    static let mediumSize: CGFloat  = Size.medium.rawValue
    static let largeSize: CGFloat   = Size.large.rawValue
    static let xLargeSize: CGFloat  = Size.xLarge.rawValue
    static let xxLargeSize: CGFloat = Size.xxLarge.rawValue
    static let xxxLargeSize: CGFloat = Size.xxxLarge.rawValue
    
    // Icon sizes
    static let smallIconSize: CGFloat   = 16
    static let regularIconSize: CGFloat = 20
    static let largeIconSize: CGFloat   = 24
    static let boldIconSize: CGFloat    = largeIconSize
    
    // Text style base sizes
    static let footnoteSize: CGFloat      = smallSize
    static let captionSize: CGFloat       = regularSize
    static let subheadlineSize: CGFloat   = regularSize
    static let bodySize: CGFloat          = regularSize
    static let calloutSize: CGFloat       = mediumSize
    static let headlineSize: CGFloat      = mediumSize
    static let titleSize: CGFloat         = largeSize
    static let largeTitleSize: CGFloat    = xxLargeSize
    
    // Derived sizes
    static let extraSmallFootnoteSize: CGFloat = footnoteSize - 4
    static let smallFootnoteSize: CGFloat      = footnoteSize - 2
    static let regularFootnoteSize: CGFloat    = footnoteSize
    
    static let smallSubheadlineSize: CGFloat   = subheadlineSize - 2
    static let regularSubheadlineSize: CGFloat = subheadlineSize
    static let boldHeadlineSize: CGFloat       = subheadlineSize + 2
    
    static let tinyCaptionSize: CGFloat    = captionSize - 4
    static let smallCaptionSize: CGFloat   = captionSize - 2
    static let regularCaptionSize: CGFloat = captionSize
    
    static let regularCalloutSize: CGFloat = calloutSize
    
    static let regularBodySize: CGFloat    = bodySize
    static let regularUsernameSize: CGFloat = bodySize
    static let smallUsernameSize: CGFloat   = bodySize - 2
    
    static let smallTitleSize: CGFloat     = titleSize - 2
    static let regularTitleSize: CGFloat   = titleSize
    static let boldTitleSize: CGFloat      = titleSize + 2
    static let semiBoldTitleSize: CGFloat  = largeTitleSize - 2
    static let boldLargeTitleSize: CGFloat = largeTitleSize + 2
    
    // Navigation and special cases
    static let navigationTitleSize: CGFloat = xLargeSize
    static let tabBarItemSize: CGFloat      = tinySize
    static let buttonSize: CGFloat          = mediumSize
    
    // Title hierarchy
    static let title3Size: CGFloat = largeSize
    static let title2Size: CGFloat = xLargeSize
    static let title1Size: CGFloat = xxLargeSize
    
    static let mediumNavigationTitleSize: CGFloat = title2Size
    static let mediumTitle3Size: CGFloat          = title3Size
    static let mediumTitle2Size: CGFloat          = title2Size
    static let mediumTitle1Size: CGFloat          = title1Size
    static let mediumLargeTitleSize: CGFloat      = xxxLargeSize
    
    // Text styles - define combinations of font and size
    enum TextStyle {
        case extraSmallFootnote
        case smallSubheadline
        case lightFootnote
        case lightCaption
        case lightCaption2
        case caption
        case caption2
        case caption3
        case semiBoldCaption
        case callout
        case footnote
        case footnote2
        case headline
        case subheadline
        case smallBody
        case body
        case smallTitle
        case title
        case username
        case handle
        case navigationTitle
        case title1
        case title2
        case title3
        case semiBoldTitle
        case boldSubheadline
        case boldSubheadline2
        case boldHeadline
        case boldTitle
        case boldIcon
        case largeBoldTitle
        case blackHeadline
        case largeTitle
        
        var fontName: FontName {
            switch self {
            case .lightFootnote, .lightCaption, .lightCaption2:
                return .light
            case .semiBoldCaption, .username, .semiBoldTitle:
                return .semiBold
            case .boldSubheadline, .boldSubheadline2, .boldHeadline, .boldTitle, .boldIcon, .largeBoldTitle:
                return .bold
            case .blackHeadline:
                return .black
            case .navigationTitle, .title1, .title2, .title3, .largeTitle:
                return .medium
            default:
                return .regular
            }
        }
        
        var size: CGFloat {
            switch self {
            case .extraSmallFootnote:
                return FontConstants.extraSmallFootnoteSize
            case .smallSubheadline:
                return FontConstants.smallSubheadlineSize
            case .lightFootnote, .footnote:
                return FontConstants.regularFootnoteSize
            case .lightCaption, .caption, .semiBoldCaption:
                return FontConstants.regularCaptionSize
            case .lightCaption2, .caption2:
                return FontConstants.smallCaptionSize
            case .caption3:
                return FontConstants.tinyCaptionSize
            case .callout:
                return FontConstants.calloutSize
            case .footnote2:
                return FontConstants.smallFootnoteSize
            case .headline, .blackHeadline:
                return FontConstants.headlineSize
            case .subheadline, .boldSubheadline:
                return FontConstants.subheadlineSize
            case .boldSubheadline2:
                return FontConstants.subheadlineSize - 2
            case .smallBody:
                return FontConstants.footnoteSize
            case .body:
                return FontConstants.bodySize
            case .smallTitle:
                return FontConstants.smallTitleSize
            case .title:
                return FontConstants.titleSize
            case .username:
                return FontConstants.regularUsernameSize
            case .handle:
                return FontConstants.smallUsernameSize
            case .navigationTitle:
                return FontConstants.navigationTitleSize
            case .title1:
                return FontConstants.title1Size
            case .title2:
                return FontConstants.title2Size
            case .title3:
                return FontConstants.title3Size
            case .semiBoldTitle:
                return FontConstants.semiBoldTitleSize
            case .boldHeadline:
                return FontConstants.boldHeadlineSize
            case .boldTitle:
                return FontConstants.boldTitleSize
            case .boldIcon:
                return FontConstants.boldIconSize
            case .largeBoldTitle:
                return FontConstants.boldLargeTitleSize
            case .largeTitle:
                return FontConstants.largeTitleSize
            }
        }
    }
}

extension FontConstants {
    /// Creates a UIFont with the specified Montserrat font style and size
    static func uiFont(_ fontName: FontName, size: CGFloat) -> UIFont? {
        return UIFont(name: fontName.rawValue, size: size)
    }
}

// MARK: - View Extensions - Typography

extension View {
    /// Apply a Montserrat font with the specified style and size
    /// - Parameters:
    ///   - fontName: The Montserrat font variant to use
    ///   - size: The font size
    /// - Returns: A view with the specified font applied
    func montserratFont(_ fontName: FontConstants.FontName, size: CGFloat) -> some View {
        self.font(.custom(fontName.rawValue, size: size))
    }
    
    /// Apply a predefined text style using Montserrat font
    /// - Parameter style: The text style to apply
    /// - Returns: A view with the specified text style applied
    func montserratFont(_ style: FontConstants.TextStyle) -> some View {
        montserratFont(style.fontName, size: style.size)
    }
    
    // Legacy support methods that use the new unified approach
    
    /// Apply extra small footnote style
    func extraSmallFootnote() -> some View {
        montserratFont(.extraSmallFootnote)
    }
    
    /// Apply small subheadline style
    func smallSubheadline() -> some View {
        montserratFont(.smallSubheadline)
    }
    
    /// Apply light footnote style
    func lightFootnote() -> some View {
        montserratFont(.lightFootnote)
    }

    /// Apply light caption style
    func lightCaption() -> some View {
        montserratFont(.lightCaption)
    }
    
    /// Apply light caption 2 style
    func lightCaption2() -> some View {
        montserratFont(.lightCaption2)
    }
    
    /// Apply caption style
    func caption() -> some View {
        montserratFont(.caption)
    }
    
    /// Apply caption 2 style
    func caption2() -> some View {
        montserratFont(.caption2)
    }
    
    /// Apply caption 3 style
    func caption3() -> some View {
        montserratFont(.caption3)
    }
    
    /// Apply semi-bold caption style
    func semiBoldCaption() -> some View {
        montserratFont(.semiBoldCaption)
    }
    
    /// Apply callout style
    func callout() -> some View {
        montserratFont(.callout)
    }
    
    /// Apply footnote style
    func footnote() -> some View {
        montserratFont(.footnote)
    }
    
    /// Apply footnote 2 style
    func footnote2() -> some View {
        montserratFont(.footnote2)
    }
    
    /// Apply headline style
    func headline() -> some View {
        montserratFont(.headline)
    }
    
    /// Apply subheadline style
    func subheadline() -> some View {
        montserratFont(.subheadline)
    }
    
    /// Apply small body style
    func smallBody() -> some View {
        montserratFont(.smallBody)
    }
    
    /// Apply body style
    func body() -> some View {
        montserratFont(.body)
    }
    
    /// Apply small title style
    func smallTitle() -> some View {
        montserratFont(.smallTitle)
    }
    
    /// Apply title style
    func title() -> some View {
        montserratFont(.title)
    }
    
    /// Apply username style
    func username() -> some View {
        montserratFont(.username)
    }
    
    /// Apply handle style
    func handle() -> some View {
        montserratFont(.handle)
    }
    
    /// Apply navigation title style
    func navigationTitle() -> some View {
        montserratFont(.navigationTitle)
    }
    
    /// Apply title 1 style
    func title1() -> some View {
        montserratFont(.title1)
    }
    
    /// Apply title 2 style
    func title2() -> some View {
        montserratFont(.title2)
    }
    
    /// Apply title 3 style
    func title3() -> some View {
        montserratFont(.title3)
    }
    
    /// Apply semi-bold title style
    func semiBoldTitle() -> some View {
        montserratFont(.semiBoldTitle)
    }
    
    /// Apply bold subheadline style
    func boldSubheadline() -> some View {
        montserratFont(.boldSubheadline)
    }
    
    /// Apply bold subheadline 2 style
    func boldSubheadline2() -> some View {
        montserratFont(.boldSubheadline2)
    }
   
    /// Apply bold headline style
    func boldHeadline() -> some View {
        montserratFont(.boldHeadline)
    }
    
    /// Apply bold title style
    func boldTitle() -> some View {
        montserratFont(.boldTitle)
    }
    
    /// Apply bold icon style
    func boldIcon() -> some View {
        montserratFont(.boldIcon)
    }
    
    /// Apply large bold title style
    func largeBoldTitle() -> some View {
        montserratFont(.largeBoldTitle)
    }
    
    /// Apply black headline style
    func blackHeadline() -> some View {
        montserratFont(.blackHeadline)
    }
    
    /// Apply large title style
    func largeTitle() -> some View {
        montserratFont(.largeTitle)
    }
}


nonisolated extension Font {
    // MARK: - Display Fonts (Large Headings)
    
    /// Display 1 - Largest display font (34pt, bold)
    static var tmiDisplay1: Font {
        return .system(size: 34, weight: .bold, design: .default)
    }
    
    /// Display 2 - Second largest display font (28pt, bold)
    static var tmiDisplay2: Font {
        return .system(size: 28, weight: .bold, design: .default)
    }
    
    /// Display 3 - Third largest display font (24pt, bold)
    static var tmiDisplay3: Font {
        return .system(size: 24, weight: .bold, design: .default)
    }
    
    // MARK: - Heading Fonts
    
    /// Heading 1 - Largest heading (22pt, bold)
    static var tmiHeading1: Font {
        return .system(size: 22, weight: .bold, design: .default)
    }
    
    /// Heading 2 - Second largest heading (20pt, semibold)
    static var tmiHeading2: Font {
        return .system(size: 20, weight: .semibold, design: .default)
    }
    
    /// Heading 3 - Third largest heading (18pt, semibold)
    static var tmiHeading3: Font {
        return .system(size: 18, weight: .semibold, design: .default)
    }
    
    // MARK: - Body Fonts
    
    /// Body Large - Larger body text (17pt, regular)
    static var tmiBodyLarge: Font {
        return .system(size: 17, weight: .regular, design: .default)
    }
    
    /// Body - Standard body text (16pt, regular)
    static var tmiBody: Font {
        return .system(size: 16, weight: .regular, design: .default)
    }
    
    /// Body Small - Smaller body text (14pt, regular)
    static var tmiBodySmall: Font {
        return .system(size: 14, weight: .regular, design: .default)
    }
    
    // MARK: - Label Fonts
    
    /// Label Large - Larger label text (16pt, medium)
    static var tmiLabelLarge: Font {
        return .system(size: 16, weight: .medium, design: .default)
    }
    
    /// Label Medium - Standard label text (14pt, medium)
    static var tmiLabelMedium: Font {
        return .system(size: 14, weight: .medium, design: .default)
    }
    
    /// Label Small - Smaller label text (12pt, medium)
    static var tmiLabelSmall: Font {
        return .system(size: 12, weight: .medium, design: .default)
    }
    
    // MARK: - Caption Fonts
    
    /// Caption - Small caption text (12pt, regular)
    static var tmiCaption: Font {
        return .system(size: 12, weight: .regular, design: .default)
    }
    
    /// Caption Small - Smallest caption text (10pt, regular)
    static var tmiCaptionSmall: Font {
        return .system(size: 10, weight: .regular, design: .default)
    }
    
    // MARK: - Monospaced Fonts
    
    /// Code - Monospaced font for code display (14pt, regular)
    static var tmiCode: Font {
        return .system(size: 14, weight: .regular, design: .monospaced)
    }
    
    /// Code Small - Smaller monospaced font (12pt, regular)
    static var tmiCodeSmall: Font {
        return .system(size: 12, weight: .regular, design: .monospaced)
    }
}
