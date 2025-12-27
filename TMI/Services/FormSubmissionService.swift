//
//  FormSubmissionService.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation

/// Service for managing form submissions, reviews, and analytics
@Observable
class FormSubmissionService {
  private let db = Firestore.firestore()

  // MARK: - Collection References

  private var userSubmissionsCollection: CollectionReference? {
    guard let uid = Auth.auth().currentUser?.uid else { return nil }
    return db.collection("users").document(uid).collection("formSubmissions")
  }

  // MARK: - CRUD Operations

  /// Fetch all submissions for the current user
  func fetchSubmissions() async throws -> [FormSubmission] {
    guard let collection = userSubmissionsCollection else {
      throw FormSubmissionError.userNotAuthenticated
    }

    let querySnapshot = try await collection
      .order(by: "submissionDate", descending: true)
      .getDocuments()

    let submissions = querySnapshot.documents.compactMap { try? $0.data(as: FormSubmission.self) }
    print("[FormSubmissionService] Fetched \(submissions.count) submissions")

    return submissions
  }

  /// Fetch submissions for a specific assignment
  func fetchAssignmentSubmissions(assignmentId: String) async throws -> [FormSubmission] {
    guard let collection = userSubmissionsCollection else {
      throw FormSubmissionError.userNotAuthenticated
    }

    let querySnapshot = try await collection
      .whereField("assignmentId", isEqualTo: assignmentId)
      .order(by: "submissionDate", descending: true)
      .getDocuments()

    let submissions = querySnapshot.documents.compactMap { try? $0.data(as: FormSubmission.self) }
    print("[FormSubmissionService] Fetched \(submissions.count) submissions for assignment: \(assignmentId)")

    return submissions
  }

  /// Fetch submissions for a specific student
  func fetchStudentSubmissions(studentId: String) async throws -> [FormSubmission] {
    guard let collection = userSubmissionsCollection else {
      throw FormSubmissionError.userNotAuthenticated
    }

    let querySnapshot = try await collection
      .whereField("studentId", isEqualTo: studentId)
      .order(by: "submissionDate", descending: true)
      .getDocuments()

    let submissions = querySnapshot.documents.compactMap { try? $0.data(as: FormSubmission.self) }
    print("[FormSubmissionService] Fetched \(submissions.count) submissions for student: \(studentId)")

    return submissions
  }

  /// Fetch submissions needing review
  func fetchSubmissionsNeedingReview() async throws -> [FormSubmission] {
    guard let collection = userSubmissionsCollection else {
      throw FormSubmissionError.userNotAuthenticated
    }

    let querySnapshot = try await collection
      .whereField("status", isEqualTo: "submitted")
      .order(by: "submissionDate", descending: false)
      .getDocuments()

    let submissions = querySnapshot.documents.compactMap { try? $0.data(as: FormSubmission.self) }
    print("[FormSubmissionService] Fetched \(submissions.count) submissions needing review")

    return submissions
  }

  /// Fetch a single submission by ID
  func fetchSubmission(id: String) async throws -> FormSubmission {
    guard let collection = userSubmissionsCollection else {
      throw FormSubmissionError.userNotAuthenticated
    }

    let document = try await collection.document(id).getDocument()
    guard document.exists else {
      throw FormSubmissionError.submissionNotFound(id)
    }

    return try document.data(as: FormSubmission.self)
  }

  /// Create a new submission (draft)
  func createSubmission(_ submission: FormSubmission) async throws -> FormSubmission {
    guard let collection = userSubmissionsCollection else {
      throw FormSubmissionError.userNotAuthenticated
    }

    var newSubmission = submission
    newSubmission.submissionDate = Date()
    newSubmission.updatedAt = Date()

    let data = try Firestore.Encoder().encode(newSubmission)
    let documentRef = try await collection.addDocument(data: data)

    newSubmission.id = documentRef.documentID
    print("[FormSubmissionService] Created submission with ID: \(documentRef.documentID)")

    return newSubmission
  }

  /// Update an existing submission
  func updateSubmission(_ submission: FormSubmission) async throws {
    guard let collection = userSubmissionsCollection else {
      throw FormSubmissionError.userNotAuthenticated
    }

    guard let id = submission.id else {
      throw FormSubmissionError.invalidSubmission("Submission ID is missing")
    }

    var updatedSubmission = submission
    updatedSubmission.updatedAt = Date()

    let data = try Firestore.Encoder().encode(updatedSubmission)
    try await collection.document(id).setData(data, merge: true)

    print("[FormSubmissionService] Updated submission: \(id)")
  }

  /// Save draft submission
  func saveDraft(_ submission: FormSubmission) async throws {
    var draft = submission
    draft.status = "draft"
    try await updateSubmission(draft)
  }

  /// Submit a form (change status from draft to submitted)
  func submitForm(_ submission: FormSubmission) async throws {
    var submitted = submission
    submitted.status = "submitted"
    submitted.submissionDate = Date()
    submitted.updatedAt = Date()

    try await updateSubmission(submitted)
    print("[FormSubmissionService] Submitted form: \(submission.id ?? "unknown")")
  }

  /// Delete a submission
  func deleteSubmission(id: String) async throws {
    guard let collection = userSubmissionsCollection else {
      throw FormSubmissionError.userNotAuthenticated
    }

    try await collection.document(id).delete()
    print("[FormSubmissionService] Deleted submission: \(id)")
  }

  // MARK: - Review & Scoring

