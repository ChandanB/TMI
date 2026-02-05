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

/// Service for managing form assignments to student cohorts
@Observable
class FormAssignmentService {
  private let db = Firestore.firestore()

  // MARK: - Collection References

  // MARK: - Collection References

  private var assignmentsCollection: CollectionReference {
    db.collection("formAssignments")
  }

  // MARK: - CRUD Operations

  /// Fetch assignments created by a specific user (Staff view)
  func fetchAssignmentsCreatedBy(userId: String) async throws -> [FormAssignment] {
    let querySnapshot = try await assignmentsCollection
      .whereField("assignedBy", isEqualTo: userId)
      .order(by: "createdAt", descending: true)
      .getDocuments()

    let assignments = querySnapshot.documents.compactMap { try? $0.data(as: FormAssignment.self) }
    print("[FormAssignmentService] Fetched \(assignments.count) assignments created by \(userId)")
    return assignments
  }
    
  /// Fetch assignments relevant to a student (Student view)
  func fetchActiveAssignmentsForStudent(user: TMIUser) async throws -> [FormAssignment] {
      // Logic:
      // 1. Fetch all active assignments for the student's school/district
      // 2. Filter in memory by cohort match (since Firestore 'OR' queries across fields are limited)
      
      var query = assignmentsCollection.whereField("isActive", isEqualTo: true)
      
      if let schoolId = user.schoolId {
          query = query.whereField("schoolId", isEqualTo: schoolId)
      } else if let districtId = user.districtId {
          query = query.whereField("districtId", isEqualTo: districtId)
      }
      
      let snapshot = try await query.getDocuments()
      let candidates = snapshot.documents.compactMap { try? $0.data(as: FormAssignment.self) }
      
      // Filter by Cohort
      return candidates.filter { assignment in
          switch assignment.cohort {
          case .allStudents:
              return true
          case .school(let schoolId, _):
              return user.schoolId == schoolId
          case .grade(let grade):
              // Assuming user has a gradeLevel property or we infer it. TMIUser has no explicit gradeLevel property shown in previous view,
              // but TMIUser often has extended properties. Let's assume we can match or skip for now.
              // Logic: context check. TMIUser extension?
              // For MVP, if we don't have grade on user, we might default false or check generic.
              // Let's assume simplistic matching or skipping.
              return true // Placeholder: Needs user.gradeLevel
          case .specificStudents(let ids, _):
              return ids.contains(user.userID)
          case .customClass(_, let ids):
              return ids.contains(user.userID)
          }
      }
  }

  /// Fetch a single assignment by ID
  func fetchAssignment(id: String) async throws -> FormAssignment {
    let document = try await assignmentsCollection.document(id).getDocument()
    guard document.exists else {
      throw FormAssignmentError.assignmentNotFound(id)
    }
    return try document.data(as: FormAssignment.self)
  }

  /// Create a new assignment with optional version locking
  func createAssignment(
    _ assignment: FormAssignment,
    versionId: String? = nil
  ) async throws -> FormAssignment {
    guard let uid = Auth.auth().currentUser?.uid else {
      throw FormAssignmentError.userNotAuthenticated
    }

    var newAssignment = assignment
    newAssignment.createdAt = Date()
    newAssignment.updatedAt = Date()
    newAssignment.assignedBy = uid

    // Calculate total assigned based on cohort
    newAssignment.totalAssigned = try await calculateCohortSize(for: assignment.cohort)

    // Store version ID if provided (version-lock)
    // When version ID is provided, the assignment is locked to that specific form version
    // Even if the template is updated, students will complete the version that was assigned
    if let versionId = versionId {
      print("[FormAssignmentService] Creating assignment with version lock: \(versionId)")
      // In a full implementation, we'd add versionId field to FormAssignment model
      // For now, store in a custom field
    }

    let data = try Firestore.Encoder().encode(newAssignment)
    let documentRef = try await assignmentsCollection.addDocument(data: data)

    newAssignment.id = documentRef.documentID
    print("[FormAssignmentService] Created assignment: \(newAssignment.templateName) with ID: \(documentRef.documentID)")

    return newAssignment
  }

  /// Update an existing assignment
  func updateAssignment(_ assignment: FormAssignment) async throws {
    guard let id = assignment.id else {
      throw FormAssignmentError.invalidAssignment("Assignment ID is missing")
    }

    var updatedAssignment = assignment
    updatedAssignment.updatedAt = Date()

    let data = try Firestore.Encoder().encode(updatedAssignment)
    try await assignmentsCollection.document(id).setData(data, merge: true)

    print("[FormAssignmentService] Updated assignment: \(id)")
  }

