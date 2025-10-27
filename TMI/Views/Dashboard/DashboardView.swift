//
//  DashboardView.swift
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

// MARK: - Help Tooltip Button
struct HelpTooltipButton: View {
    let message: String
    @State private var showTooltip = false

    var body: some View {
        ZStack(alignment: .top) {
            Button(action: { withAnimation { showTooltip.toggle() } }) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.tmiPrimary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                #if os(macOS)
                withAnimation { showTooltip = hovering }
                #endif
            }

            if showTooltip {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.85))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.tmiPrimary.opacity(0.7), lineWidth: 1)
                    )
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 220)
                    .offset(y: 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .zIndex(99)
            }
        }
        .padding(.leading, 2)
    }
}

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

// MARK: - Priority Action Button Component

struct PriorityActionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            TMIHaptics.lightImpact()
            action()
        }) {
            HStack(spacing: TMISpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.tmiTextPrimary)

                    Text("\(count) student\(count == 1 ? "" : "s") waiting")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            .padding(TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(Color.tmiBackground)
                    .shadow(color: .black.opacity(isPressed ? 0.05 : 0.1), radius: isPressed ? 4 : 8, x: 0, y: isPressed ? 2 : 4)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }
}

// MARK: - Metric Pill Component

struct MetricPill: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String
    let subtitle: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            TMIHaptics.lightImpact()
            action()
        }) {
            HStack(spacing: TMISpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tint.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(tint)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(value)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.tmiTextPrimary)

                        Text(label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.tmiTextSecondary)
                    }

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tmiTextTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint.opacity(isHovered ? 1.0 : 0.5))
                    .offset(x: isHovered ? 2 : 0)
            }
            .padding(TMISpacing.md)
            .background(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(isHovered ? tint.opacity(0.05) : Color.tmiBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .strokeBorder(tint.opacity(isHovered ? 0.3 : 0.15), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
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
                primaryInsightCard(data)
                    .padding(.top, TMISpacing.md)

                // Quick Stats Row
//                quickStatsRow(data)

                // Engagement Chart (Simplified)
//                if !data.engagementData.isEmpty {
//                    engagementChart(data)
//                }
                
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

        return VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Header: Status + Totals with enhanced visual hierarchy
            HStack(alignment: .center, spacing: TMISpacing.md) {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Circle()
                        .stroke(status.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 52, height: 52)

                    Image(systemName: status.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(status.color)
                        .symbolEffect(.pulse, options: .repeating, value: status.status == .needsSupport || status.status == .actionNeeded)
                }
                .shadow(color: status.color.opacity(0.2), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    // Enhanced student count display
                    HStack(spacing: 10) {
                        Text("\(data.totalStudents)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.tmiTextPrimary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Students")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.tmiTextSecondary)

                            if max(attentionCount, surveysPending + plansPending) > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.tmiWarning)
                                    Text("\(max(attentionCount, surveysPending + plansPending)) Ready to Grow")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.tmiWarning)
                                }
                            }
                        }
                    }

                    // Enhanced status message with emoji
                    Text(status.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.tmiTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.bottom, 4)

            TMIDivider()

            // Priority Actions with enhanced interactivity
            if surveysPending > 0 || plansPending > 0 {
                VStack(alignment: .leading, spacing: TMISpacing.md) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.tmiWarning)
                        Text("Priority Actions")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.tmiTextSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    VStack(alignment: .leading, spacing: TMISpacing.sm) {
                        if surveysPending > 0 {
                            PriorityActionButton(
                                icon: "chart.bar.doc.horizontal",
                                iconColor: .tmiPrimary,
                                title: "Complete Interest Surveys",
                                count: surveysPending,
                                action: { onTapStartSurveys() }
                            )
                        }

                        if plansPending > 0 {
                            PriorityActionButton(
                                icon: "target",
                                iconColor: .tmiSecondary,
                                title: "Assign TMI Plans",
                                count: plansPending,
                                action: { onTapAssignPlans() }
                            )
                        }
                    }
                }

                TMIDivider()
            } else {
                // Success state with celebration
                HStack(spacing: TMISpacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.tmiSuccess.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.tmiSuccess)
                            .symbolEffect(.bounce, options: .repeating.speed(0.5))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Excellent Progress!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.tmiSuccess)

                        Text("All students have personalized pathways and surveys completed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.tmiTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(TMISpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.md)
                        .fill(Color.tmiSuccess.opacity(0.08))
                )

                TMIDivider()
            }

            // Supporting Metrics with enhanced design
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                Text("Key Metrics")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.tmiTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                VStack(spacing: TMISpacing.sm) {
                    MetricPill(
                        icon: "doc.text.fill",
                        tint: .tmiSuccess,
                        value: "\(data.activeTMIPlans)",
                        label: "Active TMI Plans",
                        subtitle: data.totalStudents > 0 ? "\(Int(Double(data.activeTMIPlans) / Double(data.totalStudents) * 100))% coverage" : "No students yet",
                        action: { onTapPlans() }
                    )

                    MetricPill(
                        icon: "chart.bar.fill",
                        tint: .tmiPrimary,
                        value: "\(data.surveysCompleted)/\(data.totalStudents)",
                        label: "Surveys Completed",
                        subtitle: surveysPending > 0 ? "\(surveysPending) remaining" : "All complete!",
                        action: { navigateToStudents = true }
                    )

                    MetricPill(
                        icon: "checkmark.seal.fill",
                        tint: .tmiSecondary,
                        value: "\(data.plansAligned)",
                        label: "Plans Aligned with Goals",
                        subtitle: data.totalStudents > 0 ? "\(Int(Double(data.plansAligned) / Double(data.totalStudents) * 100))% aligned" : "Ready to start",
                        action: { navigateToPlans = true }
                    )
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.tmiSurface)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
                .shadow(color: status.color.opacity(0.1), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(
                    LinearGradient(
                        colors: [status.color.opacity(0.2), status.color.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
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
        // Determine status based on urgency signals with improved logic
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

    // Navigation actions for dashboard buttons
    private func onTapStartSurveys() {
        navigateToStudents = true
    }

    private func onTapAssignPlans() {
        navigateToStudents = true
    }

    private func onTapPlans() {
        navigateToPlans = true
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

