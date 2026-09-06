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

nonisolated enum MVPEmptyStateCopy {
  static let dashboardActivityTitle = "Roster activity will appear here"
  static let dashboardActivityMessage = "Add a student to begin your secure district roster."
  static let dashboardActivityAction = "Open Students"

  static let studentInterestsTitle = "Discover what motivates this student"
  static let studentInterestsMessage = "Run the interest survey or add a few interests so you can build a plan from real student signals."
  static let studentInterestsAction = "Take Survey"

  static let studentPlansTitle = "Turn interests into a support plan"
  static let studentPlansMessage = "Create the first TMI plan so the team has a concrete next step to review and track."
  static let studentPlansAction = "Create First Plan"

  static let studentMeetingsTitle = "Keep the core loop moving"
  static let studentMeetingsMessage = "Schedule a check-in once the plan is underway so the team can review progress and adjust support."
  static let studentMeetingsAction = "Schedule Meeting"

  static let districtPilotTitle = "Pilot data will appear here"
  static let districtPilotMessage = "Ask each school team to add students, capture interests, and launch plans so district proof points roll up here."
  static let districtFollowUpTitle = "No follow-up signals yet"
  static let districtFollowUpMessage = "Have schools add students, capture interests, and create plans before district follow-up trends appear."
  static let districtInsightsTitle = "Insights unlock after schools use the core loop"
  static let districtInsightsMessage = "Once schools add students, run surveys, and launch plans, this view will summarize adoption and engagement patterns."
  static let districtSchoolsTitle = "School comparisons start with school-level activity"
  static let districtSchoolsMessage = "When schools begin adding students and launching plans, their engagement and follow-up trends will appear here."
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
  
  // Next Best Action
  var nextBestAction: NextBestAction?
  
  // Role-specific data
  var roleData: RoleSpecificData?
}

// MARK: - Role-Specific Data

struct RoleSpecificData: Equatable, Sendable {
  var role: StaffRole
  
  // Counselor-specific
  var caseloadCount: Int = 0
  var pendingApprovals: Int = 0
  var upcomingMeetings: Int = 0
  var criticalAlerts: Int = 0
  var caseloadStudentIds: [String] = []
  
  // Teacher-specific
  var classroomStudentCount: Int = 0
  var classroomPlansActive: Int = 0
  var classroomSurveysPending: Int = 0
  var classroomAttentionCount: Int = 0
  var classroomPlanGapCount: Int = 0
  var classroomStudentIds: [String] = []
  
  // Admin-specific
  var schoolWideStudents: Int = 0
  var schoolWidePlans: Int = 0
  var staffCount: Int = 0
}

// MARK: - Next Best Action

