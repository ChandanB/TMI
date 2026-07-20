//
//  StudentFormListView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI

struct StudentFormListView: View {
  @Environment(\.authStateModel) private var authStateModel

  @State private var assignments: [FormAssignment] = []
  @State private var submissions: [FormSubmission] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
  @State private var selectedAssignment: FormAssignment?
  @State private var showingCompletion = false

  var body: some View {
    ZStack {
      TMIBackgroundView(variant: .dashboard)

      if isLoading && assignments.isEmpty {
        ProgressView("Loading your forms...")
      } else {
        content
      }
    }
    .navigationTitle("My Forms")
    .navigationBarTitleDisplayMode(.large)
    .sheet(isPresented: $showingCompletion) {
      if let assignment = selectedAssignment {
        FormCompletionView(
          assignment: assignment,
          existingSubmission: getSubmission(for: assignment)
        )
        .tmiSheetStyle()
      }
    }
    .task {
      await loadData()
    }
    .refreshable {
      await loadData()
    }
    .alert("Error", isPresented: .constant(errorMessage != nil)) {
      Button("OK") {
        errorMessage = nil
      }
    } message: {
      if let error = errorMessage {
        Text(error)
      }
    }
  }

  // MARK: - Content

  private var content: some View {
    ScrollView {
      VStack(spacing: 16) {
        // Summary cards
        summarySection

        // Forms list
        if !assignments.isEmpty {
          formsSection
        } else {
          emptyState
        }
      }
      .padding()
    }
  }

  // MARK: - Summary

  private var summarySection: some View {
    HStack(spacing: 12) {
      SummaryCard(
        title: "Pending",
        count: pendingCount,
        color: .orange
      )

      SummaryCard(
        title: "Completed",
        count: completedCount,
        color: .green
      )

      SummaryCard(
        title: "Overdue",
        count: overdueCount,
        color: .red
      )
    }
  }

  // MARK: - Forms

  private var formsSection: some View {
    LazyVStack(spacing: 12) {
      Text("Your Assignments")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      ForEach(assignments) { assignment in
        StudentFormCard(
          assignment: assignment,
          submission: getSubmission(for: assignment),
          onTap: {
            selectedAssignment = assignment
            showingCompletion = true
          }
        )
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.text")
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text("No Forms Assigned")
        .font(.headline)

      Text("You don't have any forms to complete at this time")
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }

  // MARK: - Actions

  private func loadData() async {
    isLoading = true
    errorMessage = nil

    guard FeatureFlags.production.independentStudentAccounts else {
      assignments = []
      submissions = []
      errorMessage = "Student Mode is not available in this release."
      isLoading = false
      return
    }

    guard authStateModel.currentUser != nil else {
      errorMessage = "Sign in to view assigned forms."
      isLoading = false
      return
    }

    assignments = []
    submissions = []
    errorMessage = "Student Mode requires a trusted student session."
    isLoading = false
  }

  private func getSubmission(for assignment: FormAssignment) -> FormSubmission? {
    submissions.first { $0.assignmentId == assignment.id }
  }

  // MARK: - Computed Properties

  private var pendingCount: Int {
    assignments.filter { assignment in
      let submission = getSubmission(for: assignment)
      return submission == nil || submission?.status == "draft"
    }.count
  }

  private var completedCount: Int {
    submissions.filter { $0.status == "submitted" || $0.status == "reviewed" }.count
  }

  private var overdueCount: Int {
    assignments.filter { assignment in
      guard let dueDate = assignment.dueDate else { return false }
      let submission = getSubmission(for: assignment)
      let isIncomplete = submission == nil || submission?.status == "draft"
      return dueDate < Date() && isIncomplete
    }.count
  }
}

// MARK: - Summary Card

struct SummaryCard: View {
  let title: String
  let count: Int
  let color: Color

  var body: some View {
    VStack(spacing: 8) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)

      Text("\(count)")
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(color)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
  }
}

// MARK: - Student Form Card

struct StudentFormCard: View {
  let assignment: FormAssignment
  let submission: FormSubmission?
  let onTap: () -> Void

  private var status: String {
    if let submission {
      return submission.status
    }
    return "not_started"
  }

  private var statusColor: Color {
    switch status {
    case "not_started": return .gray
    case "draft": return .orange
    case "submitted": return .blue
    case "reviewed": return .green
    default: return .gray
    }
  }

  private var isOverdue: Bool {
    guard let dueDate = assignment.dueDate else { return false }
    return dueDate < Date() && (status == "not_started" || status == "draft")
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(assignment.templateName)
              .font(.headline)
              .foregroundColor(.primary)

            if let instructions = assignment.instructions {
              Text(instructions)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            }
          }

          Spacer()

          Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
        }

        Divider()

        HStack {
          // Status
          Label(status.capitalized, systemImage: "circle.fill")
            .font(.caption)
            .foregroundColor(statusColor)

          Spacer()

          // Due date
          if let dueDate = assignment.dueDate {
            Label(
              dueDate.formatted(date: .abbreviated, time: .omitted),
              systemImage: isOverdue ? "exclamationmark.triangle.fill" : "calendar"
            )
            .font(.caption)
            .foregroundColor(isOverdue ? .red : .secondary)
          }
        }

        // Score (if reviewed)
        if let submission, let score = submission.score, let maxScore = submission.maxScore {
          HStack {
            Text("Score:")
              .font(.caption)
              .foregroundColor(.secondary)

            Text("\(Int(score))/\(Int(maxScore))")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(.green)

            if let feedback = submission.feedback {
              Spacer()
              Text("Has feedback")
                .font(.caption2)
                .foregroundColor(.blue)
            }
          }
        }

        // Completion percentage (if draft)
        if status == "draft", let submission {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text("Progress")
                .font(.caption2)
                .foregroundColor(.secondary)

              Spacer()

              Text("\(Int(submission.completionPercentage))%")
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            ProgressView(value: submission.completionPercentage, total: 100)
              .tint(.orange)
          }
        }
      }
      .padding()
      .background(Color(UIColor.systemBackground))
      .cornerRadius(12)
      .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    StudentFormListView()
  }
}
