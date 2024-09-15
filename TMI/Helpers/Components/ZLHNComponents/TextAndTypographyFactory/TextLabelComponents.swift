//
//  TextLabelComponents.swift
//  CAMP APP
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI

struct MarqueeTextLabel: View {
    let text: String
    let font: UIFont
    @State private var animateText: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(Font(font))
                    .lineLimit(1)
                    .offset(x: animateText ? -1 * (text.widthOfString(usingFont: font) - geometry.size.width) : 0)
                    .animation(Animation.linear(duration: 8.0).repeatForever(autoreverses: false), value: animateText)
                    .onAppear {
                        animateText = true
                    }
            }
        }
    }
}
