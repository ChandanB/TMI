//
//  ResourceCard.swift
//  TMI
//
//  Created by Chandan Brown on 10/26/24.
//

import SwiftUI

struct ResourceCard: View {
    let resource: Resource
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(resource.category.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: resource.category.icon)
                        .font(.title3)
                        .foregroundColor(resource.category.color)
                }
                
                Spacer()
                
                // Category indicator
                Text(resource.category.rawValue.capitalized)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(resource.category.color.opacity(0.2))
                    )
                    .foregroundColor(resource.category.color)
            }
            
            // Title
            Text(resource.title)
                .font(.body.weight(.semibold))
                .foregroundColor(Color.tmiTextPrimary)
                .lineLimit(2)
                .frame(height: 44, alignment: .top)
            
            // Description
            Text(resource.description)
                .font(.subheadline)
                .foregroundColor(Color.tmiTextSecondary)
                .lineLimit(3)
                .frame(height: 60, alignment: .top)
            
            Spacer()
            
            // Tags
            if !resource.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(resource.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(TMIColors.fill)
                            )
                            .foregroundColor(Color.tmiTextSecondary)
                    }
                    
                    if resource.tags.count > 2 {
                        Text("+\(resource.tags.count - 2)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(TMIColors.fill)
                            )
                            .foregroundColor(Color.tmiTextSecondary)
                    }
                }
            }
        }
        .padding(16)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(TMIColors.fill)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.tmiSurface)
                        .opacity(0.3)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [TMIColors.separator, .clear, TMIColors.separator],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
