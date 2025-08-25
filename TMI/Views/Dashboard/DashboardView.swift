//
//  Created by Chandan Brown on 9/10/24.
//

import Charts
import Combine
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Dashboard Data Model

struct DashboardData: Equatable, Sendable {
  var engagementData: [EngagementData] = []
  var totalStudents: Int = 0
  var activeTMIPlans: Int = 0
  var interestsIdentified: Int = 0
  var surveysCompleted: Int = 0
  var plansAligned: Int = 0
  var recentActivities: [RecentActivity] = []
}

// MARK: - Environment Key
extension EnvironmentValues {
  @Entry var dashboardStateModel: DashboardStateModel = DashboardStateModel()
}

// MARK: - State Model

@Observable
final class DashboardStateModel: BaseStateModel<DashboardData, IdentifiableError> {
  // MARK: - Dependencies
  private let studentService = StudentService()
  private let tmiPlanService = TMIPlanService()

  // MARK: - Cancellables
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization
  override init() {
    super.init()

    // Initialize UI state
    ui.set("selectedTimeFrame", value: TimeFrame.week)
    ui.set("selectedDataPoint", value: nil as AlignmentData?)
    ui.set("showingInsightsSheet", value: false)
  }

  deinit {
    cancellables.forEach { $0.cancel() }
  }

  // MARK: - Data Fetching

  @MainActor
  override func fetch() async {
    updateState(.loading)

    do {
      // Fetch live data from services
      async let studentsTask = studentService.fetchStudents()
      async let plansTask = tmiPlanService.fetchPlans()
      
      let (students, plans) = try await (studentsTask, plansTask)
      
      // Calculate real metrics
      let totalStudents = students.count
      let activeTMIPlans = plans.count
      let surveysCompleted = students.filter { !($0.surveyResults?.isEmpty ?? true) }.count
      let interestsIdentified = students.reduce(0) { $0 + $1.interests.count }
      
      // Calculate plans aligned (students with plans vs total students)  
      let studentsWithPlans = Set(plans.flatMap { $0.students.compactMap { $0.id } }).count
      let plansAligned = studentsWithPlans
      
      // Generate engagement data and recent activities
      let engagementData = generateEngagementData(from: students)
      let recentActivities = generateRecentActivities(from: students, plans: plans)

      let dashboardData = DashboardData(
        engagementData: engagementData,
        totalStudents: totalStudents,
        activeTMIPlans: activeTMIPlans,
        interestsIdentified: interestsIdentified,
        surveysCompleted: surveysCompleted,
        plansAligned: plansAligned,
        recentActivities: recentActivities
      )

      updateState(.loaded(dashboardData))
    } catch {
      print("[DashboardStateModel] Error fetching dashboard data: \(error)")
      handleError(error, userFriendlyMessage: "Failed to load dashboard data")
    }
  }
  
  private func generateEngagementData(from students: [Student]) -> [EngagementData] {
    // Generate weekly engagement data based on student interaction dates
    let calendar = Calendar.current
    let now = Date()
    var weeklyData: [EngagementData] = []
    
    for week in 0..<7 {
      let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: now) ?? now
      let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
      
      let weeklyEngagement = students.filter { student in
        guard let lastInteraction = student.lastInteractionDate else { return false }
        return lastInteraction >= weekStart && lastInteraction <= weekEnd
      }.count
      
      let weekFormatter = DateFormatter()
      weekFormatter.dateFormat = "MMM d"
      
      weeklyData.append(EngagementData(
        week: weekFormatter.string(from: weekStart),
        engagementLevel: Double(weeklyEngagement)
      ))
    }
    