nonisolated struct NextBestAction: Equatable, Sendable {
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
  private let studentRepository: any StudentRepository
  private let planRepository: (any PlanRecordRepository)?

  // MARK: - Cancellables
  private var cancellables = Set<AnyCancellable>()

  // MARK: - Initialization
  init(
    studentRepository: any StudentRepository = CanonicalStudentRepository.firebase(),
    planRepository: (any PlanRecordRepository)? = nil
  ) {
    self.studentRepository = studentRepository
    self.planRepository = planRepository
    super.init()

    // Initialize UI state
    ui.set("selectedTimeFrame", value: TimeFrame.week)
    ui.set("selectedDataPoint", value: nil as AlignmentData?)
    ui.set("showingInsightsSheet", value: false)
  }

  isolated deinit {
    cancellables.forEach { $0.cancel() }
  }

  // MARK: - Data Fetching

  @MainActor
  override func fetch() async {
    await fetchWithMembership(nil)
  }
  
  @MainActor
  func fetchWithMembership(_ membership: MembershipContext?) async {
    updateState(.loading)

    do {
      guard let membership else {
        throw StudentRepositoryError.permissionDenied
      }

      // Roster counts come from the canonical district repository.
      let students = try await fetchCanonicalStudents(member: membership)

      // Plan metrics come from the canonical plan repository. A plan-fetch
      // failure must not blank the whole dashboard, so it is non-fatal.
      let planRecords: [PlanRecord]
      if let planRepository {
        planRecords = (try? await planRepository.plans(member: membership)) ?? []
      } else {
        planRecords = []
      }

      let totalStudents = students.count
      let activeTMIPlans = planRecords.filter {
        $0.status == .active && $0.approvalStatus == .approved
      }.count
      let studentsWithPlans = Set(
        planRecords.filter { $0.status.isOpen }.flatMap { $0.studentIDs }
      ).count
      let recentActivities = canonicalRecentActivities(
        students: students,
        planRecords: planRecords
      )
      let roleData = canonicalRoleData(
        membership: membership,
        students: students,
        planRecords: planRecords
      )
      let nextAction = Self.approvalAction(
        forPending: planRecords.filter { $0.status == .pendingApproval }
      )

      let dashboardData = DashboardData(
        engagementData: [],
        totalStudents: totalStudents,
        activeTMIPlans: activeTMIPlans,
        interestsIdentified: 0,
        surveysCompleted: 0,
        plansAligned: studentsWithPlans,
        recentActivities: recentActivities,
        nextBestAction: nextAction,
        roleData: roleData
      )

      updateState(.loaded(dashboardData))
    } catch is CancellationError {
      return
    } catch {
      print("[DashboardStateModel] Error fetching dashboard data: \(error)")
      handleError(error, userFriendlyMessage: "Failed to load dashboard data")
    }
  }

  private func fetchCanonicalStudents(
    member: MembershipContext
  ) async throws -> [StudentRecord] {
    let schoolScopes: [String?]
    if member.role == .districtAdministrator {
      schoolScopes = [nil]
    } else {
      guard !member.schoolIDs.isEmpty else {
        throw StudentRepositoryError.schoolFilterRequired
      }
      schoolScopes = member.schoolIDs.sorted().map(Optional.some)
    }

    var recordsByID: [String: StudentRecord] = [:]
    for schoolID in schoolScopes {
      var request = StudentPageRequest(
        schoolID: schoolID,
        status: .active
      )
      repeat {
        let page = try await studentRepository.page(request, member: member)
        for record in page.records {
          recordsByID[record.id] = record
        }
        request.cursor = page.nextCursor
      } while request.cursor != nil
    }
    return recordsByID.values.sorted {
      $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
    }
  }

  private func canonicalRoleData(
    membership: MembershipContext,
    students: [StudentRecord],
    planRecords: [PlanRecord]
  ) -> RoleSpecificData {
    var result = RoleSpecificData(role: membership.role)
    switch membership.role {
    case .counselor, .socialWorker:
      result.caseloadCount = students.count
      result.pendingApprovals = planRecords.filter {
        $0.status == .pendingApproval
      }.count
      result.caseloadStudentIds = students.map(\.id)
    case .teacher:
      result.classroomStudentCount = students.count
      result.classroomPlansActive = planRecords.filter {
        $0.status == .active && $0.approvalStatus == .approved
      }.count
      result.classroomStudentIds = students.map(\.id)
    case .schoolAdministrator, .districtAdministrator:
      result.schoolWideStudents = students.count
      result.schoolWidePlans = planRecords.count
    }
    return result
  }

  // MARK: - Canonical Recent Activity

  private func canonicalRecentActivities(
    students: [StudentRecord],
    planRecords: [PlanRecord]
  ) -> [RecentActivity] {
    let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
    let namesByID = Dictionary(
      uniqueKeysWithValues: students.map { ($0.id, $0.displayName) }
    )

    let planActivities = planRecords.compactMap { plan -> RecentActivity? in
      guard plan.metadata.updatedAt > sevenDaysAgo else { return nil }

      let names = plan.studentIDs.compactMap { namesByID[$0] }
      let description: String
      if names.count == 1 {
        description = "Plan '\(plan.title)' for \(names[0]) was updated"
      } else if !names.isEmpty {
        description = "Plan '\(plan.title)' for \(names.count) students was updated"
      } else {
        description = "Plan '\(plan.title)' for \(plan.studentIDs.count) students was updated"
      }

      return RecentActivity(
        icon: "doc.fill",
        title: "TMI Plan Updated",
        description: description,
        date: plan.metadata.updatedAt,
        iconColor: .blue
      )
    }

    let studentActivities = students.compactMap { student -> RecentActivity? in
      guard student.metadata.createdAt > sevenDaysAgo else { return nil }

      return RecentActivity(
        icon: "person.crop.circle.badge.plus",
        title: "Student Added",
        description: "\(student.displayName) was added",
        date: student.metadata.createdAt,
        iconColor: .green
      )
    }

    return (planActivities + studentActivities)
      .sorted { $0.date > $1.date }
      .prefix(10)
      .map { $0 }
  }
  
  // MARK: - Role-Specific Data Generation
  
  private func generateRoleSpecificData(role: StaffRole, students: [Student], plans: [TMIPlan]) -> RoleSpecificData {
    var roleData = RoleSpecificData(role: role)
    
    switch role {
    case .counselor:
      // MVP: Show all students as caseload (filtering by assigned counselor is post-MVP)
      roleData.caseloadCount = students.count
      roleData.pendingApprovals = plans.filter { $0.approvalStatus == .pendingApproval }.count
      roleData.upcomingMeetings = 0
      roleData.criticalAlerts = students.filter { $0.engagementScore < 0.3 }.count
      roleData.caseloadStudentIds = students.compactMap { $0.id }
      
    case .teacher:
      // MVP: Show all students (classroom filtering is post-MVP)
      roleData.classroomStudentCount = students.count
      roleData.classroomPlansActive = plans.filter { $0.approvalStatus == .approved }.count
      roleData.classroomSurveysPending = students.filter { $0.surveyResults?.isEmpty ?? true }.count
      roleData.classroomAttentionCount = Self.urgentAttentionStudents(in: students).count
      roleData.classroomPlanGapCount = Self.studentsMissingPlans(students: students, plans: plans).count
      roleData.classroomStudentIds = students.compactMap { $0.id }
      
    case .schoolAdministrator, .districtAdministrator:
      // MVP: Show all students and plans in single-teacher context
      roleData.schoolWideStudents = students.count
      roleData.schoolWidePlans = plans.count
      roleData.staffCount = 0
      
    case .socialWorker:
      // Social worker sees referred students with behavioral plans
      roleData.caseloadCount = students.count
      roleData.criticalAlerts = students.filter { $0.engagementScore < 0.3 }.count
      
    }
    
    return roleData
  }
  
  // MARK: - Next Best Action Generation
  
  nonisolated static func prioritizedNextBestAction(
    membership: MembershipContext?,
    students: [Student],
    plans: [TMIPlan]
  ) -> NextBestAction? {
    let pendingPlans = plans.filter { $0.approvalStatus == .pendingApproval }
    let canReviewApprovals = membership?.capabilities.contains(.planApprove) == true

    let candidates: [NextBestAction] = [
      canReviewApprovals ? approvalAction(for: pendingPlans) : nil,
      lowEngagementAction(for: students),
      missingPlanAction(for: students, plans: plans),
      surveyFollowUpAction(for: students, role: membership?.role)
    ]
    .compactMap { $0 }

    return candidates.max { lhs, rhs in
      lhs.priority < rhs.priority
    }
  }

  private nonisolated static func urgentAttentionStudents(in students: [Student]) -> [Student] {
    students.filter { $0.engagementScore < 0.3 }
  }

  private nonisolated static func studentsMissingPlans(students: [Student], plans: [TMIPlan]) -> [Student] {
    let studentsWithPlanIds = Set(plans.flatMap { $0.students.compactMap(\.id) })

    return students.filter {
      guard let studentId = $0.id else { return false }
      return !studentsWithPlanIds.contains(studentId) && !($0.surveyResults?.isEmpty ?? true)
    }
  }

  private nonisolated static func approvalAction(for pendingPlans: [TMIPlan]) -> NextBestAction? {
    guard !pendingPlans.isEmpty else { return nil }

    return NextBestAction(
      id: "pending_approval",
      type: .pendingApproval,
      title: "Plans Awaiting Approval",
      description: "\(pendingPlans.count) plan\(pendingPlans.count == 1 ? "" : "s") need your review",
      priority: .urgent,
      targetStudentId: nil,
      targetPlanId: pendingPlans.first?.id
    )
  }

  private nonisolated static func approvalAction(
    forPending pendingPlanRecords: [PlanRecord]
  ) -> NextBestAction? {
    guard !pendingPlanRecords.isEmpty else { return nil }

    return NextBestAction(
      id: "pending_approval",
      type: .pendingApproval,
      title: "Plans Awaiting Approval",
      description: "\(pendingPlanRecords.count) plan\(pendingPlanRecords.count == 1 ? "" : "s") need your review",
      priority: .urgent,
      targetStudentId: nil,
      targetPlanId: pendingPlanRecords.first?.id
    )
  }

  private nonisolated static func lowEngagementAction(for students: [Student]) -> NextBestAction? {
    guard let firstStudent = urgentAttentionStudents(in: students).first else { return nil }

    return NextBestAction(
      id: "check_progress_\(firstStudent.id ?? "")",
      type: .checkProgress,
      title: "Student Needs Attention",
      description: "\(firstStudent.name) has low engagement - consider reaching out",
      priority: .high,
      targetStudentId: firstStudent.id,
      targetPlanId: nil
    )
  }

  private nonisolated static func missingPlanAction(for students: [Student], plans: [TMIPlan]) -> NextBestAction? {
    guard let firstStudent = studentsMissingPlans(students: students, plans: plans).first else { return nil }

    return NextBestAction(
      id: "create_plan_\(firstStudent.id ?? "")",
      type: .createPlan,
      title: "Create TMI Plan",
      description: "\(firstStudent.name) completed survey but has no plan",
      priority: .medium,
      targetStudentId: firstStudent.id,
      targetPlanId: nil
    )
  }

  private nonisolated static func surveyFollowUpAction(for students: [Student], role: StaffRole?) -> NextBestAction? {
    guard role == .teacher || role == .counselor else { return nil }
    guard let firstStudent = students.first(where: { $0.surveyResults?.isEmpty ?? true }) else { return nil }

    return NextBestAction(
      id: "add_interests_\(firstStudent.id ?? "")",
      type: .addInterests,
      title: "Survey Pending",
      description: "\(firstStudent.name) hasn't completed their interest survey",
      priority: .low,
      targetStudentId: firstStudent.id,
      targetPlanId: nil
    )
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
      recentActivities: filteredActivities,
      nextBestAction: data.nextBestAction,
      roleData: data.roleData
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

struct DashboardView: View {
    @Environment(\.dashboardStateModel) var stateModel
    @Environment(\.authStateModel) private var authStateModel
    @State private var districtViewModel = DistrictDashboardViewModel()
    @State private var selectedTimeFrame: TimeFrame = .week
    @State private var showingAllActivities = false
    @State private var navigateToStudents = false
    @State private var navigateToPlans = false
    @State private var navigateToSurveys = false

    // Roles that should see district-level content appended to the dashboard
    private var isDistrictAdminRole: Bool {
        guard let membership = authStateModel.currentMembership else { return false }
        return AuthorizationPolicy.canViewAggregate(
          membership,
          districtID: membership.districtID
        )
    }

    private var isTeacherRole: Bool {
        authStateModel.currentMembership?.role == .teacher
    }

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
            await stateModel.fetchWithMembership(authStateModel.currentMembership)
            if isDistrictAdminRole {
                await loadDistrictData()
            }
        }
        .refreshable {
            await stateModel.fetchWithMembership(authStateModel.currentMembership)
            if isDistrictAdminRole {
                await loadDistrictData()
            }
        }
        .navigationDestination(isPresented: $navigateToStudents) {
            StudentListView()
        }
        .navigationDestination(isPresented: $navigateToPlans) {
            CanonicalPlanListView()
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
                Task {
                    await stateModel.fetchWithMembership(
                        authStateModel.currentMembership
                    )
                }
            },
            actionLabel: "Try Again"
        )
    }

    // MARK: - Main Content

    @ViewBuilder
    private func dashboardContent(_ data: DashboardData) -> some View {
        ScrollView {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: TMISpacing.lg) {
                    dashboardLeftColumn(data)
                        .frame(minWidth: 320, maxWidth: .infinity)
                    dashboardRightColumn(data)
                        .frame(minWidth: 320, maxWidth: .infinity)
                }

                VStack(spacing: TMISpacing.lg) {
                    dashboardLeftColumn(data)
                    dashboardRightColumn(data)
                }
            }
            
            Color.clear.frame(height: 120)
        }
        .padding(.horizontal, TMISpacing.screenPadding)
        .padding(.top)
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAllActivities) {
            NavigationStack {
                allActivitiesView(data)
            }
            .tmiSheetStyle()
        }
    }

    private func dashboardLeftColumn(_ data: DashboardData) -> some View {
        VStack(spacing: TMISpacing.lg) {
            recentActivitySection(data)
                .tmiCard()

            if !data.engagementData.isEmpty {
                DashboardEngagementChart(data: data.engagementData)
                    .tmiCard()
            }
        }
    }

    private func dashboardRightColumn(_ data: DashboardData) -> some View {
        VStack(spacing: TMISpacing.lg) {
            QuickActionsGrid(data: data)
                .tmiCard()

            releaseOneStatusCard(data)
                .tmiCard()
        }
    }

    // MARK: - Recent Activity Section

    private func recentActivitySection(_ data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(.tmiTitle3.bold())
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

            Divider()

            if data.recentActivities.isEmpty {
                emptyActivityState(data)
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

    private func emptyActivityState(_ data: DashboardData) -> some View {
        VStack(spacing: TMISpacing.sm) {
            Image(systemName: data.totalStudents == 0 ? "person.crop.circle.badge.plus" : "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(.tmiPrimary)

            Text(MVPEmptyStateCopy.dashboardActivityTitle)
                .font(.tmiBody)
                .fontWeight(.semibold)
                .foregroundColor(.tmiTextPrimary)

            Text(
                data.totalStudents == 0
                    ? MVPEmptyStateCopy.dashboardActivityMessage
                    : "Recent roster and plan activity will appear here as canonical events are recorded."
            )
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)
                .multilineTextAlignment(.center)

            TMIButton(
                text: data.totalStudents == 0
                    ? MVPEmptyStateCopy.dashboardActivityAction
                    : "View Roster",
                icon: "person.3.fill",
                style: .primary,
                action: { navigateToStudents = true }
            )
            .padding(.top, TMISpacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.xl)
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .foregroundColor(Color.tmiTextTertiary.opacity(0.4))
        )
        .padding(.horizontal, TMISpacing.sm)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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



    private func releaseOneStatusCard(_ data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Label("Release 1 workspace", systemImage: "checkmark.shield")
                .font(.tmiTitle3.bold())
                .foregroundColor(.tmiPrimary)

            Text("\(data.totalStudents) active students · \(data.activeTMIPlans) visible plans")
                .font(.tmiBody)
                .foregroundColor(.tmiTextPrimary)

            Text("Engagement, survey, interest, and support-alert metrics appear only after their canonical data releases. No placeholder scores are shown.")
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - District Data Loading

    private func loadDistrictData() async {
        if let membership = authStateModel.currentMembership,
           AuthorizationPolicy.canViewAggregate(
            membership,
            districtID: membership.districtID
           ) {
            await districtViewModel.loadDashboard(districtId: membership.districtID)
        }
    }

    // MARK: - District Overview Section (admin/superintendent roles)

    @ViewBuilder
    private var districtOverviewSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Section header
            HStack {
                Image(systemName: "building.columns.fill")
                    .foregroundColor(.tmiPrimary)
                Text("District Overview")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)
                Spacer()
            }
            .padding(.horizontal, TMISpacing.screenPadding)

            if districtViewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, TMISpacing.xl)
                    Spacer()
                }
            } else {
                // KPI grid
                VStack(spacing: TMISpacing.md) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: TMISpacing.md) {
                        DistrictKPICard(
                            title: "Total Students",
                            value: "\(districtViewModel.metrics.totalStudents)",
                            icon: "person.3.fill",
                            color: .blue
                        )
                        DistrictKPICard(
                            title: "Engagement Rate",
                            value: districtViewModel.metrics.engagementPercentage,
                            icon: "chart.line.uptrend.xyaxis",
                            color: .green
                        )
                        DistrictKPICard(
                            title: "Active Plans",
                            value: "\(districtViewModel.metrics.activePlansCount)",
                            icon: "doc.text.fill",
                            color: .orange
                        )
                        DistrictKPICard(
                            title: "Needs Attention",
                            value: "\(districtViewModel.metrics.flaggedStudentsCount)",
                            icon: "exclamationmark.triangle.fill",
                            color: districtViewModel.metrics.flaggedStudentsCount > 0 ? .red : .gray
                        )
                    }

                    // Students needing attention list
                    StudentsNeedingAttentionList(alerts: districtViewModel.studentsNeedingAttention)

                    // AI-generated district insights
                    DistrictInsightsSummary(insights: districtViewModel.insights)
                }
            }
        }
        .padding(.vertical, TMISpacing.md)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(TMIRadius.lg)
    }
}

