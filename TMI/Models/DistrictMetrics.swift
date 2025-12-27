//
//  DistrictMetrics.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #2
//

import Foundation

// MARK: - District Metrics

struct DistrictMetrics: Codable, Equatable, Sendable {
  var totalStudents: Int
  var activePlansCount: Int
  var completedPlansCount: Int
  var planCompletionRate: Double
  var formCompletionRate: Double
  var avgEngagementRate: Double
  var flaggedStudentsCount: Int
  var totalSchools: Int
  var totalStaff: Int

  init(
    totalStudents: Int = 0,
    activePlansCount: Int = 0,
    completedPlansCount: Int = 0,
    planCompletionRate: Double = 0.0,
    formCompletionRate: Double = 0.0,
    avgEngagementRate: Double = 0.0,
    flaggedStudentsCount: Int = 0,
    totalSchools: Int = 0,
    totalStaff: Int = 0
  ) {
    self.totalStudents = totalStudents
    self.activePlansCount = activePlansCount
    self.completedPlansCount = completedPlansCount
    self.planCompletionRate = planCompletionRate
    self.formCompletionRate = formCompletionRate
    self.avgEngagementRate = avgEngagementRate
    self.flaggedStudentsCount = flaggedStudentsCount
    self.totalSchools = totalSchools
    self.totalStaff = totalStaff
  }

  // Computed properties for display
  var planCompletionPercentage: String {
    String(format: "%.1f%%", planCompletionRate * 100)
  }

  var formCompletionPercentage: String {
    String(format: "%.1f%%", formCompletionRate * 100)
  }

  var engagementPercentage: String {
    String(format: "%.1f%%", avgEngagementRate * 100)
  }

  var totalPlansCount: Int {
    activePlansCount + completedPlansCount
  }
}

// MARK: - School Metrics

struct SchoolMetrics: Codable, Equatable, Sendable {
  var schoolId: String
  var schoolName: String
  var studentCount: Int
  var activePlansCount: Int
  var completedPlansCount: Int
  var engagementRate: Double
  var formCompletionRate: Double
  var flaggedStudentsCount: Int

  init(
    schoolId: String,
    schoolName: String,
    studentCount: Int = 0,
    activePlansCount: Int = 0,
    completedPlansCount: Int = 0,
    engagementRate: Double = 0.0,
    formCompletionRate: Double = 0.0,
    flaggedStudentsCount: Int = 0
  ) {
    self.schoolId = schoolId
    self.schoolName = schoolName
    self.studentCount = studentCount
    self.activePlansCount = activePlansCount
    self.completedPlansCount = completedPlansCount
    self.engagementRate = engagementRate
    self.formCompletionRate = formCompletionRate
    self.flaggedStudentsCount = flaggedStudentsCount
  }

  var totalPlansCount: Int {
    activePlansCount + completedPlansCount
  }

  var planCompletionRate: Double {
    guard totalPlansCount > 0 else { return 0.0 }
    return Double(completedPlansCount) / Double(totalPlansCount)
  }
}

// MARK: - Student Need Alert

struct StudentNeedAlert: Codable, Identifiable, Equatable, Sendable {
  var id: String
  var studentId: String
  var studentName: String
  var schoolId: String
  var schoolName: String
  var alertType: AlertType
  var alertMessage: String
  var severity: Severity
  var timestamp: Date

  enum AlertType: String, Codable, CaseIterable {
    case lowEngagement = "low_engagement"
    case overduePlan = "overdue_plan"
    case incompleteForm = "incomplete_form"
    case noRecentInteraction = "no_recent_interaction"
    case flaggedBehavior = "flagged_behavior"
    case decliningPerformance = "declining_performance"

    var displayName: String {
      switch self {
      case .lowEngagement: return "Low Engagement"
      case .overduePlan: return "Overdue TMI Plan"
      case .incompleteForm: return "Incomplete Form"
      case .noRecentInteraction: return "No Recent Interaction"
      case .flaggedBehavior: return "Flagged Behavior"
      case .decliningPerformance: return "Declining Performance"
      }
    }

    var icon: String {
      switch self {
      case .lowEngagement: return "chart.line.downtrend.xyaxis"
      case .overduePlan: return "calendar.badge.exclamationmark"
      case .incompleteForm: return "doc.badge.ellipsis"
      case .noRecentInteraction: return "person.crop.circle.badge.clock"
      case .flaggedBehavior: return "exclamationmark.triangle.fill"
      case .decliningPerformance: return "arrow.down.circle.fill"
      }
    }
  }

  enum Severity: String, Codable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    var color: String {
      switch self {
      case .low: return "blue"
      case .medium: return "yellow"
      case .high: return "orange"
      case .critical: return "red"
      }
    }
  }
}

// MARK: - Sample Data

extension DistrictMetrics {
  static let sample = DistrictMetrics(
    totalStudents: 2250,
    activePlansCount: 87,
    completedPlansCount: 156,
    planCompletionRate: 0.642,
    formCompletionRate: 0.78,
    avgEngagementRate: 0.724,
    flaggedStudentsCount: 12,
    totalSchools: 3,
    totalStaff: 178
  )
}

extension SchoolMetrics {
  static let sampleSchools: [SchoolMetrics] = [
    SchoolMetrics(
      schoolId: "school-001",
      schoolName: "Lincoln Elementary",
      studentCount: 450,
      activePlansCount: 18,
      completedPlansCount: 42,
      engagementRate: 0.81,
      formCompletionRate: 0.85,
      flaggedStudentsCount: 3
    ),
    SchoolMetrics(
      schoolId: "school-002",
      schoolName: "Washington Middle School",
      studentCount: 600,
      activePlansCount: 28,
      completedPlansCount: 51,
      engagementRate: 0.69,
      formCompletionRate: 0.73,
      flaggedStudentsCount: 5
    ),
    SchoolMetrics(
      schoolId: "school-003",
      schoolName: "Jefferson High School",
      studentCount: 1200,
      activePlansCount: 41,
      completedPlansCount: 63,
      engagementRate: 0.68,
      formCompletionRate: 0.76,
      flaggedStudentsCount: 4
    )
  ]
}

extension StudentNeedAlert {
  static let sampleAlerts: [StudentNeedAlert] = [
    StudentNeedAlert(
      id: UUID().uuidString,
      studentId: "student-001",
      studentName: "Alex Thompson",
      schoolId: "school-003",
      schoolName: "Jefferson High School",
      alertType: .lowEngagement,
      alertMessage: "Engagement score dropped below 40% in the last 2 weeks",
      severity: .high,
      timestamp: Date().addingTimeInterval(-86400 * 2)
    ),
    StudentNeedAlert(
      id: UUID().uuidString,
      studentId: "student-002",
      studentName: "Jamie Rodriguez",
      schoolId: "school-002",
      schoolName: "Washington Middle School",
      alertType: .overduePlan,
      alertMessage: "TMI Plan review overdue by 15 days",
      severity: .medium,
      timestamp: Date().addingTimeInterval(-86400 * 1)
    ),
    StudentNeedAlert(
      id: UUID().uuidString,
      studentId: "student-003",
      studentName: "Morgan Chen",
      schoolId: "school-001",
      schoolName: "Lincoln Elementary",
      alertType: .incompleteForm,
      alertMessage: "3 assigned forms not completed",
      severity: .low,
      timestamp: Date().addingTimeInterval(-86400 * 3)
    )
  ]
}
