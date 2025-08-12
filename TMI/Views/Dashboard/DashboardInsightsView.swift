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
  let dashboardData: DashboardData

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
                  value: "\(Int(surveyCompletionRate * 100))%",
                  title: "Survey\nCompletion",
                  color: .green,
                  icon: "chart.bar.fill"
                )

                StatCircle(
                  value: "\(Int(planAlignmentRate * 100))%", 
                  title: "Plan\nAlignment",
                  color: Color.tmiSecondary,
                  icon: "person.fill.checkmark"
                )

                StatCircle(
                  value: "\(Int(planEffectiveness * 100))%",
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

              ForEach(recommendations) { recommendation in
                RecommendationRow(recommendation: recommendation)

                if recommendation.id != recommendations.last!.id {
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
  
  // MARK: - Computed Properties
  
  private var surveyCompletionRate: Double {
    guard dashboardData.totalStudents > 0 else { return 0.0 }
    return Double(dashboardData.surveysCompleted) / Double(dashboardData.totalStudents)
  }
  
  private var planAlignmentRate: Double {
    guard dashboardData.totalStudents > 0 else { return 0.0 }
    return Double(dashboardData.plansAligned) / Double(dashboardData.totalStudents)
  }
  
  private var planEffectiveness: Double {
    // Calculate plan effectiveness based on plans vs students ratio and activity
    let planRatio = dashboardData.totalStudents > 0 ? 
      Double(dashboardData.activeTMIPlans) / Double(dashboardData.totalStudents) : 0.0
    let activityBonus = dashboardData.recentActivities.count > 0 ? 0.15 : 0.0
    return min(1.0, planRatio * 0.8 + activityBonus)
  }
  
  private var recommendations: [InsightRecommendation] {
    var recs: [InsightRecommendation] = []
    
    // Survey completion recommendations
    if surveyCompletionRate < 0.7 {
      let missingCount = dashboardData.totalStudents - dashboardData.surveysCompleted
      recs.append(InsightRecommendation(
        title: "Increase survey completion rate",
        description: "\(missingCount) students haven't completed their interest surveys. Consider sending reminder notifications.",
        icon: "bell.fill",
        color: .orange
      ))
    }
    
    // Plan alignment recommendations
    if planAlignmentRate < 0.6 {
      let unalignedCount = dashboardData.totalStudents - dashboardData.plansAligned
      recs.append(InsightRecommendation(
        title: "Improve plan alignment",
        description: "\(unalignedCount) students need aligned TMI plans. Schedule individual meetings to assess their needs.",
        icon: "person.2.fill",
        color: .blue
      ))
    }
    
    // Interest identification recommendations
    if dashboardData.interestsIdentified < dashboardData.totalStudents * 2 {
      recs.append(InsightRecommendation(
        title: "Expand interest exploration",
        description: "Students show limited interest diversity. Consider organizing career exploration workshops.",
        icon: "lightbulb.fill",
        color: .yellow
      ))
    }
    
    // Recent activity recommendations
    if dashboardData.recentActivities.count < 3 {
      recs.append(InsightRecommendation(
        title: "Boost student engagement",
        description: "Low recent activity detected. Plan interactive sessions to re-engage students.",
        icon: "chart.line.uptrend.xyaxis",
        color: .green
      ))
    }
    
    // Positive recommendations
    if surveyCompletionRate > 0.8 && planAlignmentRate > 0.7 {
      recs.append(InsightRecommendation(
        title: "Excellent progress!",
        description: "High completion and alignment rates. Consider expanding to advanced tracking features.",
        icon: "star.fill",
        color: .teal
      ))
    }
    
    return Array(recs.prefix(3)) // Limit to 3 recommendations
  }
}

// MARK: - Preview

#Preview {
  DashboardInsightsView(dashboardData: DashboardData(
    engagementData: [],
    totalStudents: 25,
    activeTMIPlans: 18,
    interestsIdentified: 50,
    surveysCompleted: 20,
    plansAligned: 15,
    recentActivities: []
  ))
}