  /// Review a submission
  func reviewSubmission(
    _ submission: FormSubmission,
    score: Double?,
    maxScore: Double?,
    feedback: String?
  ) async throws {
    guard let uid = Auth.auth().currentUser?.uid else {
      throw FormSubmissionError.userNotAuthenticated
    }

    var reviewed = submission
    reviewed.status = "reviewed"
    reviewed.score = score
    reviewed.maxScore = maxScore
    reviewed.feedback = feedback
    reviewed.reviewedBy = uid
    reviewed.reviewedAt = Date()
    reviewed.updatedAt = Date()

    try await updateSubmission(reviewed)
    print("[FormSubmissionService] Reviewed submission: \(submission.id ?? "unknown")")
  }

  /// Batch review multiple submissions
  func batchReview(
    submissions: [FormSubmission],
    score: Double?,
    maxScore: Double?,
    feedback: String?
  ) async throws {
    for submission in submissions {
      try await reviewSubmission(submission, score: score, maxScore: maxScore, feedback: feedback)
    }
  }

  // MARK: - Analytics

  /// Get submission analytics for an assignment
  func getAnalytics(for assignmentId: String) async throws -> SubmissionAnalytics {
    let submissions = try await fetchAssignmentSubmissions(assignmentId: assignmentId)

    let total = submissions.count
    let submitted = submissions.filter { $0.status == "submitted" || $0.status == "reviewed" }.count
    let reviewed = submissions.filter { $0.status == "reviewed" }.count
    let drafts = submissions.filter { $0.status == "draft" }.count

    let avgScore: Double? = {
      let scoredSubmissions = submissions.compactMap { $0.score }
      guard !scoredSubmissions.isEmpty else { return nil }
      return scoredSubmissions.reduce(0, +) / Double(scoredSubmissions.count)
    }()

    let avgCompletionPercentage = submissions.isEmpty ? 0 :
      submissions.map { $0.completionPercentage }.reduce(0, +) / Double(submissions.count)

    return SubmissionAnalytics(
      totalSubmissions: total,
      submittedCount: submitted,
      reviewedCount: reviewed,
      draftCount: drafts,
      averageScore: avgScore,
      averageCompletionPercentage: avgCompletionPercentage
    )
  }

  /// Export submissions to CSV
  func exportToCSV(submissions: [FormSubmission], assignmentName: String) async throws -> URL {
    var csvString = "Submission ID,Student ID,Status,Submission Date,Score,Feedback\n"

    for submission in submissions {
      let id = submission.id ?? "N/A"
      let studentId = submission.studentId ?? "N/A"
      let status = submission.status
      let date = DateFormatter.localizedString(from: submission.submissionDate, dateStyle: .short, timeStyle: .short)
      let score = submission.score.map { String($0) } ?? "N/A"
      let feedback = submission.feedback?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""

      csvString += "\"\(id)\",\"\(studentId)\",\"\(status)\",\"\(date)\",\"\(score)\",\"\(feedback)\"\n"
    }

    let fileName = "\(assignmentName.replacingOccurrences(of: " ", with: "_"))_submissions.csv"
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    try csvString.write(to: tempURL, atomically: true, encoding: .utf8)

    print("[FormSubmissionService] Exported \(submissions.count) submissions to CSV: \(tempURL.path)")
    return tempURL
  }

  // MARK: - Sample Data

  /// Get sample submissions for demo
  func getSampleSubmissions() -> [FormSubmission] {
    return [
      FormSubmission(
        formId: "form_001",
        data: [
          "question_1": AnyCodable("Response 1"),
          "question_2": AnyCodable("Response 2")
        ],
        submissionDate: Date(),
        assignmentId: "assignment_001",
        studentId: "student_001",
        status: "submitted"
      ),
      FormSubmission(
        formId: "form_001",
        data: [
          "question_1": AnyCodable("Response A"),
          "question_2": AnyCodable("Response B")
        ],
        submissionDate: Date().addingTimeInterval(-86400),
        assignmentId: "assignment_001",
        studentId: "student_002",
        status: "reviewed",
        score: 85,
        maxScore: 100,
        reviewedBy: "teacher_001",
        reviewedByName: "Demo Teacher",
        reviewedAt: Date(),
        feedback: "Great work! Clear and thoughtful responses."
      )
    ]
  }
}

// MARK: - Supporting Models

struct SubmissionAnalytics: Codable, Sendable {
  var totalSubmissions: Int
  var submittedCount: Int
  var reviewedCount: Int
  var draftCount: Int
  var averageScore: Double?
  var averageCompletionPercentage: Double

  var completionRate: Double {
    guard totalSubmissions > 0 else { return 0 }
    return Double(submittedCount) / Double(totalSubmissions) * 100
  }

  var reviewRate: Double {
    guard submittedCount > 0 else { return 0 }
    return Double(reviewedCount) / Double(submittedCount) * 100
  }
}

// MARK: - Error Handling

enum FormSubmissionError: Error, LocalizedError {
  case userNotAuthenticated
  case submissionNotFound(String)
  case invalidSubmission(String)
  case exportFailed(String)

  var errorDescription: String? {
    switch self {
    case .userNotAuthenticated:
      return "User not authenticated"
    case .submissionNotFound(let id):
      return "Submission not found: \(id)"
    case .invalidSubmission(let reason):
      return "Invalid submission: \(reason)"
    case .exportFailed(let reason):
      return "Export failed: \(reason)"
    }
  }
}
