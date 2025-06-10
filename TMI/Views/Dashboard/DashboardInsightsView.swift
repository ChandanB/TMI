//
//  DashboardInsightsView.swift
//  TMI
//
//  Created by Chandan Brown on 4/21/25.
//

import SwiftUI

// MARK: -  Insights View

struct DashboardInsightsView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      // Background
      Color(red: 0.08, green: 0.08, blue: 0.15)
        .ignoresSafeArea()

      // Content
      ScrollView {
        VStack(spacing: 24) {
          // Header
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text("Student Insights")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)

              Text("Advanced analytics and recommendations")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button {
              dismiss()
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .padding(8)
                .foregroundColor(.white)
                .background(
                  Circle()
                    .fill(Color.white.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
          }
          .padding(.top, 20)

          // Insights content
          TMIGlassCard(style: .dashboard) {
            VStack(alignment: .leading, spacing: 20) {
              Text("Performance Overview")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)

              HStack(spacing: 16) {
                StatCircle(
                  value: "78%",
                  title: "Survey\nCompletion",
                  color: .green,
                  icon: "chart.bar.fill"
                )

                StatCircle(
                  value: "65%",
                  title: "Interest\nAlignment",
                  color: Color.tmiSecondary,
                  icon: "person.fill.checkmark"
                )

                StatCircle(
                  value: "82%",
                  title: "Plan\nEffectiveness",
                  color: .orange,
                  icon: "star.fill"
                )
              }
              .padding(.vertical, 10)
            }
          }

          // Recommendations
          TMIGlassCard(style: .dashboard) {
            VStack(alignment: .leading, spacing: 16) {
              Text("AI Recommendations")
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)

              ForEach(InsightRecommendation.sampleRecommendations) { recommendation in
                RecommendationRow(recommendation: recommendation)

                if recommendation.id != InsightRecommendation.sampleRecommendations.last!.id {
                  Divider()
                    .background(Color.white.opacity(0.1))
                }
              }
            }
          }

          // Action buttons
          HStack(spacing: 16) {
            Button {
              // Schedule meeting action
            } label: {
              HStack {
                Image(systemName: "calendar.badge.plus")
                Text("Schedule Meeting")
              }
              .font(.system(size: 16, weight: .semibold))
              .padding(16)
              .frame(maxWidth: .infinity)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color.white.opacity(0.05))
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                  )
              )
              .foregroundColor(.white)
            }
            .buttonStyle(ScaleButtonStyle())

            Button {
              // Export report action
            } label: {
              HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Export Report")
              }
              .font(.system(size: 16, weight: .semibold))
              .padding(16)
              .frame(maxWidth: .infinity)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(
                    LinearGradient(
                      colors: [Color.tmiSecondary, Color.tmiSecondary.opacity(0.8)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    )
                  )
              )
              .foregroundColor(.white)
            }
            .buttonStyle(ScaleButtonStyle())
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
      }
    }
    .preferredColorScheme(.dark)
  }
}