    return weeklyData.reversed() // Most recent week last
  }
  
  private func generateRecentActivities(from students: [Student], plans: [TMIPlan]) -> [RecentActivity] {
    var activities: [RecentActivity] = []
    
    // Recent surveys completed
    let recentSurveys = students.compactMap { student -> RecentActivity? in
      guard let surveyResults = student.surveyResults,
            let latestSurvey = surveyResults.sorted(by: { $0.date > $1.date }).first,
            latestSurvey.isComplete,
            latestSurvey.date > Date().addingTimeInterval(-7 * 24 * 60 * 60) else { return nil } // Last 7 days
      
      return RecentActivity(
        icon: "checkmark.circle.fill",
        title: "Survey Completed",
        description: "\(student.name) completed \(latestSurvey.surveyName)",
        date: latestSurvey.date,
        iconColor: .green
      )
    }
    
    // Recent TMI Plans created/updated
    let recentPlans = plans.compactMap { plan -> RecentActivity? in
      guard plan.lastUpdated > Date().addingTimeInterval(-7 * 24 * 60 * 60) else { return nil } // Last 7 days
      
      let studentNames = plan.students.map { $0.name }.joined(separator: ", ")
      let description = plan.students.count == 1 
        ? "Plan for \(studentNames) was updated"
        : "Plan for \(plan.students.count) students was updated"
      
      return RecentActivity(
        icon: "doc.fill",
        title: "TMI Plan Updated",
        description: description,
        date: plan.lastUpdated,
        iconColor: .blue,
        showProgress: true,
        progressValue: Double(plan.goals.count) / 5.0 // Assume 5 is max interventions
      )
    }
    
    // Recently added students
    let recentStudents = students.compactMap { student -> RecentActivity? in
      guard let lastInteraction = student.lastInteractionDate,
            lastInteraction > Date().addingTimeInterval(-3 * 24 * 60 * 60) else { return nil } // Last 3 days
      
      return RecentActivity(
        icon: "person.fill.badge.plus",
        title: "New Student Activity",
        description: "Recent interaction with \(student.name)",
        date: lastInteraction,
        iconColor: .purple
      )
    }
    
    // Combine and sort by date
    activities.append(contentsOf: recentSurveys)
    activities.append(contentsOf: recentPlans)
    activities.append(contentsOf: recentStudents)
    
    // Sort by date (most recent first) and take top 5
    return Array(activities.sorted { $0.date > $1.date }.prefix(5))
  }

  @MainActor
  override func refresh() async {
    await fetch()
  }

  @MainActor
  func fetchDataForTimeFrame(_ timeFrame: TimeFrame) async {
    // Don't update selectedTimeFrame here to avoid infinite loop
    // The UI binding will handle the selectedTimeFrame state
    
    // Instead of refetching all data, just regenerate the dashboard data
    // with the new timeframe applied to existing data
    guard case .loaded(let currentData) = state else {
      // If no data is loaded yet, fetch it
      await fetch()
      return
    }
    
    // Regenerate data with new timeframe filter
    let filteredData = filterDataForTimeFrame(currentData, timeFrame: timeFrame)
    updateState(.loaded(filteredData))
  }
  
  private func filterDataForTimeFrame(_ data: DashboardData, timeFrame: TimeFrame) -> DashboardData {
    // Use TimeFrame's built-in date calculation methods
    let startDate = timeFrame.startDate()
    let endDate = timeFrame.endDate()
    
    // Filter recent activities based on timeframe
    let filteredActivities = data.recentActivities.filter { activity in
      activity.date >= startDate && activity.date <= endDate
    }
    
    // Return filtered data with the same core stats but filtered activities
    // Note: Core stats (totalStudents, etc.) remain the same as they represent overall counts
    return DashboardData(
      engagementData: data.engagementData, // Keep engagement data as is for now
      totalStudents: data.totalStudents,
      activeTMIPlans: data.activeTMIPlans,
      interestsIdentified: data.interestsIdentified,
      surveysCompleted: data.surveysCompleted,
      plansAligned: data.plansAligned,
      recentActivities: filteredActivities
    )
  }

  // MARK: - UI State Accessors

  var selectedTimeFrame: TimeFrame {
    get { return ui.get("selectedTimeFrame") ?? .week }
    set { ui.set("selectedTimeFrame", value: newValue) }
  }

  var selectedDataPoint: AlignmentData? {
    get { return ui.get("selectedDataPoint") }
    set { ui.set("selectedDataPoint", value: newValue) }
  }

  var showingInsightsSheet: Bool {
    get { return ui.get("showingInsightsSheet") ?? false }
    set { ui.set("showingInsightsSheet", value: newValue) }
  }

  var showingAllActivities: Bool {
    get { return ui.get("showingAllActivities") ?? false }
    set { ui.set("showingAllActivities", value: newValue) }
  }

  // MARK: - Helper Methods
  
  var alignmentData: [AlignmentData] {
    guard case .loaded(let dashboardData) = state else {
      return []
    }
    return generateAlignmentData(from: dashboardData)
  }
  
  private func generateAlignmentData(from dashboardData: DashboardData) -> [AlignmentData] {
    // Generate alignment data based on student engagement and TMI plan effectiveness
    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul"]
    let baseAlignment = 0.45
    
    return months.enumerated().map { index, month in
      // Calculate alignment based on surveys completed and plans aligned
      let completionRate = dashboardData.totalStudents > 0 ?
        Double(dashboardData.surveysCompleted) / Double(dashboardData.totalStudents) : 0.0
      let planRate = dashboardData.totalStudents > 0 ?
        Double(dashboardData.plansAligned) / Double(dashboardData.totalStudents) : 0.0
      
      // Add some variance and progression over time
      let monthProgress = Double(index) * 0.02 // Small improvement over time
      let variance = Double.random(in: -0.05...0.05) // Random variance
      
      let alignment = min(0.95, max(0.25, baseAlignment + (completionRate * 0.3) + (planRate * 0.2) + monthProgress + variance))
      
      return AlignmentData(timePeriod: month, alignmentPercentage: alignment)
    }
  }

  func averageAlignment() -> String {
    let data = alignmentData
    guard !data.isEmpty else { return "0.0" }
    let average = data.map { $0.alignmentPercentage }.reduce(0, +) / Double(data.count)
    return String(format: "%.1f", average * 100)
  }

  func highestAlignment() -> String {
    let highest = alignmentData.map { $0.alignmentPercentage }.max() ?? 0
    return String(format: "%.1f", highest * 100)
  }

  func highestAlignmentPeriod() -> String {
    alignmentData.max { $0.alignmentPercentage < $1.alignmentPercentage }?.timePeriod ?? "N/A"
  }

  func alignmentTrend() -> String {
    let values = alignmentData.map { $0.alignmentPercentage }
    if let first = values.first, let last = values.last {
      if first < last {
        return "Increasing"
      } else if first > last {
        return "Decreasing"
      } else {
        return "Stable"
      }
    }
    return "No Data"
  }

  func trendIcon() -> String {
    let trend = alignmentTrend()
    if trend == "Increasing" {
      return "arrow.up.right"
    } else if trend == "Decreasing" {
      return "arrow.down.right"
    } else {
      return "arrow.right"
    }
  }

  func trendColor() -> Color {
    let trend = alignmentTrend()
    if trend == "Increasing" {
      return .green
    } else if trend == "Decreasing" {
      return .red
    } else {
      return .orange
    }
  }
}

