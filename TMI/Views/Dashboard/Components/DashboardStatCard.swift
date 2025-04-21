//
//  DashboardStatCard.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 2)
                .symbolEffect(
                    .bounce.up.byLayer,
                    options: .speed(1.5),
                    value: isAnimating
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                Text(value)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.tmiText)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .opacity(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorScheme == .dark ? .black.opacity(0.4) : .white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
        .shadow(
            color: colorScheme == .dark ? .clear : Color.black.opacity(0.05),
            radius: 8, x: 0, y: 4
        )
        .onAppear {
            withAnimation(.bouncy.delay(0.2)) {
                isAnimating.toggle()
            }
        }
        .onChange(of: value) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isAnimating.toggle()
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatCard(title: "Total Students", value: "425", icon: "person.3", color: .blue)
        StatCard(title: "Surveys Completed", value: "287", icon: "checkmark.circle", color: .green)
        StatCard(title: "Plans Aligned", value: "182", icon: "star", color: .orange)
    }
    .padding()
}
