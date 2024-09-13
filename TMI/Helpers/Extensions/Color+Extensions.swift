//
//  Colors.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import Foundation
import SwiftUI

// MARK: - Color Definitions
// Note: These are programmatic definitions. In a real app, you'd define these in the asset catalog.

/*
TMIPrimary:
  Light: #3857DF (RGB: 56, 87, 223)
  Dark:  #5D7CE0 (RGB: 93, 124, 224)

TMISecondary:
  Light: #3DA5D9 (RGB: 61, 165, 217)
  Dark:  #2D7FB0 (RGB: 45, 127, 176)

TMIBackground:
  Light: #F9E9AB (RGB: 249, 233, 171)
  Dark:  #1A4766 (RGB: 26, 71, 102)

TMIText:
  Light: #1A4766 (RGB: 26, 71, 102)
  Dark:  #F9E9AB (RGB: 249, 233, 171)
*/

extension Color {
    static let tmiPrimary = Color(light: #colorLiteral(red: 0.0653751418, green: 0.004413233139, blue: 0.238399297, alpha: 1), dark: #colorLiteral(red: 0.3312325776, green: 0.3195435107, blue: 0.9338886142, alpha: 1))
    static let tmiSecondary = Color(light: #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1), dark: #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1))
    static let tmiBackground = Color(light: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1), dark: #colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1))
    static let tmiText = Color(light: #colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1), dark: #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1))
    static let backgroundTop = Color(red: 0.0, green: 0.47, blue: 0.75)
    static let backgroundBottom = Color(red: 0.0, green: 0.35, blue: 0.65)
    static let cardBackground = Color.black.opacity(0.5)
}

#if DEBUG
extension Color {
    static let debugTMIPrimary = Color(light: #colorLiteral(red: 0.2196078449, green: 0.007843137719, blue: 0.8549019694, alpha: 1), dark: #colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1))
    static let debugTMISecondary = Color(light: #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1), dark: #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1))
    static let debugTMIBackground = Color(light: #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1), dark: #colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1))
    static let debugTMIText = Color(light: #colorLiteral(red: 0.1019607857, green: 0.2784313858, blue: 0.400000006, alpha: 1), dark: #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1))
}
 
extension Color {
    init(light: UIColor, dark: UIColor) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return dark
            default:
                return light
            }
        })
    }
}
#endif

// MARK: - Preview
struct ColorPreview: View {
    var body: some View {
        List {
            ColorRow(name: "TMIPrimary", color: .tmiPrimary)
            ColorRow(name: "TMISecondary", color: .tmiSecondary)
            ColorRow(name: "TMIBackground", color: .tmiBackground)
            ColorRow(name: "TMIText", color: .tmiText)
        }
    }
}

struct ColorRow: View {
    let name: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Rectangle()
                .fill(color)
                .frame(width: 100, height: 30)
                .cornerRadius(8)
        }
    }
}

#Preview {
    Group {
        ColorPreview()
    }
}
