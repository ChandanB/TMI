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
}