// MARK: -  Activity Row

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
          .foregroundColor(.white)

        Text(activity.description)
          .font(.system(size: 13))
          .foregroundColor(.white.opacity(0.7))
          .lineLimit(2)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(activity.timeAgo)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.5))

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

// MARK: - Redesigned Dashboard View

struct DashboardView: View {
  @Environment(\.dashboardStateModel) var stateModel
  @Environment(\.horizontalSizeClass) private var sizeClass

  @State private var selectedTimeFrame: TimeFrame = .week
  @State private var showingInsightsSheet = false
  @State private var showingUserProfile = false
  @State private var headerAnimation = false
  @State private var cardsAnimation = false
  @State private var chartAnimation = false
  @State private var buttonAnimation = false
  
  // AI Insights state
  @State private var aiInsights: [AIInsight] = []
  @State private var isLoadingInsights = false

  var body: some View {
    ZStack {
      // Dynamic background - Using unified TMIBackgroundView
      TMIBackgroundView(variant: .dashboard)

      Group {
        switch stateModel.state {
        case .idle, .loading:
          loadingView

        case .loaded(let dashboardData):
          dashboardContent(dashboardData)

        case .error(let error):
          errorView(error)
        }
      }
    }
    .navigationTitle("TMI Dashboard")
    .foregroundColor(.white)
    .foregroundStyle(.white)
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          showingUserProfile = true
        } label: {
          HStack(spacing: 8) {
            Text("Educator")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.white)

            Image(systemName: "person.crop.circle.fill")
              .font(.system(size: 24))
              .foregroundStyle(
                LinearGradient(
                  colors: [.white, .white.opacity(0.8)],
                  startPoint: .top,
                  endPoint: .bottom
                )
              )
              .symbolRenderingMode(.hierarchical)
              .overlay(
                Circle()
                  .stroke(
                    LinearGradient(
                      colors: [Color.tmiSecondary.opacity(0.8), Color.tmiSecondary.opacity(0.4)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                  )
                  .padding(-4)
              )
          }
          .padding(8)
          .background(
            Capsule()
              .fill(.ultraThinMaterial.opacity(0.5))
          )
        }
        .buttonStyle(ScaleButtonStyle())
      }
    }
    .sheet(isPresented: binding(stateModel, \.showingAllActivities)) {
      if case .loaded(let dashboardData) = stateModel.state {
        AllActivitiesView(activities: dashboardData.recentActivities)
          .presentationDetents([PresentationDetent.medium, PresentationDetent.large])
          .presentationDragIndicator(.visible)
      }
    }
    .sheet(isPresented: $showingUserProfile) {
      UserProfileView()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    .task {
      // Initialize the local selectedTimeFrame with the stateModel's value
      selectedTimeFrame = stateModel.selectedTimeFrame
      await stateModel.fetch()
      
      // Load AI insights after dashboard data is available
      if case .loaded(let dashboardData) = stateModel.state {
        await loadAIInsights(for: dashboardData)
      }
    }
    .refreshable {
      await stateModel.refresh()
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Loading View

  private var loadingView: some View {
    VStack(spacing: 24) {
      ProgressView()
        .scaleEffect(1.5)
        .tint(.white)

      Text("Loading your dashboard")
        .font(.headline)
        .foregroundColor(.white)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Error View

  private func errorView(_ error: IdentifiableError) -> some View {
    VStack(spacing: 24) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 50))
        .foregroundStyle(
          LinearGradient(
            colors: [.orange, .red],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .symbolEffect(.pulse, options: .repeating)

      Text("Unable to Load Dashboard")
        .font(.title2.bold())
        .foregroundColor(.white)

      Text(error.message)
        .multilineTextAlignment(.center)
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 40)

      Button {
        Task {
          await stateModel.fetch()
        }
      } label: {
        Text("Try Again")
          .font(.headline)
          .padding(.horizontal, 30)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.tmiSecondary)
          )
          .foregroundColor(.white)
      }
      .buttonStyle(ScaleButtonStyle())
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Dashboard Content

  @ViewBuilder
  private func dashboardContent(_ data: DashboardData) -> some View {
    ScrollView {
      VStack(spacing: 24) {
        // Welcome header
        welcomeHeader
          .padding(.top, 16)
          .offset(y: headerAnimation ? 0 : -20)
          .opacity(headerAnimation ? 1 : 0)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.1),
            value: headerAnimation
          )

        // Time frame selector
        TimeFrameSelector(selection: $selectedTimeFrame)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 8)
          .opacity(headerAnimation ? 1 : 0)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.2),
            value: headerAnimation
          )
          .onChange(of: selectedTimeFrame) { _, newTimeFrame in
            Task {
              await stateModel.fetchDataForTimeFrame(newTimeFrame)
            }
          }

        // Dashboard cards
        if sizeClass == .regular {
          HStack(alignment: .top, spacing: 20) {
            quickStatsView(data)
              .frame(maxWidth: .infinity)
            recentActivitiesView(data)
              .frame(maxWidth: .infinity)
          }
          .opacity(cardsAnimation ? 1 : 0)
          .offset(y: cardsAnimation ? 0 : 30)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.3),
            value: cardsAnimation
          )
        } else {
          VStack(spacing: 20) {
            quickStatsView(data)
            recentActivitiesView(data)
          }
          .opacity(cardsAnimation ? 1 : 0)
          .offset(y: cardsAnimation ? 0 : 30)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.3),
            value: cardsAnimation
          )
        }

        // Alignment chart
        DashboardAlignmentChartView(alignmentData: stateModel.alignmentData)
          .opacity(chartAnimation ? 1 : 0)
          .offset(y: chartAnimation ? 0 : 30)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.4),
            value: chartAnimation
          )

        // Performance Overview (from insights)
        performanceOverviewView(data)
          .opacity(buttonAnimation ? 1 : 0)
          .offset(y: buttonAnimation ? 0 : 20)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.5),
            value: buttonAnimation
          )

        // Insights & Recommendations (embedded)
        insightsAndRecommendationsView(data)
          .opacity(buttonAnimation ? 1 : 0)
          .offset(y: buttonAnimation ? 0 : 20)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.6),
            value: buttonAnimation
          )

        // Action buttons (from insights)
        dashboardActionButtons(data)
          .opacity(buttonAnimation ? 1 : 0)
          .offset(y: buttonAnimation ? 0 : 20)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.7),
            value: buttonAnimation
          )
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 40)
    }
    .onAppear {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        headerAnimation = true
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        cardsAnimation = true
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        chartAnimation = true
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        buttonAnimation = true
      }
    }
  }

  private var welcomeHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 6) {
        Text("Welcome back,")
          .font(.system(size: 18, weight: .medium))
          .foregroundColor(.white.opacity(0.8))

        Text("Educator!")
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }

      Spacer()

      // Date display
      VStack(alignment: .trailing, spacing: 4) {
        Text(Date(), style: .date)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.white.opacity(0.7))

        Text(Date(), style: .time)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.5))
      }
    }
  }

  private func quickStatsView(_ data: DashboardData) -> some View {
    TMIGlassCard(style: .dashboard) {
      VStack(alignment: .leading, spacing: 20) {
        Text("Quick Stats")
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(.white)

        VStack(spacing: 16) {
          StatCard(
            title: "Total Students",
            value: "\(data.totalStudents)",
            icon: "person.3.fill",
            color: Color.blue
          )

          StatCard(
            title: "Surveys Completed",
            value: "\(data.surveysCompleted)",
            icon: "checkmark.circle.fill",
            color: Color.green
          )

          StatCard(
            title: "Plans Aligned",
            value: "\(data.plansAligned)",
            icon: "star.fill",
            color: Color.orange
          )
        }
        .animation(
          .spring(response: 0.4, dampingFraction: 0.8), value: stateModel.selectedTimeFrame)
      }
    }
  }

  private func recentActivitiesView(_ data: DashboardData) -> some View {
    TMIGlassCard(style: .dashboard) {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Text("Recent Activities")
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(.white)

          Spacer()

          Button {
            // Show all activities sheet
            stateModel.showingAllActivities = true
          } label: {
            HStack(spacing: 4) {
              Text("View All")
                .font(.system(size: 14, weight: .medium))

              Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(Color.tmiSecondary)
          }
          .buttonStyle(ScaleButtonStyle())
        }

        Divider()
          .background(Color.white.opacity(0.1))

        if data.recentActivities.isEmpty {
          VStack(spacing: 16) {
            Image(systemName: "tray.fill")
              .font(.system(size: 30))
              .foregroundColor(.white.opacity(0.3))

            Text("No recent activities")
              .font(.system(size: 16))
              .foregroundColor(.white.opacity(0.6))
          }
          .frame(maxWidth: .infinity, minHeight: 150)
        } else {
          LazyVStack(spacing: 12) {
            ForEach(data.recentActivities) { activity in
              DashboardActivityRow(activity: activity)

              if activity.id != data.recentActivities.last!.id {
                Divider()
                  .background(Color.white.opacity(0.1))
              }
            }
          }
        }
      }
    }
  }

  // MARK: - Integrated Insights Views

  private func performanceOverviewView(_ data: DashboardData) -> some View {
    TMIGlassCard(style: .dashboard) {
      VStack(alignment: .leading, spacing: 20) {
        Text("Performance Overview")
          .font(.title3.weight(.semibold))
          .foregroundColor(.white)

        HStack(spacing: 16) {
          StatCircle(
            value: "\(Int(surveyCompletionRate(data) * 100))%",
            title: "Survey\nCompletion",
            color: .green,
            icon: "chart.bar.fill"
          )

          StatCircle(
            value: "\(Int(planAlignmentRate(data) * 100))%",
            title: "Plan\nAlignment",
            color: Color.tmiSecondary,
            icon: "person.fill.checkmark"
          )

          StatCircle(
            value: "\(Int(planEffectiveness(data) * 100))%",
            title: "Plan\nEffectiveness",
            color: .orange,
            icon: "star.fill"
          )
        }
        .padding(.vertical, 10)
      }
    }
  }

  private func insightsAndRecommendationsView(_ data: DashboardData) -> some View {
    Group {
      // AI-Powered Insights & Recommendations
      if #available(iOS 18.0, *) {
        TMIGlassCard(style: .dashboard) {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("AI Insights & Recommendations")
                  .font(.title3.weight(.semibold))
                  .foregroundColor(.white)
                
                Text("Generated by advanced analytics")
                  .font(.subheadline)
                  .foregroundColor(.white.opacity(0.7))
              }
              
              Spacer()
              
              if isLoadingInsights {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: .white))
                  .scaleEffect(0.8)
              }
            }
            
            Divider()
              .background(Color.white.opacity(0.2))
            
            if aiInsights.isEmpty && !isLoadingInsights {
              VStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                  .font(.system(size: 24))
                  .foregroundColor(.white.opacity(0.6))
                
                Text("Generating AI insights...")
                  .font(.subheadline)
                  .foregroundColor(.white.opacity(0.7))
                
                Text("Analysis will appear as data becomes available")
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.5))
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 20)
            } else {
              ForEach(aiInsights.prefix(3)) { insight in
                AIInsightRow(insight: insight)
                
                if insight.id != aiInsights.prefix(3).last!.id {
                  Divider()
                    .background(Color.white.opacity(0.1))
                }
              }
            }
          }
        }
      } else {
        // Fallback for iOS < 18.0
        TMIGlassCard(style: .dashboard) {
          VStack(alignment: .leading, spacing: 16) {
            HStack {
              VStack(alignment: .leading, spacing: 4) {
                Text("Insights & Recommendations")
                  .font(.title3.weight(.semibold))
                  .foregroundColor(.white)
                
                Text("Based on current data patterns")
                  .font(.subheadline)
                  .foregroundColor(.white.opacity(0.7))
              }
              
              Spacer()
            }
            
            Divider()
              .background(Color.white.opacity(0.2))
            
            ForEach(recommendations(data).prefix(3)) { recommendation in
              BasicRecommendationRow(recommendation: recommendation)
              
              if recommendation.id != recommendations(data).prefix(3).last!.id {
                Divider()
                  .background(Color.white.opacity(0.1))
              }
            }
          }
        }
      }
    }
  }

  private func dashboardActionButtons(_ data: DashboardData) -> some View {
    HStack(spacing: 16) {
      Button {
        // Open calendar app for scheduling
        openCalendarApp()
      } label: {
        HStack {
          Image(systemName: "calendar.badge.plus")
          Text("Open Calendar")
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
        // Export report action - share dashboard data
        exportDashboardReport(data)
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

  // MARK: - Insights Helper Methods

  private func surveyCompletionRate(_ data: DashboardData) -> Double {
    guard data.totalStudents > 0 else { return 0.0 }
    return Double(data.surveysCompleted) / Double(data.totalStudents)
  }

  private func planAlignmentRate(_ data: DashboardData) -> Double {
    guard data.totalStudents > 0 else { return 0.0 }
    return Double(data.plansAligned) / Double(data.totalStudents)
  }

  private func planEffectiveness(_ data: DashboardData) -> Double {
    // Calculate plan effectiveness based on plans vs students ratio and activity
    let planRatio = data.totalStudents > 0 ?
      Double(data.activeTMIPlans) / Double(data.totalStudents) : 0.0
    let activityBonus = data.recentActivities.count > 0 ? 0.15 : 0.0
    return min(1.0, planRatio * 0.8 + activityBonus)
  }

  // MARK: - AI Insights Integration
  
  @MainActor
  private func loadAIInsights(for data: DashboardData) async {
    guard !isLoadingInsights else { return }
    
    isLoadingInsights = true
    
    if #available(iOS 18.0, *) {
      let insights = await AIInsightsService.shared.generateInsights(from: data)
      aiInsights = insights
      print("[DashboardView] Loaded \(insights.count) AI insights")
    }
    
    isLoadingInsights = false
  }
  
  private func recommendations(_ data: DashboardData) -> [InsightRecommendation] {
    // Use AI-generated insights if available, fall back to rule-based
    if #available(iOS 18.0, *), !aiInsights.isEmpty {
      return convertAIInsights(aiInsights)
    } else {
      return generateBasicRecommendations(data)
    }
  }
  
  @available(iOS 18.0, *)
  private func convertAIInsights(_ insights: [AIInsight]) -> [InsightRecommendation] {
    return insights.prefix(3).map { insight in
      InsightRecommendation(
        title: insight.title,
        description: insight.description,
        icon: insight.category.icon,
        color: insight.priority.color
      )
    }
  }
  
  private func generateBasicRecommendations(_ data: DashboardData) -> [InsightRecommendation] {
    var recs: [InsightRecommendation] = []
    
    // Survey completion recommendations
    let completionRate = surveyCompletionRate(data)
    let alignmentRate = planAlignmentRate(data)
    
    if completionRate < 0.7 {
      let missingCount = data.totalStudents - data.surveysCompleted
      recs.append(InsightRecommendation(
        title: "Increase survey completion rate",
        description: "\(missingCount) students haven't completed their interest surveys. Consider sending reminder notifications.",
        icon: "bell.fill",
        color: .orange
      ))
    }
    
    // Plan alignment recommendations
    if alignmentRate < 0.6 {
      let unalignedCount = data.totalStudents - data.plansAligned
      recs.append(InsightRecommendation(
        title: "Improve plan alignment",
        description: "\(unalignedCount) students need aligned TMI plans. Schedule individual meetings to assess their needs.",
        icon: "person.2.fill",
        color: .blue
      ))
    }
    
    // Interest identification recommendations
    if data.interestsIdentified < data.totalStudents * 2 {
      recs.append(InsightRecommendation(
        title: "Expand interest exploration",
        description: "Students show limited interest diversity. Consider organizing career exploration workshops.",
        icon: "lightbulb.fill",
        color: .yellow
      ))
    }
    
    // Recent activity recommendations
    if data.recentActivities.count < 3 {
      recs.append(InsightRecommendation(
        title: "Boost student engagement",
        description: "Low recent activity detected. Plan interactive sessions to re-engage students.",
        icon: "chart.line.uptrend.xyaxis",
        color: .green
      ))
    }
    
    // Positive recommendations
    if completionRate > 0.8 && alignmentRate > 0.7 {
      recs.append(InsightRecommendation(
        title: "Excellent progress!",
        description: "High completion and alignment rates. Consider expanding to advanced tracking features.",
        icon: "star.fill",
        color: .teal
      ))
    }
    
    return Array(recs.prefix(3)) // Limit to 3 recommendations
  }

  private func generateDashboardReport(_ data: DashboardData) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .full
    dateFormatter.timeStyle = .none
    
    let report = """
    TMI Dashboard Report
    Generated: \(dateFormatter.string(from: Date()))
    
    PERFORMANCE OVERVIEW
    • Total Students: \(data.totalStudents)
    • Active TMI Plans: \(data.activeTMIPlans)
    • Surveys Completed: \(data.surveysCompleted)
    • Interests Identified: \(data.interestsIdentified)
    • Plans Aligned: \(data.plansAligned)
    
    KEY METRICS
    • Survey Completion Rate: \(Int(surveyCompletionRate(data) * 100))%
    • Plan Alignment Rate: \(Int(planAlignmentRate(data) * 100))%
    • Plan Effectiveness: \(Int(planEffectiveness(data) * 100))%
    
    RECENT ACTIVITIES (\(data.recentActivities.count))
    \(data.recentActivities.map { "• \($0.title): \($0.description)" }.joined(separator: "\n"))
    
    RECOMMENDATIONS
    \(recommendations(data).map { "• \($0.title): \($0.description)" }.joined(separator: "\n"))
    
    ---
    Report generated by TMI Education Platform
    """
    
    return report
  }
  
  // MARK: - Platform-Specific Actions
  
  private func exportDashboardReport(_ data: DashboardData) {
    let reportText = generateDashboardReport(data)
    
    #if os(iOS)
    let activityController = UIActivityViewController(
      activityItems: [reportText],
      applicationActivities: nil
    )
    
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first,
       let rootViewController = window.rootViewController {
      activityController.popoverPresentationController?.sourceView = window
      activityController.popoverPresentationController?.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
      rootViewController.present(activityController, animated: true)
    }
    #elseif os(macOS)
    // macOS sharing implementation
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(reportText, forType: .string)
    
    // Show a temporary notification that the report was copied
    // You could also open the save dialog here
    print("Dashboard report copied to clipboard")
    #endif
  }
  
  private func openCalendarApp() {
    #if os(iOS)
    if let calendarURL = URL(string: "calshow://") {
      if UIApplication.shared.canOpenURL(calendarURL) {
        UIApplication.shared.open(calendarURL)
      } else {
        // Fallback to default calendar URL
        if let fallbackURL = URL(string: "calendar://") {
          UIApplication.shared.open(fallbackURL)
        }
      }
    }
    #elseif os(macOS)
    // macOS Calendar app opening
    if let calendarURL = URL(string: "x-apple-calendar://") {
      NSWorkspace.shared.open(calendarURL)
    }
    #endif
  }
}

