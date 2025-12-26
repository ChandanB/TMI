//
//  ActionableCards.swift
//  TMI
//
//  Created by TMI App.
//

import SwiftUI

struct StudentsReadyToGrowCard: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.tmiWarning.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.tmiWarning)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Students Ready to Grow")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.tmiTextPrimary)
                    
                    Text("\(count) students showing potential for improvement")
                        .font(.system(size: 14))
                        .foregroundColor(.tmiTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tmiTextTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tmiSurface)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.tmiWarning.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SurveysPendingCard: View {
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.tmiSecondary.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.tmiSecondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Surveys Pending")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.tmiTextPrimary)
                    
                    Text("\(count) students need to complete interest surveys")
                        .font(.system(size: 14))
                        .foregroundColor(.tmiTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tmiTextTertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tmiSurface)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.tmiSecondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
