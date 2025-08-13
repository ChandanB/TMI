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
  
  @State private var aiInsights: [AIInsight] = []
  @State private var isLoadingInsights = false
  @State private var showingLegacyInsights = false

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

          // AI Insights
          if isLoadingInsights {
            TMIGlassCard(style: .dashboard) {
              VStack(spacing: 20) {
                ProgressView()
                  .scaleEffect(1.2)
                  .tint(.white)
                
                VStack(spacing: 8) {
                  Text("Analyzing Data with Foundation Models")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                  
                  Text("Generating AI-powered educational insights...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                }
              }
              .frame(minHeight: 120)
            }
          } else if !aiInsights.isEmpty {
            TMIGlassCard(style: .dashboard) {
              VStack(alignment: .leading, spacing: 16) {
                HStack {
                  Text("🧠 AI Insights")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                  
                  Spacer()
                }

                ForEach(aiInsights.prefix(4)) { insight in
                  AIInsightRow(insight: insight)

                  if insight.id != aiInsights.prefix(4).last!.id {
                    Divider()
                      .background(Color.white.opacity(0.1))
                  }
                }
                
                if aiInsights.count > 4 {
                  Text("+ \(aiInsights.count - 4) more insights")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 8)
                }
              }
            }
          } else {
            // Fallback to legacy recommendations
            TMIGlassCard(style: .dashboard) {
              VStack(alignment: .leading, spacing: 16) {
                Text("Basic Recommendations")
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
    .task {
      await loadAIInsights()
    }
    .sheet(isPresented: $showingLegacyInsights) {
      LegacyInsightsView(dashboardData: dashboardData)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .preferredColorScheme(.dark)
  }
  
  // MARK: - AI Insights Loading
  
  @MainActor
  private func loadAIInsights() async {
    isLoadingInsights = true
    
    if #available(iOS 26.0, *) {
      // Use Foundation Models for iOS 26+
      aiInsights = await AIInsightsService.shared.generateInsights(from: dashboardData)
    } else if #available(iOS 18.0, *) {
      // Use enhanced rule-based insights for iOS 18-25
      aiInsights = await AIInsightsService.shared.generateInsights(from: dashboardData)
    } else {
      // Fallback for older iOS versions
      aiInsights = []
    }
    
    isLoadingInsights = false
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

// MARK: - AI Insight Row Component

struct AIInsightRow: View {
  let insight: AIInsight
  @State private var isExpanded = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Main insight content
      HStack(spacing: 12) {
        // Priority/Category indicator
        ZStack {
          Circle()
            .fill(insight.priority.color.opacity(0.2))
            .frame(width: 40, height: 40)
          
          Image(systemName: insight.category.icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(insight.priority.color)
        }
        
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(insight.title)
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.white)
            
            Spacer()
            
            // Confidence indicator
            HStack(spacing: 4) {
              Image(systemName: "brain.head.profile")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.6))
              
              Text("\(Int(insight.confidence * 100))%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            }
          }
          
          Text(insight.description)
            .font(.system(size: 14))
            .foregroundColor(.white.opacity(0.8))
            .lineLimit(isExpanded ? nil : 2)
          
          // Priority and category tags
          HStack(spacing: 8) {
            InsightTagView(text: insight.priority.rawValue, color: insight.priority.color)
            InsightTagView(text: insight.category.rawValue, color: insight.category.color)
            
            Spacer()
            
            if !insight.actionItems.isEmpty {
              Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                  isExpanded.toggle()
                }
              } label: {
                HStack(spacing: 4) {
                  Text(isExpanded ? "Less" : "Actions")
                    .font(.system(size: 12, weight: .medium))
                  
                  Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10))
                }
                .foregroundColor(.white.opacity(0.7))
              }
            }
          }
          .padding(.top, 4)
        }
      }
      
      // Expanded action items
      if isExpanded && !insight.actionItems.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Recommended Actions:")
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
          
          ForEach(Array(insight.actionItems.enumerated()), id: \.offset) { index, action in
            HStack(alignment: .top, spacing: 8) {
              Text("\(index + 1).")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 16, alignment: .leading)
              
              Text(action)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
            }
          }
        }
        .padding(.leading, 52)
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Insight Tag View Component

struct InsightTagView: View {
  let text: String
  let color: Color
  
  var body: some View {
    Text(text)
      .font(.system(size: 10, weight: .medium))
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(
        Capsule()
          .fill(color.opacity(0.15))
      )
      .foregroundColor(color)
  }
}

// MARK: - Legacy Insights View

struct LegacyInsightsView: View {
  let dashboardData: DashboardData
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      ZStack {
        TMIBackgroundView(variant: .dashboard)
          .ignoresSafeArea()
        
        ScrollView {
          VStack(spacing: 20) {
            TMIGlassCard(style: .dashboard) {
              VStack(alignment: .leading, spacing: 16) {
                Text("Legacy Recommendations")
                  .font(.title3.weight(.semibold))
                  .foregroundColor(.white)

                ForEach(legacyRecommendations) { recommendation in
                  RecommendationRow(recommendation: recommendation)

                  if recommendation.id != legacyRecommendations.last!.id {
                    Divider()
                      .background(Color.white.opacity(0.1))
                  }
                }
              }
            }
          }
          .padding(20)
        }
      }
      .navigationTitle("Legacy Insights")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
    }
    .preferredColorScheme(.dark)
  }
  
  private var legacyRecommendations: [InsightRecommendation] {
    // This would be the same logic as the original recommendations
    var recs: [InsightRecommendation] = []
    
    let completionRate = dashboardData.totalStudents > 0 ? 
      Double(dashboardData.surveysCompleted) / Double(dashboardData.totalStudents) : 0
    let alignmentRate = dashboardData.totalStudents > 0 ? 
      Double(dashboardData.plansAligned) / Double(dashboardData.totalStudents) : 0
    
    if completionRate < 0.7 {
      let missingCount = dashboardData.totalStudents - dashboardData.surveysCompleted
      recs.append(InsightRecommendation(
        title: "Increase survey completion rate",
        description: "\(missingCount) students haven't completed their interest surveys. Consider sending reminder notifications.",
        icon: "bell.fill",
        color: .orange
      ))
    }
    
    if alignmentRate < 0.6 {
      let unalignedCount = dashboardData.totalStudents - dashboardData.plansAligned
      recs.append(InsightRecommendation(
        title: "Improve plan alignment",
        description: "\(unalignedCount) students need aligned TMI plans. Schedule individual meetings to assess their needs.",
        icon: "person.2.fill",
        color: .blue
      ))
    }
    
    return Array(recs.prefix(3))
  }
}
