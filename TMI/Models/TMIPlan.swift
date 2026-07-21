// TMIPlan.swift

import FirebaseFirestore
import Foundation
import SwiftData

nonisolated enum TMIPlanModel: String, CaseIterable, Codable, Sendable {
  case chaseYourSpace = "Chase Your Space"
  case acknowledgeInterests = "Acknowledge Your Interests and Hobbies"
  case alignYourMind = "Align Your Mind"
  case directAndCorrect = "Direct & Correct Negative Behavior"
  case bullyToBoss = "From Bully to Boss"
  case meekToProtector = "From Meek to Promising Protector"

  var description: String {
    switch self {
    case .chaseYourSpace:
      return
        "For students who already know what they want to do in life. We help cultivate their career pathway choice."
    case .acknowledgeInterests:
      return
        "We meet with each student after the survey to reassure them of our support for their success based on their interests and hobbies."
    case .alignYourMind:
      return
        "Using individual survey results to help keep students focused and on task, like aligning a car."
    case .directAndCorrect:
      return
        "Working with the school Social Worker to provide coping skills and relate scenarios to students' interests and hobbies."
    case .bullyToBoss:
      return
        "Helping bullies find their intrinsic leader by tapping into their interests and guiding them towards positive leadership roles."
    case .meekToProtector:
      return
        "Empowering introverted or passive students by reflecting on their interests and hobbies to build confidence and develop coping skills."
    }
  }

  var icon: String {
    switch self {
    case .chaseYourSpace:
      return "target"
    case .acknowledgeInterests:
      return "heart.text.square"
    case .alignYourMind:
      return "brain.head.profile"
    case .directAndCorrect:
      return "arrow.triangle.turn.up.right.circle"
    case .bullyToBoss:
      return "person.badge.shield.checkmark"
    case .meekToProtector:
      return "shield.lefthalf.filled"
    }
  }
}

