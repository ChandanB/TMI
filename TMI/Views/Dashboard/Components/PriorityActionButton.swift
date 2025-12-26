//
//  PriorityActionButton.swift
//  TMI
//
//  Created by TMI App.
//

import SwiftUI

struct PriorityActionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            TMIHaptics.lightImpact()
            action()
        }) {
            HStack(spacing: TMISpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.tmiTextPrimary)

                    Text("\(count) student\(count == 1 ? "" : "s") waiting")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .padding(TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(Color.tmiBackground)
                    .shadow(color: .black.opacity(isPressed ? 0.05 : 0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}
