//
//  DashboardView.swift
//  TMI
//
//  Simplified, purposeful dashboard with unified insight panel.
//  Now uses shared caches from AppBootstrapService and shows next best action.
//

import Charts
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
  /// Plans waiting on *this* member's approval (0 for members who can't approve).
  var pendingApprovalCount: Int = 0
  /// Active students with no open plan.
  var studentsWithoutPlanCount: Int = 0
  
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
  // Fail closed: the app root injects the real model. A Firebase-backed
  // default would trap in fixtures and previews with no FirebaseApp.
  @Entry var dashboardStateModel: DashboardStateModel = .environmentDefault
}

// MARK: - State Model

extension DashboardStateModel {
  /// Allocated once so @Entry does not rebuild it on every read.
  static let environmentDefault = DashboardStateModel()
}

@Observable
final class DashboardStateModel: BaseStateModel<DashboardData, IdentifiableError> {
  // MARK: - Dependencies
  private let studentRepository: any StudentRepository
  private let planRepository: (any PlanRecordRepository)?

  // MARK: - Initialization
  init(
    studentRepository: any StudentRepository = UnavailableStudentRepository(),
    planRepository: (any PlanRecordRepository)? = nil
  ) {
    self.studentRepository = studentRepository
    self.planRepository = planRepository
    super.init()
  }

  // MARK: - Data Fetching

  @MainActor
  override func fetch() async {
    await fetchWithMembership(nil)
  }
  
  @MainActor
  func fetchWithMembership(_ membership: MembershipContext?) async {
    // Stale-while-revalidate: keep what's on screen during a refresh so the
    // page (and its pull-to-refresh control) never collapses into a spinner.
    if case .loaded = state {} else {
      updateState(.loading)
    }

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
      // Coverage is roster-scoped: a plan naming a student outside this
      // member's roster must not push coverage past 100%.
      let rosterIDs = Set(students.map(\.id))
      let studentsWithPlans = Set(
        planRecords.filter { $0.status.isOpen }.flatMap { $0.studentIDs }
      ).intersection(rosterIDs).count
      let recentActivities = canonicalRecentActivities(
        students: students,
        planRecords: planRecords
      )
      let roleData = canonicalRoleData(
        membership: membership,
        students: students,
        planRecords: planRecords
      )
      // Approval work is only "next" for the member who can act on it —
      // the same rule the plan list uses for its Needs Approval attention.
      let approvable = planRecords.filter {
        $0.status == .pendingApproval
          && $0.approverMemberIDs.contains(membership.userID)
          && membership.capabilities.contains(.planApprove)
      }
      let plannedStudentIDs = Set(planRecords.filter { $0.status.isOpen }.flatMap { $0.studentIDs })
      let studentsWithoutPlan = students.filter { !plannedStudentIDs.contains($0.id) }
      let nextAction = Self.approvalAction(forPending: approvable)
        ?? Self.startPlanAction(for: studentsWithoutPlan.first)

      let dashboardData = DashboardData(
        engagementData: [],
        totalStudents: totalStudents,
        activeTMIPlans: activeTMIPlans,
        interestsIdentified: 0,
        surveysCompleted: 0,
        plansAligned: studentsWithPlans,
        recentActivities: recentActivities,
        pendingApprovalCount: approvable.count,
        studentsWithoutPlanCount: studentsWithoutPlan.count,
        nextBestAction: nextAction,
        roleData: roleData
      )

      updateState(.loaded(dashboardData))
    } catch is CancellationError {
      return
    } catch {
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
      } else if names.count > 1 {
        description = "Plan '\(plan.title)' for \(names.count) students was updated"
      } else if plan.studentIDs.count > 1 {
        description = "Plan '\(plan.title)' for \(plan.studentIDs.count) students was updated"
      } else {
        description = "Plan '\(plan.title)' was updated"
      }

