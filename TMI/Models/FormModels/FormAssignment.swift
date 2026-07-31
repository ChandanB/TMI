//
//  FormAssignment.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import Foundation
@preconcurrency import FirebaseFirestore

/// Represents a form assignment to a cohort of students
struct FormAssignment: Codable, Identifiable, Sendable {
  @DocumentID var id: String?
  var templateId: String
  var templateName: String
  var assignedBy: String // User ID of staff who assigned
  var assignedByName: String?
  var cohort: AssignmentCohort
  /// Canonical target projection used by security rules and respondent sessions.
  var studentIDs: [String]?
  var dueDate: Date?
  var createdAt: Date
  var updatedAt: Date?
  var isActive: Bool
  var instructions: String?
  var allowLateSubmissions: Bool
  var requiresReview: Bool // If true, submissions need staff review

  // Metadata
  var districtId: String?
  var schoolId: String?

  // Statistics (computed or cached)
  var totalAssigned: Int // Number of students assigned
  var totalSubmitted: Int // Number of submissions
  var totalReviewed: Int // Number reviewed

  init(
    id: String? = nil,
    templateId: String,
    templateName: String,
    assignedBy: String,
    assignedByName: String? = nil,
    cohort: AssignmentCohort,
    studentIDs: [String]? = nil,
    dueDate: Date? = nil,
    createdAt: Date = Date(),
    updatedAt: Date? = nil,
    isActive: Bool = true,
    instructions: String? = nil,
    allowLateSubmissions: Bool = true,
    requiresReview: Bool = false,
    districtId: String? = nil,
    schoolId: String? = nil,
    totalAssigned: Int = 0,
    totalSubmitted: Int = 0,
    totalReviewed: Int = 0
  ) {
    self.id = id
    self.templateId = templateId
    self.templateName = templateName
    self.assignedBy = assignedBy
    self.assignedByName = assignedByName
    self.cohort = cohort
    self.studentIDs = studentIDs
    self.dueDate = dueDate
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isActive = isActive
    self.instructions = instructions
    self.allowLateSubmissions = allowLateSubmissions
    self.requiresReview = requiresReview
    self.districtId = districtId
    self.schoolId = schoolId
    self.totalAssigned = totalAssigned
    self.totalSubmitted = totalSubmitted
    self.totalReviewed = totalReviewed
  }
}

// MARK: - Assignment Cohort

enum AssignmentCohort: Codable, Equatable, Sendable {
  case allStudents
  case school(schoolId: String, schoolName: String)
  case grade(grade: String)
  case specificStudents(studentIds: [String], count: Int)
  case customClass(className: String, studentIds: [String])

  var displayName: String {
    switch self {
    case .allStudents:
      return "All Students"
    case .school(_, let schoolName):
      return schoolName
    case .grade(let grade):
      return "Grade \(grade)"
    case .specificStudents(_, let count):
      return "\(count) Selected Students"
    case .customClass(let className, _):
      return className
    }
  }

  var description: String {
    switch self {
    case .allStudents:
      return "Assigned to all students in your district"
    case .school(_, let schoolName):
      return "Assigned to all students at \(schoolName)"
    case .grade(let grade):
      return "Assigned to all students in grade \(grade)"
    case .specificStudents(_, let count):
      return "Assigned to \(count) specific students"
    case .customClass(let className, let studentIds):
      return "Assigned to \(studentIds.count) students in \(className)"
    }
  }

  // Coding implementation
  private enum CodingKeys: String, CodingKey {
    case type
    case schoolId, schoolName
    case grade
    case studentIds, count
    case className
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)

    switch type {
    case "allStudents":
      self = .allStudents
    case "school":
      let schoolId = try container.decode(String.self, forKey: .schoolId)
      let schoolName = try container.decode(String.self, forKey: .schoolName)
      self = .school(schoolId: schoolId, schoolName: schoolName)
    case "grade":
      let grade = try container.decode(String.self, forKey: .grade)
      self = .grade(grade: grade)
    case "specificStudents":
      let studentIds = try container.decode([String].self, forKey: .studentIds)
      let count = try container.decode(Int.self, forKey: .count)
      self = .specificStudents(studentIds: studentIds, count: count)
    case "customClass":
      let className = try container.decode(String.self, forKey: .className)
      let studentIds = try container.decode([String].self, forKey: .studentIds)
      self = .customClass(className: className, studentIds: studentIds)
    default:
      throw DecodingError.dataCorrupted(
        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown cohort type")
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    switch self {
    case .allStudents:
      try container.encode("allStudents", forKey: .type)
    case .school(let schoolId, let schoolName):
      try container.encode("school", forKey: .type)
      try container.encode(schoolId, forKey: .schoolId)
      try container.encode(schoolName, forKey: .schoolName)
    case .grade(let grade):
      try container.encode("grade", forKey: .type)
      try container.encode(grade, forKey: .grade)
    case .specificStudents(let studentIds, let count):
      try container.encode("specificStudents", forKey: .type)
      try container.encode(studentIds, forKey: .studentIds)
      try container.encode(count, forKey: .count)
    case .customClass(let className, let studentIds):
      try container.encode("customClass", forKey: .type)
      try container.encode(className, forKey: .className)
      try container.encode(studentIds, forKey: .studentIds)
    }
  }
}

// MARK: - Submission Status

enum SubmissionStatus: String, Codable, CaseIterable, Sendable {
  case notStarted = "not_started"
  case draft = "draft"
  case submitted = "submitted"
  case reviewed = "reviewed"

  var displayName: String {
    switch self {
    case .notStarted: return "Not Started"
    case .draft: return "Draft"
    case .submitted: return "Submitted"
    case .reviewed: return "Reviewed"
    }
  }

  var color: String {
    switch self {
    case .notStarted: return "#9E9E9E" // Gray
    case .draft: return "#FF9800" // Orange
    case .submitted: return "#2196F3" // Blue
    case .reviewed: return "#4CAF50" // Green
    }
  }
}