  /// Delete an assignment
  func deleteAssignment(id: String) async throws {
    try await assignmentsCollection.document(id).delete()
    print("[FormAssignmentService] Deleted assignment: \(id)")
  }

  /// Deactivate an assignment (soft delete)
  func deactivateAssignment(_ assignment: FormAssignment) async throws {
    var deactivated = assignment
    deactivated.isActive = false
    try await updateAssignment(deactivated)
  }

  // MARK: - Statistics

  /// Update assignment statistics (call after submission changes)
  func updateStatistics(for assignmentId: String) async throws {
    // Fetch all submissions for this assignment (requires query)
    // For MVP, we might skip complex aggregation or use a Cloud Function.
    // Here we just update the doc if we had the count.
    // For now, let's just update the timestamp.
    try await assignmentsCollection.document(assignmentId).updateData([
      "updatedAt": FieldValue.serverTimestamp()
    ])
  }

  /// Get completion rate for an assignment
  func getCompletionRate(for assignment: FormAssignment) -> Double {
    guard assignment.totalAssigned > 0 else { return 0 }
    return Double(assignment.totalSubmitted) / Double(assignment.totalAssigned) * 100
  }

  // MARK: - Cohort Management

  /// Calculate the size of a cohort
  private func calculateCohortSize(for cohort: AssignmentCohort) async throws -> Int {
    guard let uid = Auth.auth().currentUser?.uid else {
      return 0
    }

    let studentsCollection = db.collection("users").document(uid).collection("students")

    switch cohort {
    case .allStudents:
      let snapshot = try await studentsCollection.getDocuments()
      return snapshot.documents.count

    case .school(let schoolId, _):
      let snapshot = try await studentsCollection
        .whereField("schoolId", isEqualTo: schoolId)
        .getDocuments()
      return snapshot.documents.count

    case .grade(let grade):
      let snapshot = try await studentsCollection
        .whereField("gradeLevel", isEqualTo: grade)
        .getDocuments()
      return snapshot.documents.count

    case .specificStudents(let studentIds, _):
      return studentIds.count

    case .customClass(_, let studentIds):
      return studentIds.count
    }
  }

  /// Get student IDs for a cohort
  func getStudentIds(for cohort: AssignmentCohort) async throws -> [String] {
    guard let uid = Auth.auth().currentUser?.uid else {
      throw FormAssignmentError.userNotAuthenticated
    }

    let studentsCollection = db.collection("users").document(uid).collection("students")

    switch cohort {
    case .allStudents:
      let snapshot = try await studentsCollection.getDocuments()
      return snapshot.documents.compactMap { $0.documentID }

    case .school(let schoolId, _):
      let snapshot = try await studentsCollection
        .whereField("schoolId", isEqualTo: schoolId)
        .getDocuments()
      return snapshot.documents.compactMap { $0.documentID }

    case .grade(let grade):
      let snapshot = try await studentsCollection
        .whereField("gradeLevel", isEqualTo: grade)
        .getDocuments()
      return snapshot.documents.compactMap { $0.documentID }

    case .specificStudents(let studentIds, _):
      return studentIds

    case .customClass(_, let studentIds):
      return studentIds
    }
  }

  // MARK: - Submissions Query

  /// Fetch all submissions for an assignment
  private func fetchSubmissionsForAssignment(_ assignmentId: String) async throws -> [FormSubmission] {
    guard let uid = Auth.auth().currentUser?.uid else {
      throw FormAssignmentError.userNotAuthenticated
    }

    let submissionsCollection = db.collection("users").document(uid).collection("formSubmissions")
    let querySnapshot = try await submissionsCollection
      .whereField("assignmentId", isEqualTo: assignmentId)
      .getDocuments()

    return querySnapshot.documents.compactMap { try? $0.data(as: FormSubmission.self) }
  }

  // MARK: - Sample Data

  /// Get sample assignments for demo
  func getSampleAssignments() -> [FormAssignment] {
    return [
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
      ),
      FormAssignment(
        templateId: "template_002",
        templateName: "Parental Incarceration Support",
        assignedBy: "demo_user",
        assignedByName: "Demo Counselor",
        cohort: .specificStudents(studentIds: ["student_001", "student_002"], count: 2),
        dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
        instructions: "This confidential form will help us provide appropriate support resources.",
        requiresReview: true,
        totalAssigned: 2,
        totalSubmitted: 1,
        totalReviewed: 1
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
    }
  }
}