      var activity = RecentActivity(
        id: "plan-\(plan.id)-\(Int(plan.metadata.updatedAt.timeIntervalSince1970))",
        icon: "doc.text",
        title: "TMI Plan Updated",
        description: description,
        date: plan.metadata.updatedAt,
        iconColor: .blue
      )
      activity.destination = .plan(plan.id)
      return activity
    }

    let studentActivities = students.compactMap { student -> RecentActivity? in
      guard student.metadata.createdAt > sevenDaysAgo else { return nil }

      var activity = RecentActivity(
        id: "student-\(student.id)",
        icon: "person.crop.circle.badge.plus",
        title: "Student Added",
        description: "\(student.displayName) was added",
        date: student.metadata.createdAt,
        iconColor: .green
      )
      activity.destination = .student(student.id)
      return activity
    }

    return (planActivities + studentActivities)
      .sorted { $0.date > $1.date }
      .prefix(10)
      .map { $0 }
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
      description: pendingPlans.count == 1 ? "1 plan needs your review" : "\(pendingPlans.count) plans need your review",
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
      description: pendingPlanRecords.count == 1
        ? "1 plan needs your review"
        : "\(pendingPlanRecords.count) plans need your review",
      priority: .urgent,
      targetStudentId: nil,
      targetPlanId: pendingPlanRecords.first?.id
    )
  }

  private nonisolated static func startPlanAction(for student: StudentRecord?) -> NextBestAction? {
    guard let student else { return nil }

    return NextBestAction(
      id: "create_plan_\(student.id)",
      type: .createPlan,
      title: "Start a support plan for \(student.displayName)",
      description: "No open plan yet. Their record has what you need to begin.",
      priority: .medium,
      targetStudentId: student.id,
      targetPlanId: nil
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
  
  @MainActor
  override func refresh() async {
    await fetch()
  }

}

// MARK: - Today (Dashboard)

/// The home screen. iPhone gets one focused column that answers "what needs
/// me now?"; iPad and Mac get a composed two-column page within a readable
/// maximum width.
struct DashboardView: View {
    @Environment(\.dashboardStateModel) var stateModel
    @Environment(\.authStateModel) private var authStateModel
    @Environment(\.programContext) private var programContext
    @Environment(AppRouter.self) private var router
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#endif
    @State private var showingAllActivities = false
    @State private var refreshCount = 0

    private var terminology: Terminology { programContext.shell.terminology }

    private var usesWideLayout: Bool {
#if os(macOS)
        true
#else
        horizontalSizeClass == .regular
#endif
    }

    var body: some View {
        Group {
            switch stateModel.state {
            case .idle, .loading:
                page(.placeholder, isPlaceholder: true)
            case .loaded(let data):
                page(data, isPlaceholder: false)
            case .error(let error):
                TMIEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Today couldn’t load",
                    message: error.message,
                    action: { Task { await reload() } },
                    actionLabel: "Try Again"
                )
            }
        }
        .tmiScreenBackground()
        .navigationTitle("Today")
#if os(iOS)
        .toolbarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await reload() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Refresh (⌘R)")
            }
        }
        .task(id: authStateModel.currentMembership) {
            await reload()
        }
        .refreshable {
            await reload()
        }
        .sensoryFeedback(.success, trigger: refreshCount)
        .sheet(isPresented: $showingAllActivities) {
            if case .loaded(let data) = stateModel.state {
                NavigationStack {
                    DashboardActivityFeed(activities: data.recentActivities, onOpen: open)
                        .navigationTitle("Recent Activity")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingAllActivities = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
                .tmiSheetStyle()
            }
        }
    }

    private func reload() async {
        await stateModel.fetchWithMembership(authStateModel.currentMembership)
        if case .loaded = stateModel.state {
            refreshCount += 1
        }
    }

    // MARK: Layout

    private func page(_ data: DashboardData, isPlaceholder: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TMISpacing.lg) {
                header
                if usesWideLayout {
                    HStack(alignment: .top, spacing: TMISpacing.lg) {
                        VStack(alignment: .leading, spacing: TMISpacing.lg) {
                            nextStep(data)
                            activity(data)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: TMISpacing.lg) {
                            metrics(data, columns: 2)
                            caseload(data)
                            workspace
                        }
                        .frame(width: 380)
                    }
                } else {
                    nextStep(data)
                    metrics(data, columns: 2)
                    activity(data)
                    caseload(data)
                    workspace
                }
            }
            .padding(.horizontal, TMISpacing.screenPadding)
            .padding(.vertical, TMISpacing.md)
            .frame(maxWidth: TMISizing.maxContentWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
            .tmiPlaceholder(isPlaceholder)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .tmiEyebrow()
            Text(greeting)
                .font(.tmiEditorial(usesWideLayout ? .largeTitle : .title))
                .foregroundStyle(TMIColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.top, TMISpacing.sm)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let salutation = switch hour {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
        let firstName = authStateModel.currentUser?.displayName
            .split(separator: " ").first.map(String.init)
        guard let firstName, !firstName.isEmpty else { return salutation }
        return "\(salutation), \(firstName)"
    }

    // MARK: Next best step

    @ViewBuilder
    private func nextStep(_ data: DashboardData) -> some View {
        if let action = data.nextBestAction {
            TMIGoldenHourCard {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    Label("Next best step", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TMIColors.surface.opacity(0.55), in: Capsule())
                    Text(action.title)
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(action.description)
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.goldenHourSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(actionLabel(for: action)) {
                        perform(action)
                    }
                    .buttonStyle(.tmiPrimary)
                    .padding(.top, TMISpacing.xs)
                    .accessibilityIdentifier("dashboard.nextStep.action")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("dashboard.nextStep")
        } else {
            HStack(spacing: TMISpacing.ms) {
                TMIIconTile("checkmark.seal", tone: .success, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You’re all caught up")
                        .font(.headline)
                        .foregroundStyle(TMIColors.textPrimary)
                    Text(data.totalStudents == 0
                        ? "Add your first \(terminology.learner.lowercased()) to get started."
                        : "Nothing is waiting on you right now.")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                }
                Spacer(minLength: 0)
                if data.totalStudents == 0 {
                    Button("Open \(terminology.learners)") {
                        try? router.select(.students)
                    }
                    .buttonStyle(.tmiSecondary)
                }
            }
            .tmiSurface()
            .accessibilityIdentifier("dashboard.caughtUp")
        }
    }

    private func actionLabel(for action: NextBestAction) -> String {
        switch action.type {
        case .pendingApproval, .reviewPlan: "Review Plan"
        case .createPlan: "Open \(terminology.learner)"
        case .scheduleMeeting: "Schedule"
        case .addInterests: "Start Survey"
        case .checkProgress, .completeNotes: "Open \(terminology.learner)"
        }
    }

    private func perform(_ action: NextBestAction) {
        if let planID = action.targetPlanId {
            open(.plan(planID))
        } else if let studentID = action.targetStudentId {
            open(.student(studentID))
        } else if action.type == .pendingApproval {
            try? router.select(.plans)
        } else {
            try? router.select(.students)
        }
    }

    private func open(_ destination: ActivityDestination) {
        showingAllActivities = false
        switch destination {
        case .student(let id): try? router.openListed(.student(id))
        case .plan(let id): try? router.openListed(.plan(id))
        }
    }

    // MARK: Metrics

    private func metrics(_ data: DashboardData, columns: Int) -> some View {
        let tiles = metricTiles(data)
        return Grid(horizontalSpacing: TMISpacing.ms, verticalSpacing: TMISpacing.ms) {
            ForEach(Array(stride(from: 0, to: tiles.count, by: columns)), id: \.self) { start in
                GridRow {
                    ForEach(tiles[start..<min(start + columns, tiles.count)]) { tile in
                        TMIMetricTile(tile.title, value: tile.value, caption: tile.caption, systemImage: tile.symbol)
                            .accessibilityIdentifier("dashboard.kpi.\(tile.id)")
                    }
                }
            }
        }
    }

    private struct MetricTileModel: Identifiable {
        let id: String
        let title: String
        let value: String
        let caption: String?
        let symbol: String
    }

    private func metricTiles(_ data: DashboardData) -> [MetricTileModel] {
        var tiles = [
            MetricTileModel(
                id: "students",
                title: terminology.learners,
                value: data.totalStudents.formatted(),
                caption: "Active on your roster",
                symbol: "person.2"
            ),
            MetricTileModel(
                id: "activePlans",
                title: "Active plans",
                value: data.activeTMIPlans.formatted(),
                caption: "Approved and underway",
                symbol: "chart.line.uptrend.xyaxis"
            ),
        ]
        tiles.append(MetricTileModel(
            id: "withoutPlan",
            title: "Need a plan",
            value: data.studentsWithoutPlanCount.formatted(),
            caption: "No open plan yet",
            symbol: "doc.badge.plus"
        ))
        if authStateModel.currentMembership?.capabilities.contains(.planApprove) == true {
            tiles.append(MetricTileModel(
                id: "approvals",
                title: "Awaiting you",
                value: data.pendingApprovalCount.formatted(),
                caption: "Plans to approve",
                symbol: "checkmark.seal"
            ))
        } else {
            let updates = data.recentActivities.filter {
                if case .plan = $0.destination { true } else { false }
            }.count
            tiles.append(MetricTileModel(
                id: "planUpdates",
                title: "Plan updates",
                value: updates.formatted(),
                caption: "In the last 7 days",
                symbol: "clock.arrow.circlepath"
            ))
        }
        return tiles
    }

    // MARK: Activity

    private func activity(_ data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.ms) {
            if data.recentActivities.count > 4 {
                TMISectionHeader("Recent activity", actionTitle: "See All") {
                    showingAllActivities = true
                }
            } else {
                TMISectionHeader("Recent activity")
            }

            if data.recentActivities.isEmpty {
                HStack(spacing: TMISpacing.ms) {
                    TMIIconTile("clock", tone: .neutral)
                    Text(data.totalStudents == 0
                        ? MVPEmptyStateCopy.dashboardActivityMessage
                        : "No activity in the last 7 days.")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                    Spacer(minLength: 0)
                }
                .tmiSurface()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(data.recentActivities.prefix(4).enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            TMIDivider().padding(.leading, 56)
                        }
                        DashboardActivityRow(activity: item, onOpen: open)
                    }
                }
                .tmiSurface(padding: 0)
            }
        }
        .accessibilityIdentifier("dashboard.activity")
    }

    // MARK: Workspace

    /// Forms, meetings and follow-ups used to hide four taps deep in Settings.
    private var workspace: some View {
        VStack(alignment: .leading, spacing: TMISpacing.ms) {
            TMISectionHeader("Workspace")
            VStack(spacing: 0) {
                workspaceRow("My Tasks", detail: "Follow-ups assigned to you", symbol: "checklist", tone: .info, route: .tasks)
                TMIDivider().padding(.leading, 56)
                workspaceRow("Form Assignments", detail: "Send forms and review responses", symbol: "list.bullet.rectangle", tone: .brand, route: .formAssignments)
                TMIDivider().padding(.leading, 56)
                workspaceRow("Meetings", detail: "Upcoming and past meetings", symbol: "calendar", tone: .success, route: .meetings)
            }
            .tmiSurface(padding: 0)
        }
        .accessibilityIdentifier("dashboard.workspace")
    }

    private func workspaceRow(_ title: String, detail: String, symbol: String, tone: TMITone, route: AppRoute) -> some View {
        Button {
            try? router.open(route)
        } label: {
            HStack(spacing: TMISpacing.ms) {
                TMIIconTile(symbol, tone: tone)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TMIColors.textPrimary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(TMIColors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TMIColors.textTertiary)
            }
            .padding(.horizontal, TMISpacing.md)
            .padding(.vertical, TMISpacing.ms)
        }
        .buttonStyle(.tmiPressable)
    }

    // MARK: Caseload

    private func caseload(_ data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.ms) {
            TMISectionHeader("Plan coverage")
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                let coverage = data.totalStudents > 0 ? Double(data.plansAligned) / Double(data.totalStudents) : 0
                HStack(alignment: .firstTextBaseline) {
                    Text(coverage, format: .percent.precision(.fractionLength(0)))
                        .font(.tmiMetric)
                        .foregroundStyle(TMIColors.textPrimary)
                    Text("of \(terminology.learners.lowercased()) have an open plan")
                        .font(.subheadline)
                        .foregroundStyle(TMIColors.textSecondary)
                }
                TMIProgressBar(value: coverage, height: 8)
                Button {
                    try? router.select(.plans)
                } label: {
                    Label("Open Plans", systemImage: "arrow.right")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.tmiTertiary)
                .padding(.leading, -8)
            }
            .tmiSurface()
        }
    }
}

