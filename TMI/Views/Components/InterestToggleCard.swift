//
//  InterestToggleCard.swift
//  TMI
//
//  A card view for toggling interest selection
//

import SwiftUI

struct InterestToggleCard: View {
    let interest: Interest
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 12) {
                Image(systemName: interest.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : interest.color)
                
                Text(interest.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? Color.tmiTextOnPrimary : Color.tmiTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.0, contentMode: .fit)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? interest.color : Color.tmiSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? interest.color.opacity(0.3) : Color.tmiBorder, lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