// MARK: - Next Best Quick Action Tile

struct NextBestQuickActionTile: View {
    let action: NextBestAction
    let onAction: () -> Void

    var body: some View {
        Button(action: onAction) {
            HStack(spacing: TMISpacing.md) {
                Circle()
                    .fill(priorityColor.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: actionIcon)
                            .foregroundColor(priorityColor)
                            .font(.system(size: 14, weight: .semibold))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next Step")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                    Text(action.title)
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tmiCard()
    }

    private var priorityColor: Color {
        switch action.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }

    private var actionIcon: String {
        switch action.type {
        case .createPlan: return "plus.rectangle.fill"
        case .reviewPlan: return "doc.text.magnifyingglass"
        case .scheduleMeeting: return "calendar.badge.plus"
        case .completeNotes: return "note.text.badge.plus"
        case .addInterests: return "heart.text.square.fill"
        case .checkProgress: return "chart.line.uptrend.xyaxis"
        case .pendingApproval: return "checkmark.circle.badge.questionmark"
        }
    }
}

// MARK: - Next Best Action Card

struct NextBestActionCard: View {
    let action: NextBestAction
    let onAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.sm) {
            HStack {
                Circle()
                    .fill(priorityColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: actionIcon)
                            .foregroundColor(priorityColor)
                            .font(.system(size: 16, weight: .medium))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Step")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                    Text(action.title)
                        .font(.tmiHeading2)
                        .foregroundColor(.tmiTextPrimary)
                }
                
                Spacer()
                
                Button(action: onAction) {
                    Text("Go")
                        .font(.tmiCaption.weight(.semibold))
                        .foregroundColor(Color.tmiTextPrimary)
                        .padding(.horizontal, TMISpacing.md)
                        .padding(.vertical, TMISpacing.xs)
                        .background(priorityColor)
                        .cornerRadius(TMIRadius.sm)
                }
            }
            
            Text(action.description)
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)
        }
        .tmiCard()
    }
    
    private var priorityColor: Color {
        switch action.priority {
        case .urgent: return .red
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
    
    private var actionIcon: String {
        switch action.type {
        case .createPlan: return "plus.rectangle.fill"
        case .reviewPlan: return "doc.text.magnifyingglass"
        case .scheduleMeeting: return "calendar.badge.plus"
        case .completeNotes: return "note.text.badge.plus"
        case .addInterests: return "heart.text.square.fill"
        case .checkProgress: return "chart.line.uptrend.xyaxis"
        case .pendingApproval: return "checkmark.circle.badge.questionmark"
        }
    }
}

/// MARK: - Role Summary Row

struct RoleSummaryRow: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: TMISpacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }

            Text(label)
                .font(.tmiBody)
                .foregroundColor(.tmiTextPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.tmiTextPrimary)
        }
        .padding(.vertical, TMISpacing.sm)
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
}

// MARK: - Actionable Cards moved to Components/ActionableCards.swift
