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
    static let thin = "Montserrat-Thin"
    static let extraLight = "Montserrat-ExtraLight"
    static let light = "Montserrat-Light"
    static let regular = "Montserrat-Regular"
    static let medium = "Montserrat-Medium"
    static let semiBold = "Montserrat-SemiBold"
    static let bold = "Montserrat-Bold"
    static let extraBold = "Montserrat-ExtraBold"
    static let black = "Montserrat-Black"
    
    static let thinItalic = "Montserrat-ThinItalic"
    static let extraLightItalic = "Montserrat-ExtraLightItalic"
    static let lightItalic = "Montserrat-LightItalic"
    static let italic = "Montserrat-Italic"
    static let mediumItalic = "Montserrat-MediumItalic"
    static let semiBoldItalic = "Montserrat-SemiBoldItalic"
    static let boldItalic = "Montserrat-BoldItalic"
    static let extraBoldItalic = "Montserrat-ExtraBoldItalic"
    static let blackItalic = "Montserrat-BlackItalic"
    
    static let boldIconSize: CGFloat = 24
    
    static let smallFootnoteSize: CGFloat = 12
    static let regularFootnoteSize: CGFloat = 14
    
    static let smallSubheadlineSize: CGFloat = 12
    static let regularSubheadlineSize: CGFloat = 16
    static let boldHeadlineSize: CGFloat = 17
    
    static let regularCaptionSize: CGFloat = 14
    
    static let regularCalloutSize: CGFloat = 14
    
    static let regularBodySize: CGFloat = 16
    
    static let smallTitleSize: CGFloat = 16
    static let regularTitleSize: CGFloat = 18
    static let boldTitleSize: CGFloat = 20
    static let semiBoldTitleSize: CGFloat = 24
    static let boldLargeTitleSize: CGFloat = 34
    static let mediumNavigationTitleSize: CGFloat = 18
    static let mediumTitle3Size: CGFloat = 20
    static let mediumTitle2Size: CGFloat = 22
    static let mediumTitle1Size: CGFloat = 28
    static let mediumLargeTitleSize: CGFloat = 34
}

// MARK: - Text Extensions
extension Text {
    
    func montserrat(style: String, size: CGFloat) -> Text {
        return self.font(.custom(style, size: size))
    }
    
    func extraSmallFootnote() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.smallFootnoteSize)
    }
    
    func smallSubheadline() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.smallSubheadlineSize)
    }
    
    func lightFootnote() -> Text {
        return montserrat(style: FontConstants.light, size: FontConstants.regularFootnoteSize)
    }
    
    func caption() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.regularCaptionSize)
    }
    
    func callout() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.regularCalloutSize)
    }
    
    func footnote() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.regularFootnoteSize)
    }
    
    func subheadline() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.regularSubheadlineSize)
    }
    
    func body() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.regularBodySize)
    }
    
    func smallTitle() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.smallTitleSize)
    }
    
    func title() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.regularTitleSize)
    }
    
    func headline() -> Text {
        return montserrat(style: FontConstants.regular, size: FontConstants.regularSubheadlineSize)
    }
    
    func navigationTitle() -> Text {
        return montserrat(style: FontConstants.medium, size: FontConstants.mediumNavigationTitleSize)
    }
    
    func title1() -> Text {
        return montserrat(style: FontConstants.medium, size: FontConstants.mediumTitle1Size)
    }
    
    func title2() -> Text {
        return montserrat(style: FontConstants.medium, size: FontConstants.mediumTitle2Size)
    }
    
    func title3() -> Text {
        return montserrat(style: FontConstants.medium, size: FontConstants.mediumTitle3Size)
    }
    
    func semiBoldTitle() -> Text {
        return montserrat(style: FontConstants.semiBold, size: FontConstants.semiBoldTitleSize)
    }
        
    func boldSubheadline() -> Text {
        return montserrat(style: FontConstants.bold, size: FontConstants.regularSubheadlineSize)
    }
   
    func boldHeadline() -> Text {
        return montserrat(style: FontConstants.bold, size: FontConstants.boldHeadlineSize)
    }
    
    func boldTitle() -> Text {
        return montserrat(style: FontConstants.bold, size: FontConstants.boldTitleSize)
    }
    
    func boldIcon() -> Text {
        return montserrat(style: FontConstants.bold, size: FontConstants.boldIconSize)
    }
    
    func largeBoldTitle() -> Text {
        return montserrat(style: FontConstants.bold, size: FontConstants.boldLargeTitleSize)
    }
    
    func blackHeadline() -> Text {
        return montserrat(style: FontConstants.black, size: FontConstants.regularSubheadlineSize)
    }
    
    func largeTitle() -> Text {
        return montserrat(style: FontConstants.medium, size: FontConstants.mediumLargeTitleSize)
    }
}

struct NavigationTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom(FontConstants.medium, size: FontConstants.mediumNavigationTitleSize))
            .dynamicTypeSize(.large ... .xxxLarge)
    }
}

extension View {
    func navigationTitleStyle() -> some View {
        self.modifier(NavigationTitleModifier())
    }
}
