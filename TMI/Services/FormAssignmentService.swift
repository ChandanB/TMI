//
//  FormAssignmentService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

/// Service for managing form assignments to authorized student cohorts.
@Observable
class FormAssignmentService {
  private let db = Firestore.firestore()
  private let authorizationSessions: any AuthorizationSessionProviding
  private let authorization = RBACService()

  init(
    authorizationSessions: any AuthorizationSessionProviding = TrustedAuthorizationSessionStore.shared
  ) {
    self.authorizationSessions = authorizationSessions
  }

  private var assignmentsCollection: CollectionReference {
    db.collection(FirestorePaths.formAssignments)
  }

  // MARK: - CRUD Operations

  /// Fetch assignments created by the currently authenticated staff member.
  func fetchAssignmentsCreatedBy(userId: String) async throws -> [FormAssignment] {
    let session = try authorizedSession()
    guard userId == session.membership.userID else {
      throw FormAssignmentError.authorizationDenied
    }

    let querySnapshot = try await assignmentsCollection
      .whereField("assignedBy", isEqualTo: session.membership.userID)
      .order(by: "createdAt", descending: true)
      .getDocuments()

    let assignments = querySnapshot.documents.compactMap {
      try? $0.data(as: FormAssignment.self)
    }
    var authorizedAssignments: [FormAssignment] = []
    for assignment in assignments {
      if (try? await requireAssignmentAccess(assignment)) != nil {
        authorizedAssignments.append(assignment)
      }
    }

    print("[FormAssignmentService] Fetched \(authorizedAssignments.count) authorized assignments")
    return authorizedAssignments
  }

  /// Fetch active assignments containing a canonical student target.
  /// Independent student accounts remain feature-flagged; this API is for a
  /// trusted staff context until Student Mode has its own session contract.
  func fetchActiveAssignmentsForStudent(
    student: StudentAuthorizationScope
  ) async throws -> [FormAssignment] {
    let session = try authorizedSession()
    guard authorization.canReadStudent(
      member: session.membership,
      student: student
    ) else {
      throw FormAssignmentError.authorizationDenied
    }

    let studentService = StudentService(
      authorizationSessions: authorizationSessions
    )
    guard let canonicalStudent = try await studentService.getStudent(by: student.studentID),
          StudentAuthorizationScope(student: canonicalStudent) == student else {
      throw FormAssignmentError.authorizationDenied
    }

    let snapshot = try await assignmentsCollection
      .whereField("isActive", isEqualTo: true)
      .whereField("districtId", isEqualTo: session.membership.districtID)
      .getDocuments()
    let candidates = snapshot.documents.compactMap {
      try? $0.data(as: FormAssignment.self)
    }

    return candidates.filter {
      cohort($0.cohort, contains: canonicalStudent)
    }
  }

  /// Fetch a single assignment after rebuilding its canonical target scope.
  func fetchAssignment(id: String) async throws -> FormAssignment {
    let document = try await assignmentsCollection.document(id).getDocument()
    guard document.exists else {
      throw FormAssignmentError.assignmentNotFound(id)
    }
    let assignment = try document.data(as: FormAssignment.self)
    _ = try await requireAssignmentAccess(assignment)
    return assignment
  }

  /// Create an assignment after resolving the cohort to canonical students.
  func createAssignment(
    _ assignment: FormAssignment,
    versionId: String? = nil
  ) async throws -> FormAssignment {
    let session = try authorizedSession()
    let access = try await assignmentAccess(
      for: assignment,
      member: session.membership,
      validatesStoredBoundary: false
    )
    guard authorization.canAssignForm(
      member: session.membership,
      assignment: access.scope
    ) else {
      throw FormAssignmentError.authorizationDenied
    }

    var newAssignment = assignment
    newAssignment.createdAt = Date()
    newAssignment.updatedAt = Date()
    newAssignment.assignedBy = session.membership.userID
    newAssignment.assignedByName = session.profile.displayName
    newAssignment.districtId = session.membership.districtID
    newAssignment.schoolId = access.scope.schoolID
    newAssignment.totalAssigned = access.students.count

    if let versionId {
      print("[FormAssignmentService] Creating assignment with version lock: \(versionId)")
    }

    let data = try Firestore.Encoder().encode(newAssignment)
    let documentRef = try await assignmentsCollection.addDocument(data: data)
    newAssignment.id = documentRef.documentID

    print("[FormAssignmentService] Created assignment: \(documentRef.documentID)")
    return newAssignment
  }

