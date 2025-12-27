//
//  FormAssignmentViewModel.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import Foundation
import Observation
import FirebaseFirestore
import FirebaseAuth

@Observable
@MainActor
class FormAssignmentViewModel {
  // Services
  private let assignmentService = FormAssignmentService()
  private let submissionService = FormSubmissionService()

  // State
  var assignments: [FormAssignment] = []
  var filteredAssignments: [FormAssignment] = []
  var selectedAssignment: FormAssignment?

  // UI State
  var isLoading = false
  var errorMessage: String?
  var searchText = ""
  var showActiveOnly = true

  // Analytics
  var submissionAnalytics: [String: SubmissionAnalytics] = [:] // Assignment ID -> Analytics

  // MARK: - Data Fetching

  func loadAssignments() async {
    isLoading = true
    errorMessage = nil
    
    guard let uid = Auth.auth().currentUser?.uid else {
        errorMessage = "User not authenticated"
        isLoading = false
        return
    }

    do {
      // Always fetch all assignments created by user, then filter locally
      assignments = try await assignmentService.fetchAssignmentsCreatedBy(userId: uid)
      applyFilters()
      print("[FormAssignmentViewModel] Loaded \(assignments.count) assignments")
    } catch {
      errorMessage = "Failed to load assignments: \(error.localizedDescription)"
      print("[FormAssignmentViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func refreshAssignments() async {
    await loadAssignments()
  }

  // MARK: - Filtering & Search

  func applyFilters() {
    var results = assignments
      
    // Filter by active status
    if showActiveOnly {
        results = results.filter { $0.isActive }
    }

    // Apply search
    if !searchText.isEmpty {
      results = results.filter { assignment in
        assignment.templateName.localizedCaseInsensitiveContains(searchText) ||
          assignment.cohort.displayName.localizedCaseInsensitiveContains(searchText)
      }
    }

    filteredAssignments = results.sorted { $0.createdAt > $1.createdAt }
  }

  func updateSearch(_ text: String) {
    searchText = text
    applyFilters()
  }

  func toggleActiveFilter() {
    showActiveOnly.toggle()
    applyFilters()
  }

  func clearFilters() {
    searchText = ""
    applyFilters()
  }

  // MARK: - Assignment Operations

  func createAssignment(_ assignment: FormAssignment) async {
    isLoading = true
    errorMessage = nil

    do {
      let newAssignment = try await assignmentService.createAssignment(assignment)
      assignments.append(newAssignment)
      applyFilters()
      print("[FormAssignmentViewModel] Created assignment: \(newAssignment.templateName)")
    } catch {
      errorMessage = "Failed to create assignment: \(error.localizedDescription)"
      print("[FormAssignmentViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func updateAssignment(_ assignment: FormAssignment) async {
    isLoading = true
    errorMessage = nil

    do {
      try await assignmentService.updateAssignment(assignment)

      // Update in local array
      if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
        assignments[index] = assignment
        applyFilters()
      }

      print("[FormAssignmentViewModel] Updated assignment: \(assignment.templateName)")
    } catch {
      errorMessage = "Failed to update assignment: \(error.localizedDescription)"
      print("[FormAssignmentViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func deleteAssignment(_ assignment: FormAssignment) async {
    guard let id = assignment.id else { return }

    isLoading = true
    errorMessage = nil

    do {
      try await assignmentService.deleteAssignment(id: id)

      // Remove from local array
      assignments.removeAll { $0.id == id }
      applyFilters()

      print("[FormAssignmentViewModel] Deleted assignment: \(id)")
    } catch {
      errorMessage = "Failed to delete assignment: \(error.localizedDescription)"
      print("[FormAssignmentViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  func deactivateAssignment(_ assignment: FormAssignment) async {
    isLoading = true
    errorMessage = nil

    do {
      try await assignmentService.deactivateAssignment(assignment)

      // Update in local array
      if let index = assignments.firstIndex(where: { $0.id == assignment.id }) {
        assignments[index].isActive = false
        applyFilters()
      }

      print("[FormAssignmentViewModel] Deactivated assignment: \(assignment.templateName)")
    } catch {
      errorMessage = "Failed to deactivate assignment: \(error.localizedDescription)"
      print("[FormAssignmentViewModel] Error: \(errorMessage ?? "Unknown")")
    }

    isLoading = false
  }

  // MARK: - Analytics

  func loadAnalytics(for assignmentId: String) async {
    do {
      let analytics = try await submissionService.getAnalytics(for: assignmentId)
      submissionAnalytics[assignmentId] = analytics
      print("[FormAssignmentViewModel] Loaded analytics for assignment: \(assignmentId)")
    } catch {
      print("[FormAssignmentViewModel] Failed to load analytics: \(error.localizedDescription)")
    }
  }

  func getCompletionRate(for assignment: FormAssignment) -> Double {
    guard assignment.totalAssigned > 0 else { return 0 }
    return Double(assignment.totalSubmitted) / Double(assignment.totalAssigned) * 100
  }

  func getReviewRate(for assignment: FormAssignment) -> Double {
    guard assignment.totalSubmitted > 0 else { return 0 }
    return Double(assignment.totalReviewed) / Double(assignment.totalSubmitted) * 100
  }

  // MARK: - Computed Properties

  var hasAssignments: Bool {
    !assignments.isEmpty
  }

  var hasFilteredResults: Bool {
    !filteredAssignments.isEmpty
  }

  var overdueAssignments: [FormAssignment] {
    assignments.filter { assignment in
      guard let dueDate = assignment.dueDate else { return false }
      return dueDate < Date() && assignment.isActive
    }
  }

  var upcomingAssignments: [FormAssignment] {
    assignments.filter { assignment in
      guard let dueDate = assignment.dueDate else { return false }
      return dueDate >= Date() && assignment.isActive
    }
  }
}
