//
//  MetricPill.swift
//  TMI
//
//  Created by TMI App.
//

import SwiftUI

struct MetricPill: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String
    let subtitle: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            TMIHaptics.lightImpact()
            action()
        }) {
            HStack(spacing: TMISpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tint.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tint)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(value)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.tmiTextPrimary)

                        Text(label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.tmiTextSecondary)
                    }

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tmiTextTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint.opacity(isHovered ? 1.0 : 0.5))
                    .offset(x: isHovered ? 2 : 0)
            }
            .padding(TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(isHovered ? tint.opacity(0.05) : Color.tmiBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .strokeBorder(tint.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
