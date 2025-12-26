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
                        .font(.system(size: 20))
                        .foregroundColor(resource.category.color)
                }
                
                Spacer()
                
                // Category indicator
                Text(resource.category.rawValue.capitalized)
                    .font(.system(size: 11, weight: .medium))
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(height: 44, alignment: .top)
            
            // Description
            Text(resource.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(3)
                .frame(height: 60, alignment: .top)
            
            Spacer()
            
            // Tags
            if !resource.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(resource.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if resource.tags.count > 2 {
                        Text("+\(resource.tags.count - 2)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(16)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .opacity(0.3)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
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
