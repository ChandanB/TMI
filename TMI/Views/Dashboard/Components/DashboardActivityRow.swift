//
//  DashboardActivityRow.swift
//  TMI
//
//  Created by TMI App.
//

import SwiftUI

struct DashboardActivityRow: View {
  var activity: RecentActivity

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 16) {
      // Activity Icon
      ZStack {
        Circle()
          .fill(activity.iconColor.opacity(0.15))
          .frame(width: 40, height: 40)

        Image(systemName: activity.icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(activity.iconColor)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(activity.title)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(Color.tmiTextPrimary)

        Text(activity.description)
          .font(.system(size: 13))
          .foregroundColor(Color.tmiTextSecondary)
          .lineLimit(2)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(activity.timeAgo)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(Color.tmiTextTertiary)

        if activity.showProgress {
          ProgressView(value: activity.progressValue)
            .tmiProgressStyle(color: activity.iconColor)
            .frame(width: 50)
        }
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(isHovered ? 0.05 : 0))
    )
    .contentShape(Rectangle())
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.2)) {
        isHovered = hovering
      }
    }
  }
}