  /// Update only after both the stored and proposed cohort boundaries pass policy.
  func updateAssignment(_ assignment: FormAssignment) async throws {
    let session = try authorizedSession()
    guard let id = assignment.id else {
      throw FormAssignmentError.invalidAssignment("Assignment ID is missing")
    }

    let stored = try await fetchAssignmentDocument(id: id)
    _ = try await requireAssignmentAccess(stored)

    let proposedAccess = try await assignmentAccess(
      for: assignment,
      member: session.membership,
      validatesStoredBoundary: false
    )
    guard authorization.canAssignForm(
      member: session.membership,
      assignment: proposedAccess.scope
    ) else {
      throw FormAssignmentError.authorizationDenied
    }

    var updated = assignment
    updated.assignedBy = stored.assignedBy
    updated.assignedByName = stored.assignedByName
    updated.createdAt = stored.createdAt
    updated.updatedAt = Date()
    updated.districtId = session.membership.districtID
    updated.schoolId = proposedAccess.scope.schoolID
    updated.totalAssigned = proposedAccess.students.count

    let data = try Firestore.Encoder().encode(updated)
    try await assignmentsCollection.document(id).setData(data, merge: false)
    print("[FormAssignmentService] Updated assignment: \(id)")
  }

  /// Hard deletion is unavailable until the retention workflow owns it.
  func deleteAssignment(id: String) async throws {
    let stored = try await fetchAssignmentDocument(id: id)
    let access = try await requireAssignmentAccess(stored)
    guard authorization.canDeleteAssignment(
      member: access.session.membership,
      assignment: access.scope
    ) else {
      throw FormAssignmentError.deletionRequiresRetentionWorkflow
    }

    try await assignmentsCollection.document(id).delete()
  }

  func deactivateAssignment(_ assignment: FormAssignment) async throws {
    var deactivated = assignment
    deactivated.isActive = false
    try await updateAssignment(deactivated)
  }

  // MARK: - Statistics

  func updateStatistics(for assignmentId: String) async throws {
    let stored = try await fetchAssignmentDocument(id: assignmentId)
    _ = try await requireAssignmentAccess(stored)
    try await assignmentsCollection.document(assignmentId).updateData([
      "updatedAt": FieldValue.serverTimestamp()
    ])
  }

  func getCompletionRate(for assignment: FormAssignment) -> Double {
    guard assignment.totalAssigned > 0 else { return 0 }
    return Double(assignment.totalSubmitted) / Double(assignment.totalAssigned) * 100
  }

  // MARK: - Cohort Management

  func getStudentIds(for cohort: AssignmentCohort) async throws -> [String] {
    let session = try authorizedSession()
    return try await canonicalStudents(
      for: cohort,
      member: session.membership
    ).compactMap(\.id)
  }

  // MARK: - Submissions Query

  private func fetchSubmissionsForAssignment(
    _ assignmentId: String
  ) async throws -> [FormSubmission] {
    let session = try authorizedSession()
    let stored = try await fetchAssignmentDocument(id: assignmentId)
    _ = try await requireAssignmentAccess(stored)

    let submissionsCollection = db.collection("users")
      .document(session.membership.userID)
      .collection("formSubmissions")
    let querySnapshot = try await submissionsCollection
      .whereField("assignmentId", isEqualTo: assignmentId)
      .getDocuments()

    return querySnapshot.documents.compactMap {
      try? $0.data(as: FormSubmission.self)
    }
  }

  // MARK: - Authorization Helpers

  private struct AssignmentAccess {
    let session: AuthenticatedSession
    let scope: FormAssignmentAuthorizationScope
    let students: [Student]
  }

  private func authorizedSession() throws -> AuthenticatedSession {
    guard let session = authorizationSessions.session(
      authenticatedUserID: Auth.auth().currentUser?.uid
    ) else {
      throw FormAssignmentError.userNotAuthenticated
    }
    return session
  }

  private func fetchAssignmentDocument(id: String) async throws -> FormAssignment {
    let document = try await assignmentsCollection.document(id).getDocument()
    guard document.exists else {
      throw FormAssignmentError.assignmentNotFound(id)
    }
    return try document.data(as: FormAssignment.self)
  }

  private func requireAssignmentAccess(
    _ assignment: FormAssignment
  ) async throws -> AssignmentAccess {
    let session = try authorizedSession()
    let access = try await assignmentAccess(
      for: assignment,
      member: session.membership,
      validatesStoredBoundary: true
    )
    guard authorization.canAssignForm(
      member: session.membership,
      assignment: access.scope
    ) else {
      throw FormAssignmentError.authorizationDenied
    }
    return access
  }