// MARK: - Activity row and feed

/// One activity line: tinted symbol tile, what happened, and when.
struct DashboardActivityRow: View {
    let activity: RecentActivity
    let onOpen: (ActivityDestination) -> Void

    var body: some View {
        Button {
            if let destination = activity.destination {
                onOpen(destination)
            }
        } label: {
            HStack(spacing: TMISpacing.ms) {
                TMIIconTile(activity.icon, tone: activity.destination.map(Self.tone) ?? .neutral)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TMIColors.textPrimary)
                    Text(activity.description)
                        .font(.footnote)
                        .foregroundStyle(TMIColors.textSecondary)
                        .lineLimit(2)
                        .privacySensitive()
                }
                Spacer(minLength: TMISpacing.sm)
                Text(activity.date, format: .relative(presentation: .named))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TMIColors.textTertiary)
                if activity.destination != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TMIColors.textTertiary)
                }
            }
            .padding(.horizontal, TMISpacing.md)
            .padding(.vertical, TMISpacing.ms)
        }
        .buttonStyle(.tmiPressable)
        .disabled(activity.destination == nil)
        .help(activity.date.formatted(date: .abbreviated, time: .shortened))
    }

    private static func tone(_ destination: ActivityDestination) -> TMITone {
        switch destination {
        case .student: .info
        case .plan: .brand
        }
    }
}

