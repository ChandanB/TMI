//
//  HelpTooltipButton.swift
//  TMI
//
//  Created by TMI App.
//

import SwiftUI

struct HelpTooltipButton: View {
    let message: String
    @State private var showTooltip = false

    var body: some View {
        ZStack(alignment: .top) {
            Button(action: { withAnimation { showTooltip.toggle() } }) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.tmiPrimary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                #if os(macOS)
                withAnimation { showTooltip = hovering }
                #endif
            }

            if showTooltip {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(Color.tmiTextPrimary)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(Color.tmiSurface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.tmiPrimary.opacity(0.7), lineWidth: 1)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 220)
                    .offset(y: 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(99)
            }
        }
        .padding(.leading, 2)
        .padding(.bottom)
    }
}