// MARK: - AI Insight Row

@available(iOS 18.0, *)
struct AIInsightRow: View {
  let insight: AIInsight
  @State private var isHovered = false
  
  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: insight.category.icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(insight.priority.color)
        .frame(width: 30, height: 30)
        .padding(4)
        .background(
          Circle()
            .fill(insight.priority.color.opacity(0.1))
        )
      
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(insight.title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
          
          Spacer()
          
          HStack(spacing: 4) {
            Image(systemName: insight.priority.icon)
              .font(.system(size: 10))
            
            Text(insight.priority.rawValue)
              .font(.caption2.weight(.medium))
          }
          .foregroundColor(insight.priority.color)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(
            Capsule()
              .fill(insight.priority.color.opacity(0.1))
          )
        }
        
        Text(insight.description)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.7))
          .lineLimit(isHovered ? nil : 2)
        
        if !insight.actionItems.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            Text("Action Items:")
              .font(.caption.weight(.medium))
              .foregroundColor(.white.opacity(0.8))
            
            ForEach(insight.actionItems.prefix(2), id: \.self) { actionItem in
              HStack(alignment: .top, spacing: 4) {
                Text("•")
                  .foregroundColor(insight.priority.color)
                Text(actionItem)
                  .font(.caption)
                  .foregroundColor(.white.opacity(0.6))
              }
            }
          }
          .padding(.top, 4)
        }
        
        if insight.confidence > 0 {
          HStack(spacing: 4) {
            Text("Confidence:")
              .font(.caption2)
              .foregroundColor(.white.opacity(0.5))
            
            Text("\(Int(insight.confidence * 100))%")
              .font(.caption2.weight(.medium))
              .foregroundColor(.white.opacity(0.7))
          }
          .padding(.top, 2)
        }
      }
      
      Spacer()
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
    .onHover { hovering in
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        isHovered = hovering
      }
    }
  }
}

