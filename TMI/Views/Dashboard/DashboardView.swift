//
//  DashboardViewRedesigned.swift
//  TMI
//
//  Simplified, purposeful dashboard with unified insight panel
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

struct DashboardView: View {
    @Environment(\.dashboardStateModel) var stateModel
    @State private var studentStateModel = StudentListStateModel()
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var showingAllActivities = false
    @State private var showingAddStudent = false

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            Group {
                switch stateModel.state {
                case .idle, .loading:
                    loadingView
                case .loaded(let data):
                    dashboardContent(data)
                case .error(let error):
                    errorView(error)
                }
            }
        }
        .task {
            await stateModel.fetch()
            await studentStateModel.fetch()
        }
        .refreshable {
            await stateModel.refresh()
            await studentStateModel.fetch()
        }
        .sheet(isPresented: $showingAddStudent) {
            NavigationStack {
                AddStudentViewRedesigned(onComplete: {
                    showingAddStudent = false
                    // Refresh dashboard and student data
                    Task {
                        await studentStateModel.fetch()
                        await stateModel.refresh()
                    }
                })
            }
        }
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: TMISpacing.lg) {
            ProgressView()
                .tint(.tmiPrimary)

            Text("Loading dashboard...")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
        }
    }

    // MARK: - Error State

    private func errorView(_ error: IdentifiableError) -> some View {
        TMIEmptyStateRedesigned(
            icon: "exclamationmark.triangle",
            title: "Unable to Load",
            message: error.message,
            action: {
                Task { await stateModel.fetch() }
            },
            actionLabel: "Try Again"
        )
    }

    // MARK: - Main Content

    @ViewBuilder
    private func dashboardContent(_ data: DashboardData) -> some View {
        ScrollView {
            VStack(spacing: TMISpacing.lg) {
                // Hero Section - Primary Insight
                primaryInsightCard(data)
                    .padding(.top, TMISpacing.md)

                // Quick Action Cards - NEW
                QuickActionsGrid()

                // Student Engagement Overview - NEW
                StudentStatusWidget()

                // Quick Stats Row
                quickStatsRow(data)

                // Engagement Chart (Simplified)
                if !data.engagementData.isEmpty {
                    engagementChart(data)
                }

                // Recent Activity Preview
                recentActivitySection(data)

                Spacer(minLength: TMISpacing.xxl)
            }
            .padding(.horizontal, TMISpacing.screenPadding)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    TMIAvatar(initials: "ED", color: .tmiPrimary, size: 36)
                }
            }
        }
        .sheet(isPresented: $showingAllActivities) {
            NavigationStack {
                allActivitiesView(data)
            }
        }
    }

    // MARK: - Primary Insight Card

    private func primaryInsightCard(_ data: DashboardData) -> some View {
        let surveysPending = max(0, data.totalStudents - data.surveysCompleted)
        let plansPending = max(0, data.totalStudents - data.plansAligned)
        let attentionCount = studentsNeedingAttention(data) ?? 0
        let status = computeDashboardStatus(data: data, attentionCount: attentionCount, surveysPending: surveysPending, plansPending: plansPending)

        return VStack(alignment: .leading, spacing: TMISpacing.md) {
            // Header: Status + Totals
            HStack(alignment: .center, spacing: TMISpacing.md) {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: status.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(status.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    // "6 Students  •  4 Ready to Grow"
                    HStack(spacing: 8) {
                        Text("\(data.totalStudents) Students")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.tmiTextPrimary)
                        Text("•")
                            .foregroundColor(.tmiTextTertiary)
                        Text("\(max(attentionCount, surveysPending + plansPending)) Ready to Grow")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.tmiWarning)
                    }

                    // Contextual status microcopy
                    Text(status.title)
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()
            }

            TMIDivider()

            // Priority Actions
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.tmiWarning)
                    Text("Priority Actions")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if surveysPending > 0 {
                        Button(action: { onTapStartSurveys() }) {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: "chart.bar")
                                    .foregroundColor(.tmiPrimary)
                                Text("\(surveysPending) students need survey completion")
                                    .font(.tmiBody)
                                    .foregroundColor(.tmiTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.tmiPrimary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if plansPending > 0 {
                        Button(action: { onTapAssignPlans() }) {
                            HStack(alignment: .center, spacing: 8) {
                                Image(systemName: "target")
                                    .foregroundColor(.tmiSecondary)
                                Text("\(plansPending) students waiting for plan assignment")
                                    .font(.tmiBody)
                                    .foregroundColor(.tmiTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.tmiSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    if surveysPending == 0 && plansPending == 0 {
                        Text("Great work—everyone has a personalized pathway!")
                            .font(.tmiCaption)
                            .foregroundColor(.tmiSuccess)
                    }
                }
            }

            TMIDivider()

            // Supporting Metrics (clickable + clarified)
            HStack(spacing: TMISpacing.lg) {
                metricPill(
                    icon: "doc.badge.checkmark",
                    tint: .tmiSuccess,
                    value: "\(data.activeTMIPlans)",
                    label: "Personalized Pathways"
                ) { onTapPlans() }

                metricPill(
                    icon: "chart.bar.fill",
                    tint: .tmiPrimary,
                    value: "\(data.surveysCompleted)/\(data.totalStudents)",
                    label: surveysPending > 0 ? "Let's discover their interests!" : "All surveys complete"
                ) { onTapStartSurveys() }

                metricPill(
                    icon: "checkmark.seal.fill",
                    tint: .tmiSecondary,
                    value: "\(data.plansAligned)",
                    label: "Aligned with goals"
                ) { onTapAssignPlans() }
            }
        }
        .tmiCard(style: .elevated)
    }

    // Helper function to calculate students needing attention
    private func studentsNeedingAttention(_ data: DashboardData) -> Int? {
        // Count students with engagement < 0.4 (needs support level)
        let needsSupport = studentStateModel.students.filter { $0.engagementScore < 0.4 }.count
        return needsSupport > 0 ? needsSupport : nil
    }

    private func supportingStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            Text(label)
                .font(.tmiFootnote)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum DashboardStatus {
        case onTrack, actionNeeded, growing, needsSupport

        var title: String {
            switch self {
            case .onTrack: return "🎯 On Track — surveys complete and plans active"
            case .actionNeeded: return "⚡ Action Needed — missing surveys or unassigned pathways"
            case .growing: return "🌱 Growing — progress improving"
            case .needsSupport: return "🚨 Needs Support — multiple students at risk"
            }
        }

        var icon: String {
            switch self {
            case .onTrack: return "checkmark.seal.fill"
            case .actionNeeded: return "bolt.fill"
            case .growing: return "leaf.fill"
            case .needsSupport: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .onTrack: return .tmiSuccess
            case .actionNeeded: return .tmiWarning
            case .growing: return .tmiPrimary
            case .needsSupport: return .tmiError
            }
        }
    }

    private func computeDashboardStatus(data: DashboardData, attentionCount: Int, surveysPending: Int, plansPending: Int) -> (status: DashboardStatus, title: String, icon: String, color: Color) {
        // Determine status based on urgency signals
        if attentionCount >= 2 {
            return (.needsSupport, DashboardStatus.needsSupport.title, DashboardStatus.needsSupport.icon, DashboardStatus.needsSupport.color)
        }
        if surveysPending > 0 || plansPending > 0 {
            return (.actionNeeded, DashboardStatus.actionNeeded.title, DashboardStatus.actionNeeded.icon, DashboardStatus.actionNeeded.color)
        }
        // If engagement is trending up or plans exist but not all, call it growing
        if data.activeTMIPlans > 0 && (data.activeTMIPlans < data.totalStudents) {
            return (.growing, DashboardStatus.growing.title, DashboardStatus.growing.icon, DashboardStatus.growing.color)
        }
        return (.onTrack, DashboardStatus.onTrack.title, DashboardStatus.onTrack.icon, DashboardStatus.onTrack.color)
    }

    @ViewBuilder
    private func metricPill(icon: String, tint: Color, value: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tint.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(tint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)
                    Text(label)
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Placeholder actions to make the card actionable.
    // In a future iteration, wire these to navigation or filters in your app.
    private func onTapStartSurveys() {
        // For now, show all activities as a proxy action.
        showingAllActivities = true
    }

    private func onTapAssignPlans() {
        // For now, show the add student flow as a proxy to plan assignment.
        showingAddStudent = true
    }

    private func onTapPlans() {
        // Navigate to plans list when available; using activities for now.
        showingAllActivities = true
    }

    // MARK: - Quick Stats Row

    private func quickStatsRow(_ data: DashboardData) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TMISpacing.md) {
                TMIStatChip(
                    value: "\(data.surveysCompleted)",
                    label: "Surveys Done",
                    color: .tmiSuccess
                )

                TMIStatChip(
                    value: "\(Int(planAlignmentRate(data) * 100))%",
                    label: "Plan Alignment",
                    trend: planAlignmentRate(data) > 0.7 ? .up : .neutral,
                    color: .tmiPrimary
                )

                TMIStatChip(
                    value: "\(data.interestsIdentified)",
                    label: "Interests Found",
                    color: .tmiSecondary
                )
            }
        }
    }

    // MARK: - Engagement Chart

    private func engagementChart(_ data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Weekly Engagement")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            Chart(data.engagementData) { item in
                LineMark(
                    x: .value("Week", item.week),
                    y: .value("Level", item.engagementLevel)
                )
                .foregroundStyle(Color.tmiPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                AreaMark(
                    x: .value("Week", item.week),
                    y: .value("Level", item.engagementLevel)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.tmiPrimary.opacity(0.2), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.tmiTextSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.tmiTextSecondary)
                }
            }
        }
        .tmiCard()
    }

    // MARK: - Recent Activity Section

    private func recentActivitySection(_ data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                Spacer()

                if !data.recentActivities.isEmpty {
                    Button(action: { showingAllActivities = true }) {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(.tmiCaption)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.tmiPrimary)
                    }
                }
            }

            if data.recentActivities.isEmpty {
                emptyActivityState
            } else {
                VStack(spacing: 0) {
                    ForEach(data.recentActivities.prefix(3)) { activity in
                        activityRow(activity)

                        if activity.id != data.recentActivities.prefix(3).last?.id {
                            TMIDivider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
        .tmiCard()
    }

    private func activityRow(_ activity: RecentActivity) -> some View {
        HStack(spacing: TMISpacing.md) {
            ZStack {
                Circle()
                    .fill(activity.iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: activity.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(activity.iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextPrimary)

                Text(activity.description)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(activity.timeAgo)
                .font(.tmiFootnote)
                .foregroundColor(.tmiTextTertiary)
        }
        .padding(.vertical, TMISpacing.sm)
    }

    private var emptyActivityState: some View {
        VStack(spacing: TMISpacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(.tmiTextTertiary)

            Text("No recent activity")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.xl)
    }

    // MARK: - All Activities Sheet

    private func allActivitiesView(_ data: DashboardData) -> some View {
        List(data.recentActivities) { activity in
            TMIListRow(
                title: activity.title,
                subtitle: activity.description,
                leading: {
                    ZStack {
                        Circle()
                            .fill(activity.iconColor.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: activity.icon)
                            .font(.system(size: 16))
                            .foregroundColor(activity.iconColor)
                    }
                },
                trailing: {
                    Text(activity.timeAgo)
                        .font(.tmiFootnote)
                        .foregroundColor(.tmiTextTertiary)
                }
            )
            .listRowBackground(Color.tmiBackground)
        }
        .listStyle(.plain)
        .background(Color.tmiBackground)
        .navigationTitle("All Activities")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    showingAllActivities = false
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func surveyCompletionRate(_ data: DashboardData) -> Double {
        guard data.totalStudents > 0 else { return 0.0 }
        return Double(data.surveysCompleted) / Double(data.totalStudents)
    }

    private func planAlignmentRate(_ data: DashboardData) -> Double {
        guard data.totalStudents > 0 else { return 0.0 }
        return Double(data.plansAligned) / Double(data.totalStudents)
    }

    private func calculateTrend(_ data: DashboardData) -> (icon: String, value: String, label: String, color: Color)? {
        guard !data.engagementData.isEmpty, data.engagementData.count >= 2 else { return nil }

        let recent = data.engagementData.suffix(2)
        let change = recent.last!.engagementLevel - recent.first!.engagementLevel

        if abs(change) < 1 {
            return ("minus", "0", "No change", .tmiTextSecondary)
        } else if change > 0 {
            return ("arrow.up.right", "+\(Int(change))", "vs last week", .tmiSuccess)
        } else {
            return ("arrow.down.right", "\(Int(change))", "vs last week", .tmiError)
        }
    }
}

#Preview("Light Mode") {
    NavigationStack {
        DashboardView()
            .environment(\.dashboardStateModel, DashboardStateModel())
    }
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    NavigationStack {
        DashboardView()
            .environment(\.dashboardStateModel, DashboardStateModel())
    }
    .preferredColorScheme(.dark)
}

