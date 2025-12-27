//
//  DistrictKPICard.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import SwiftUI

struct DistrictKPICard: View {
  let title: String
  let value: String
  let icon: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: icon)
          .font(.title2)
          .foregroundColor(color)
        Spacer()
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(value)
          .font(.system(size: 28, weight: .bold, design: .rounded))
          .foregroundColor(.primary)

        Text(title)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(2)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
  }
}

#Preview {
  LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    DistrictKPICard(
      title: "Total Students",
      value: "2,250",
      icon: "person.3.fill",
      color: .blue
    )

    DistrictKPICard(
      title: "Engagement Rate",
      value: "72.4%",
      icon: "chart.line.uptrend.xyaxis",
      color: .green
    )

    DistrictKPICard(
      title: "Active Plans",
      value: "87",
      icon: "doc.text.fill",
      color: .orange
    )

    DistrictKPICard(
      title: "Needs Attention",
      value: "12",
      icon: "exclamationmark.triangle.fill",
      color: .red
    )
  }
  .padding()
  .background(Color(UIColor.secondarySystemBackground))
}
