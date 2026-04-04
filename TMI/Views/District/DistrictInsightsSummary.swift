//
//  DistrictInsightsSummary.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import SwiftUI

struct DistrictInsightsSummary: View {
  let insights: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "lightbulb.fill")
          .foregroundColor(.yellow)
        Text("District AI Insights")
          .font(.headline)
        Spacer()
      }
      .padding(.horizontal)

      if insights.isEmpty {
        emptyState
      } else {
        ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
          insightRow(number: index + 1, text: insight)
        }
      }
    }
    .padding(.vertical)
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Image(systemName: "chart.bar.doc.horizontal")
        .font(.largeTitle)
        .foregroundColor(.secondary)

      Text("Generating insights...")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color(UIColor.secondarySystemBackground))
    .cornerRadius(12)
    .padding(.horizontal)
  }

  private func insightRow(number: Int, text: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
      // Number badge
      Text("\(number)")
        .font(.caption)
        .fontWeight(.bold)
        .foregroundColor(Color.tmiTextPrimary)
        .frame(width: 24, height: 24)
        .background(Color.blue)
        .clipShape(Circle())

      // Insight text
      Text(text)
        .font(.subheadline)
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)

      Spacer()
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    .padding(.horizontal)
  }
}

#Preview {
  ScrollView {
    DistrictInsightsSummary(insights: [
      "Jefferson High School shows 12% improvement in engagement over last month",
      "3 students across the district require immediate counselor attention",
      "Form completion rate increased to 78% from 72% last quarter",
      "Lincoln Elementary has highest plan completion rate at 70%"
    ])
  }
  .background(Color(UIColor.secondarySystemBackground))
}