/// Every recent activity, grouped by day.
struct DashboardActivityFeed: View {
    let activities: [RecentActivity]
    let onOpen: (ActivityDestination) -> Void

    private var days: [(day: Date, items: [RecentActivity])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: activities) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0, default: []].sorted { $0.date > $1.date }) }
    }

    var body: some View {
        List {
            ForEach(days, id: \.day) { group in
                Section(Self.title(for: group.day)) {
                    ForEach(group.items) { item in
                        DashboardActivityRow(activity: item, onOpen: onOpen)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .tmiScreenBackground()
    }

    private static func title(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month().day())
    }
}

extension DashboardData {
    /// Layout-shaped placeholder for the first load (rendered redacted).
    static let placeholder = DashboardData(
        totalStudents: 24,
        activeTMIPlans: 12,
        plansAligned: 16,
        recentActivities: (0..<4).map { index in
            RecentActivity(
                id: "placeholder-\(index)",
                icon: "doc.text",
                title: "Plan updated",
                description: "A support plan was updated this week",
                date: .now
            )
        },
        pendingApprovalCount: 2,
        studentsWithoutPlanCount: 8,
        nextBestAction: NextBestAction(
            id: "placeholder",
            type: .reviewPlan,
            title: "Review a plan before its check-in",
            description: "Two goals need an update",
            priority: .medium,
            targetStudentId: nil,
            targetPlanId: nil
        )
    )
}

#Preview("Today") {
    NavigationStack {
        DashboardView()
            .environment(\.dashboardStateModel, DashboardStateModel())
            .environment(AppRouter())
    }
}