nonisolated struct TMIPlan: Codable, Identifiable, Hashable, Sendable {
  var id: String?
  var title: String
  var description: String?
  var students: [Student]
  var model: TMIPlanModel
  var interests: [Interest]  // Now includes both interests and hobbies
  var startDate: Date
  var endDate: Date?
  var creationDate: Date
  var lastUpdated: Date
  var goals: [Goal]
  var progress: Double
  var notes: String
  var strategies: [String]?
  var progressTracking: [ProgressEntry]?
  var createdBy: String
  var resources: [Resource]

  // Phase 1: Approval Workflow (PR #6)
  var approvalStatus: PlanApprovalStatus
  var approvalHistory: [ApprovalHistoryEntry]
  var submittedForApprovalAt: Date?
  var submittedBy: String? // User who submitted for approval
  var currentApprovers: [String]? // UIDs of users awaiting their approval
  var approvedBy: String?
  var approvedAt: Date?
  var rejectionReason: String?

  // Phase 1: District Scoping
  /// District this plan belongs to (for district-scoped queries)
  var districtId: String?
  /// Counselor assigned to this plan (for caseload queries)
  var assignedCounselorId: String?

  // Phase 1A: Survey snapshot fields for interest tracking
  var latestInterestSurveyId: String?
  var interestIdsSnapshot: [String]?
  var snapshotUpdatedAt: Date?

  init(
    id: String? = nil, title: String, description: String? = nil, students: [Student],
    model: TMIPlanModel, interests: [Interest], startDate: Date, endDate: Date?, creationDate: Date,
    lastUpdated: Date, goals: [Goal], progress: Double, notes: String, strategies: [String]? = nil,
    progressTracking: [ProgressEntry]? = nil, createdBy: String, resources: [Resource] = [],
    approvalStatus: PlanApprovalStatus = .draft, approvalHistory: [ApprovalHistoryEntry] = [],
    submittedForApprovalAt: Date? = nil, submittedBy: String? = nil, currentApprovers: [String]? = nil,
    approvedBy: String? = nil, approvedAt: Date? = nil, rejectionReason: String? = nil,
    districtId: String? = nil, assignedCounselorId: String? = nil,
    latestInterestSurveyId: String? = nil, interestIdsSnapshot: [String]? = nil, snapshotUpdatedAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.description = description
    self.students = students
    self.model = model
    self.interests = interests
    self.startDate = startDate
    self.endDate = endDate
    self.creationDate = creationDate
    self.lastUpdated = lastUpdated
    self.goals = goals
    self.progress = progress
    self.notes = notes
    self.strategies = strategies
    self.progressTracking = progressTracking
    self.createdBy = createdBy
    self.resources = resources
    self.approvalStatus = approvalStatus
    self.approvalHistory = approvalHistory
    self.submittedForApprovalAt = submittedForApprovalAt
    self.submittedBy = submittedBy
    self.currentApprovers = currentApprovers
    self.approvedBy = approvedBy
    self.approvedAt = approvedAt
    self.rejectionReason = rejectionReason
    self.districtId = districtId
    self.assignedCounselorId = assignedCounselorId
    self.latestInterestSurveyId = latestInterestSurveyId
    self.interestIdsSnapshot = interestIdsSnapshot
    self.snapshotUpdatedAt = snapshotUpdatedAt
  }

  public static func == (lhs: TMIPlan, rhs: TMIPlan) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  // MARK: - Computed Properties

  /// Primary student (first student in the list for backward compatibility)
  var primaryStudent: Student? {
    return students.first
  }

  /// Calculated progress based on goals
  var calculatedProgress: Double {
    guard !goals.isEmpty else { return 0.0 }

    // Calculate average progress of all goals
    let totalProgress = goals.reduce(0.0) { $0 + $1.progress }
    return totalProgress / Double(goals.count)
  }

  /// Number of completed goals
  var completedGoalsCount: Int {
    goals.filter { $0.status == .completed }.count
  }

  /// Progress percentage as integer (0-100)
  var progressPercentage: Int {
    Int(calculatedProgress * 100)
  }

  // MARK: - Firestore Conversion

  func toFirestoreData() -> [String: Any] {
    var data: [String: Any] = [
      "title": title,
      "description": description ?? "",
      "model": model.rawValue,
      "startDate": startDate.timeIntervalSince1970,
      "endDate": endDate?.timeIntervalSince1970 as Any,
      "creationDate": creationDate.timeIntervalSince1970,
      "lastUpdated": lastUpdated.timeIntervalSince1970,
      "progress": progress,
      "notes": notes,
      "createdBy": createdBy,
      "resources": resources.map { try? Firestore.Encoder().encode($0) },
      "approvalStatus": approvalStatus.rawValue,
      "approvalHistory": approvalHistory.map { entry in
        [
          "action": entry.action.rawValue,
          "actionBy": entry.actionBy,
          "timestamp": entry.timestamp.timeIntervalSince1970,
          "comment": entry.comment as Any,
        ]
      },
    ]

    if let submittedAt = submittedForApprovalAt {
      data["submittedForApprovalAt"] = submittedAt.timeIntervalSince1970
    }
    if let submittedBy = submittedBy {
      data["submittedBy"] = submittedBy
    }
    if let currentApprovers = currentApprovers {
      data["currentApprovers"] = currentApprovers
    }
    if let approvedBy = approvedBy {
      data["approvedBy"] = approvedBy
    }
    if let approvedAt = approvedAt {
      data["approvedAt"] = approvedAt.timeIntervalSince1970
    }
    if let rejectionReason = rejectionReason {
      data["rejectionReason"] = rejectionReason
    }

    // Convert students array
    data["students"] = students.map { student in
      return [
        "id": student.id ?? "",
        "name": student.name,
        "grade": student.grade,
      ]
    }

    // Convert interests to full objects for proper reconstruction
    data["interests"] = interests.map { $0.toFirestoreData() }

    // Convert goals
    data["goals"] = goals.map { goal in
      return [
        "id": goal.id.uuidString,
        "description": goal.description,
        "status": goal.status.rawValue,
        "progress": goal.progress,
        "notes": goal.notes as Any,
        "dueDate": goal.dueDate?.timeIntervalSince1970 as Any,
      ]
    }

    data["strategies"] = strategies
    data["progressTracking"] = progressTracking?.map { entry in
      return [
        "score": entry.score,
        "date": entry.date.timeIntervalSince1970,
        "notes": entry.notes as Any,
      ]
    }

    // Phase 1A: Survey snapshot fields
    if let latestInterestSurveyId = latestInterestSurveyId {
      data["latestInterestSurveyId"] = latestInterestSurveyId
    }
    if let interestIdsSnapshot = interestIdsSnapshot {
      data["interestIdsSnapshot"] = interestIdsSnapshot
    }
    if let snapshotUpdatedAt = snapshotUpdatedAt {
      data["snapshotUpdatedAt"] = snapshotUpdatedAt.timeIntervalSince1970
    }

    // Phase 1: District scoping
    if let districtId = districtId {
      data["districtId"] = districtId
    }
    if let assignedCounselorId = assignedCounselorId {
      data["assignedCounselorId"] = assignedCounselorId
    }

    return data
  }
}

