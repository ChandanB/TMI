//
//  View+TMIShadow.swift
//  TMI
//
//  Created by Cody on the current date.
//

import SwiftUI

extension View {
    /// Applies a small shadow to the view
    func tmiShadowSmall() -> some View {
        self.shadow(color: Color.black.opacity(0.07), radius: 4, x: 0, y: 2)
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
    
    /// Applies a medium shadow to the view
    func tmiShadowMedium() -> some View {
        self.shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 2)
    }
    
    /// Applies a large shadow to the view
    func tmiShadowLarge() -> some View {
        self.shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 3)
    }
    
    /// Applies an elevated shadow for floating elements
    func tmiShadowElevated() -> some View {
        self.shadow(color: Color.black.opacity(0.15), radius: 24, x: 0, y: 12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
