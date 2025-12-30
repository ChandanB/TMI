//
//  DashboardView.swift
//  TMI
//
//  Simplified, purposeful dashboard with unified insight panel.
//  Now uses shared caches from AppBootstrapService and shows next best action.
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
  
  // Next Best Action
  var nextBestAction: NextBestAction?
}

// MARK: - Next Best Action

struct NextBestAction: Equatable, Sendable {
  let id: String
  let type: ActionType
  let title: String
  let description: String
  let priority: ActionPriority
  let targetStudentId: String?
  let targetPlanId: String?
  
  enum ActionType: String, Sendable {
    case createPlan = "create_plan"
    case reviewPlan = "review_plan"
    case scheduleMeeting = "schedule_meeting"
    case completeNotes = "complete_notes"
    case addInterests = "add_interests"
    case checkProgress = "check_progress"
    case pendingApproval = "pending_approval"
  }
  
  enum ActionPriority: Int, Sendable, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3
    
    static func < (lhs: ActionPriority, rhs: ActionPriority) -> Bool {
      lhs.rawValue < rhs.rawValue
    }
  }
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
  private let tmiPlanService = TMIPlanService.shared

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
      // Calculate total interests identified asynchronously
      
      // Use ThrowingTaskGroup for parallel fetching of interest counts
      let interestsIdentified: Int = try await withThrowingTaskGroup(of: Int.self) { group in
          for student in students {
              group.addTask {
                  try await student.getInterestCount()
              }
          }

          var total = 0
          for try await count in group {
              total += count
          }
          return total
      }
      
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

// MARK: - DashboardActivityRow moved to Components/DashboardActivityRow.swift

// TODO: Add `HelpTooltipButton` to other sections (Hero Card, Student Engagement, Insights, etc.) as needed.
struct DashboardView: View {
    @Environment(\.dashboardStateModel) var stateModel
    @State private var studentStateModel = StudentListStateModel()
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var showingAllActivities = false
    @State private var showingAddStudent = false
    @State private var navigateToStudents = false
    @State private var navigateToPlans = false
    @State private var navigateToSurveys = false

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .dashboard)
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
                AddStudentView(onComplete: {
                    showingAddStudent = false
                    // Refresh dashboard and student data
                    Task {
                        await studentStateModel.fetch()
                        await stateModel.refresh()
                    }
                })
            }
        }
        .navigationDestination(isPresented: $navigateToStudents) {
            StudentListView()
        }
        .navigationDestination(isPresented: $navigateToPlans) {
            TMIPlanListView()
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
        TMIEmptyState(
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
                // Recent Activity Preview
                recentActivitySection(data)
                
                // Quick Action Cards 
                QuickActionsGrid()
                
                // Hero Section - Primary Insight
                // Hero Section - Primary Insight
                DashboardHeaderView(
                    data: data,
                    attentionCount: studentsNeedingAttention(data) ?? 0,
                    onNavigateToStudents: { navigateToStudents = true },
                    onNavigateToPlans: { navigateToPlans = true }
                )
                    .padding(.top, TMISpacing.md)

                // Quick Stats Row
                DashboardStatsView(
                    data: data,
                    onNavigateToStudents: { navigateToStudents = true },
                    onNavigateToPlans: { navigateToPlans = true }
                )
                
                // Actionable Lists Section
                if studentsNeedingAttention(data) != nil || (data.totalStudents - data.surveysCompleted) > 0 {
                    VStack(spacing: TMISpacing.lg) {
                        // Students Ready to Grow
                        if let readyToGrowCount = studentsNeedingAttention(data), readyToGrowCount > 0 {
                            StudentsReadyToGrowCard(count: readyToGrowCount) {
                                navigateToStudents = true
                            }
                        }
                        
                        // Surveys Pending
                        if (data.totalStudents - data.surveysCompleted) > 0 {
                            SurveysPendingCard(count: data.totalStudents - data.surveysCompleted) {
                                navigateToStudents = true
                            }
                        }
                    }
                }

                // Engagement Chart (Simplified)
                if !data.engagementData.isEmpty {
                    DashboardEngagementChart(data: data.engagementData)
                }
                
                // Student Engagement Overview - NEW
                StudentStatusWidget()

                Spacer(minLength: TMISpacing.xxl)
            }
            .padding(.horizontal, TMISpacing.screenPadding)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: SettingsView()) {
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

    // MARK: - Quick Stats Row

    // MARK: - Quick Stats Row moved to Components/DashboardStatsView.swift

    // MARK: - Engagement Chart moved to Components/DashboardEngagementChart.swift

    // MARK: - Primary Insight Card

    // MARK: - Primary Insight Card moved to Components/DashboardHeaderView.swift



    // MARK: - Recent Activity Section

    private func recentActivitySection(_ data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)
                HelpTooltipButton(message: "See the most recent student activity, surveys, and plan updates from the last few days.")
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



    // Helper function to calculate students needing attention
    private func studentsNeedingAttention(_ data: DashboardData) -> Int? {
        // Count students with engagement < 0.4 (needs support level)
        let needsSupport = studentStateModel.students.filter { $0.engagementScore < 0.4 }.count
        return needsSupport > 0 ? needsSupport : nil
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

// MARK: - Actionable Cards moved to Components/ActionableCards.swift