nonisolated struct ProgressEntry: Codable, Sendable, Hashable {
  let score: Double
  let date: Date
  let notes: String?
}

extension TMIPlan {
  static var samplePlan: TMIPlan {
    return TMIPlan(
      title: "Chase Your Space Sample Plan",
      description: "A sample plan for chasing your space.",
      students: [Student.sampleStudents[0]],
      model: .chaseYourSpace,
      interests: [],
      startDate: Date(),
      endDate: nil,
      creationDate: Date(),
      lastUpdated: Date(),
      goals: [],
      progress: 0.50,
      notes: "Student is actively engaged in science club and coding workshops.",
      createdBy: "system",
      resources: Resource.sampleResources
    )
  }

  static var samplePlans: [TMIPlan] {
    let plan1 = TMIPlan.samplePlan

    let plan2 = TMIPlan(
      title: "Acknowledge Interests Sample Plan",
      description: "A sample plan for acknowledging interests.",
      students: [Student.sampleStudents[1]],
      model: .acknowledgeInterests,
      interests: [],
      startDate: Date(),
      endDate: nil,
      creationDate: Date(),
      lastUpdated: Date(),
      goals: [],
      progress: 0.75,
      notes: "Student is actively engaged in science club and coding workshops.",
      createdBy: "system",
      resources: [])

    let plan3 = TMIPlan(
      title: "Align Your Mind Sample Plan",
      description: "A sample plan for aligning your mind.",
      students: [Student.sampleStudents[2]],
      model: .alignYourMind,
      interests: [],
      startDate: Date(),
      endDate: nil,
      creationDate: Date(),
      lastUpdated: Date(),
      goals: [],
      progress: 0.15,
      notes: "Student is actively engaged in science club and coding workshops.",
      createdBy: "system")

    return [plan1, plan2, plan3]
  }
}

nonisolated enum GoalStatus: String, Codable, CaseIterable, Sendable {
  case notStarted = "Not Started"
  case inProgress = "In Progress"
  case completed = "Completed"
}

nonisolated struct Goal: Identifiable, Codable, Sendable, Hashable {
  let id: UUID
  var description: String
  var dueDate: Date?
  var status: GoalStatus
  var progress: Double  // Range from 0.0 to 1.0
  var notes: String?

  // Initializer
  init(
    id: UUID = UUID(),
    description: String,
    dueDate: Date? = nil,
    status: GoalStatus = .notStarted,
    progress: Double = 0.0,
    notes: String? = nil
  ) {
    self.id = id
    self.description = description
    self.dueDate = dueDate
    self.status = status
    self.progress = progress
    self.notes = notes
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: Goal, rhs: Goal) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Approval Workflow (Phase 1: PR #6)

nonisolated enum PlanApprovalStatus: String, Codable, CaseIterable, Sendable {
  case draft = "draft"
  case pendingApproval = "pending_approval"
  case approved = "approved"
  case rejected = "rejected"
  case changesRequested = "changes_requested"

  var displayName: String {
    switch self {
    case .draft: return "Draft"
    case .pendingApproval: return "Pending Approval"
    case .approved: return "Approved"
    case .rejected: return "Rejected"
    case .changesRequested: return "Changes Requested"
    }
  }

  var icon: String {
    switch self {
    case .draft: return "doc.text"
    case .pendingApproval: return "clock.fill"
    case .approved: return "checkmark.circle.fill"
    case .rejected: return "xmark.circle.fill"
    case .changesRequested: return "exclamationmark.triangle.fill"
    }
  }

  var color: String {
    switch self {
    case .draft: return "gray"
    case .pendingApproval: return "orange"
    case .approved: return "green"
    case .rejected: return "red"
    case .changesRequested: return "yellow"
    }
  }
}

nonisolated enum ApprovalAction: String, Codable, Sendable {
  case submitted = "submitted"
  case approved = "approved"
  case rejected = "rejected"
  case changesRequested = "changes_requested"
  case resubmitted = "resubmitted"

  var displayName: String {
    switch self {
    case .submitted: return "Submitted for Approval"
    case .approved: return "Approved"
    case .rejected: return "Rejected"
    case .changesRequested: return "Changes Requested"
    case .resubmitted: return "Resubmitted"
    }
  }
}

nonisolated struct ApprovalHistoryEntry: Codable, Sendable, Hashable {
  let action: ApprovalAction
  let actionBy: String  // User ID
  let timestamp: Date
  let comment: String?

  init(action: ApprovalAction, actionBy: String, timestamp: Date = Date(), comment: String? = nil) {
    self.action = action
    self.actionBy = actionBy
    self.timestamp = timestamp
    self.comment = comment
  }
}