  private func assignmentAccess(
    for assignment: FormAssignment,
    member: MembershipContext,
    validatesStoredBoundary: Bool
  ) async throws -> AssignmentAccess {
    if validatesStoredBoundary,
       assignment.districtId != member.districtID {
      throw FormAssignmentError.authorizationDenied
    }

    let students = try await canonicalStudents(
      for: assignment.cohort,
      member: member
    )
    guard !students.isEmpty else {
      throw FormAssignmentError.invalidAssignment(
        "The selected cohort has no authorized students"
      )
    }

    let studentScopes = try students.map { student in
      guard let scope = StudentAuthorizationScope(student: student),
            scope.districtID == member.districtID else {
        throw FormAssignmentError.authorizationDenied
      }
      return scope
    }
    let schoolIDs = Set(studentScopes.map(\.schoolID))
    let resolvedSchoolID = schoolIDs.count == 1 ? schoolIDs.first : nil

    if validatesStoredBoundary,
       let storedSchoolID = assignment.schoolId,
       storedSchoolID != resolvedSchoolID {
      throw FormAssignmentError.authorizationDenied
    }

    let scope = FormAssignmentAuthorizationScope(
      districtID: member.districtID,
      schoolID: resolvedSchoolID,
      students: studentScopes
    )
    return AssignmentAccess(
      session: try authorizedSession(),
      scope: scope,
      students: students
    )
  }

  private func canonicalStudents(
    for cohort: AssignmentCohort,
    member: MembershipContext
  ) async throws -> [Student] {
    let studentService = StudentService(
      authorizationSessions: authorizationSessions
    )
    let visibleStudents = try await studentService.fetchStudents()

    switch cohort {
    case .allStudents:
      return visibleStudents
    case .school(let schoolID, _):
      guard member.role == .districtAdministrator
              || member.schoolIDs.contains(schoolID) else {
        throw FormAssignmentError.authorizationDenied
      }
      return visibleStudents.filter { $0.schoolId == schoolID }
    case .grade(let grade):
      return visibleStudents.filter { $0.grade == grade }
    case .specificStudents(let studentIDs, _),
         .customClass(_, let studentIDs):
      let requested = Set(studentIDs)
      let matches = visibleStudents.filter {
        guard let id = $0.id else { return false }
        return requested.contains(id)
      }
      guard Set(matches.compactMap(\.id)) == requested else {
        throw FormAssignmentError.authorizationDenied
      }
      return matches
    }
  }

  private func cohort(
    _ cohort: AssignmentCohort,
    contains student: Student
  ) -> Bool {
    switch cohort {
    case .allStudents:
      return true
    case .school(let schoolID, _):
      return student.schoolId == schoolID
    case .grade(let grade):
      return student.grade == grade
    case .specificStudents(let studentIDs, _),
         .customClass(_, let studentIDs):
      guard let studentID = student.id else { return false }
      return studentIDs.contains(studentID)
    }
  }

  // MARK: - Sample Data

  func getSampleAssignments() -> [FormAssignment] {
    [
      FormAssignment(
        templateId: "template_001",
        templateName: "Student Intake Form",
        assignedBy: "demo_user",
        assignedByName: "Demo Teacher",
        cohort: .grade(grade: "9"),
        dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
        instructions: "Please complete this form to help us understand your background and needs.",
        requiresReview: true,
        totalAssigned: 25,
        totalSubmitted: 18,
        totalReviewed: 12
      )
    ]
  }
}

// MARK: - Error Handling

enum FormAssignmentError: Error, LocalizedError {
  case userNotAuthenticated
  case assignmentNotFound(String)
  case invalidAssignment(String)
  case cohortCalculationFailed(String)
  case authorizationDenied
  case deletionRequiresRetentionWorkflow

  var errorDescription: String? {
    switch self {
    case .userNotAuthenticated:
      return "User not authenticated"
    case .assignmentNotFound(let id):
      return "Assignment not found: \(id)"
    case .invalidAssignment(let reason):
      return "Invalid assignment: \(reason)"
    case .cohortCalculationFailed(let reason):
      return "Failed to calculate cohort size: \(reason)"
    case .authorizationDenied:
      return "You don’t have access to this assignment"
    case .deletionRequiresRetentionWorkflow:
      return "Assignments must be archived through the retention workflow"
    }
  }
}