// MARK: - Basic Recommendation Row (No Apply Button)

struct BasicRecommendationRow: View {
  let recommendation: InsightRecommendation
  @State private var isHovered = false
  
  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: recommendation.icon)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(recommendation.color)
        .frame(width: 30, height: 30)
        .padding(4)
        .background(
          Circle()
            .fill(recommendation.color.opacity(0.1))
        )
      
      VStack(alignment: .leading, spacing: 4) {
        Text(recommendation.title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
        
        Text(recommendation.description)
          .font(.system(size: 14))
          .foregroundColor(.white.opacity(0.7))
          .lineLimit(isHovered ? nil : 2)
      }
      
      Spacer()
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
    .onHover { hovering in
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        isHovered = hovering
      }
    }
  }
}

// MARK: - Preview

#Preview {
  DashboardView()
    .preferredColorScheme(.light)
}

#Preview {
  DashboardView()
    .preferredColorScheme(.dark)
}

// MARK: - All Activities View

struct AllActivitiesView: View {
  let activities: [RecentActivity]
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .dashboard)
          .ignoresSafeArea()
        
        ScrollView {
          LazyVStack(spacing: 16) {
            ForEach(activities) { activity in
              DashboardActivityRow(activity: activity)
                .padding(.horizontal, 20)
            }
            
            if activities.isEmpty {
              VStack(spacing: 16) {
                Image(systemName: "tray.fill")
                  .font(.system(size: 50))
                  .foregroundColor(.white.opacity(0.3))
                
                Text("No Recent Activities")
                  .font(.title2.bold())
                  .foregroundColor(.white)
                
                Text("Activities will appear here as you and your students interact with the TMI system.")
                  .font(.body)
                  .foregroundColor(.white.opacity(0.7))
                  .multilineTextAlignment(.center)
                  .padding(.horizontal, 40)
              }
              .frame(maxWidth: .infinity)
              .padding(.top, 100)
            }
          }
          .padding(.top, 20)
          .padding(.bottom, 40)
        }
      }
      .navigationTitle("All Activities")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
    .preferredColorScheme(.dark)
  }
}

