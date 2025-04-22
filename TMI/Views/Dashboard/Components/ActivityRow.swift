//
//  DashboardActivityRow.swift
//  PathFinder
//
//  Created by Chandan Brown on 9/10/24.
//

import SwiftUI

struct LegacyActivityRow: View {
    let activity: RecentActivity
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.tmiPrimary, .tmiPrimary.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.tmiPrimary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.tmiPrimary.opacity(0.2), lineWidth: 1)
                )
                .symbolEffect(.pulse, options: .repeating.speed(0.7), value: isHovered)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.headline)
                    .foregroundStyle(Color.tmiText)
                    .lineLimit(1)
                
                Text(activity.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text(activity.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colorScheme == .dark ? Color.black.opacity(0.01) : Color.white.opacity(0.01))
                .opacity(isHovered ? 1 : 0)
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

#Preview {
    LegacyActivityRow(activity: RecentActivity.sampleActivity)
        .padding()
        .background(Color.gray.opacity(0.1))
}
