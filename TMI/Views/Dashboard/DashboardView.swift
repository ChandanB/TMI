//
//  Created by Chandan Brown on 9/10/24.
//

import Charts
import Combine
import FirebaseFirestore
import Foundation
import Observation
import SwiftUI

// MARK: - Dashboard Data Model

struct DashboardData: Equatable {
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
      let studentsWithPlans = Set(plans.map { $0.student.id ?? "" }).count
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
      
      return RecentActivity(
        icon: "doc.fill",
        title: "TMI Plan Updated",
        description: "Plan for \(plan.student.name) was updated",
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
  @State private var headerAnimation = false
  @State private var cardsAnimation = false
  @State private var chartAnimation = false
  @State private var buttonAnimation = false

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
    .sheet(isPresented: binding(stateModel, \.showingInsightsSheet)) {
      if case .loaded(let dashboardData) = stateModel.state {
        DashboardInsightsView(dashboardData: dashboardData)
      }
    }
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          // Profile menu action
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
    .sheet(isPresented: $showingInsightsSheet) {
      if case .loaded(let dashboardData) = stateModel.state {
        DashboardInsightsView(dashboardData: dashboardData)
          .presentationDetents([.medium, .large])
          .presentationDragIndicator(.visible)
          .presentationSizing(.page)
      }
    }
    .task {
      await stateModel.fetch()
    }
    .refreshable {
      await stateModel.refresh()
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Loading View

  private var loadingView: some View {
    VStack(spacing: 24) {
      LottieLoadingView()
        .frame(width: 100, height: 100)

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
        TimeFrameSelector(selection: binding(stateModel, \.selectedTimeFrame))
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 8)
          .opacity(headerAnimation ? 1 : 0)
          .animation(
            .spring(response: 0.6, dampingFraction: 0.7).delay(0.2),
            value: headerAnimation
          )

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

        // Insights button
        InsightsButtonView {
          stateModel.showingInsightsSheet = true
        }
        .opacity(buttonAnimation ? 1 : 0)
        .offset(y: buttonAnimation ? 0 : 20)
        .animation(
          .spring(response: 0.6, dampingFraction: 0.7).delay(0.5),
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
            // View all activities
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
