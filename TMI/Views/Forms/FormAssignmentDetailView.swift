//
//  FormAssignmentDetailView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI

struct FormAssignmentDetailView: View {
  @Environment(\.dismiss) private var dismiss
  let assignment: FormAssignment
  let viewModel: FormAssignmentViewModel

  @State private var submissions: [FormSubmission] = []
  @State private var analytics: SubmissionAnalytics?
  @State private var isLoadingSubmissions = false
  @State private var selectedSubmission: FormSubmission?

  private let submissionService = FormSubmissionService()

  var body: some View {
    NavigationStack {
      ZStack {
        TMIBackgroundView(variant: .dashboard)

        ScrollView {
          VStack(spacing: 20) {
            // Assignment info
            assignmentInfo

            // Analytics
            if let analytics {
              analyticsSection(analytics)
            }

            // Submissions list
            submissionsSection
          }
          .padding()
        }
      }
      .navigationTitle(assignment.templateName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button {
              Task {
                await exportSubmissions()
              }
            } label: {
              Label("Export CSV", systemImage: "square.and.arrow.up")
            }

            Button {
              Task {
                await viewModel.deactivateAssignment(assignment)
                dismiss()
              }
            } label: {
              Label("Deactivate", systemImage: "pause.circle")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
      .sheet(item: $selectedSubmission) { submission in
        SubmissionReviewView(submission: submission, assignment: assignment)
          .tmiSheetStyle()
      }
      .task {
        await loadData()
      }
    }
  }

  // MARK: - Assignment Info

  private var assignmentInfo: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Cohort
      HStack {
        Label(assignment.cohort.displayName, systemImage: "person.2.fill")
          .font(.subheadline)
          .foregroundColor(.secondary)

        Spacer()

        if let dueDate = assignment.dueDate {
          Label(
            dueDate.formatted(date: .abbreviated, time: .omitted),
            systemImage: "calendar"
          )
          .font(.caption)
          .foregroundColor(dueDate < Date() ? .red : .secondary)
        }
      }

      // Instructions
      if let instructions = assignment.instructions {
        VStack(alignment: .leading, spacing: 4) {
          Text("Instructions")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(instructions)
            .font(.subheadline)
        }
      }

      Divider()

      // Options
      HStack(spacing: 16) {
        if assignment.allowLateSubmissions {
          Label("Late OK", systemImage: "clock.badge.checkmark")
            .font(.caption2)
            .foregroundColor(.green)
        }

        if assignment.requiresReview {
          Label("Review Required", systemImage: "eye")
            .font(.caption2)
            .foregroundColor(.blue)
        }

        Spacer()
      }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
  }

  // MARK: - Analytics

  private func analyticsSection(_ analytics: SubmissionAnalytics) -> some View {
    VStack(spacing: 12) {
      Text("Submission Analytics")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        AssignmentStatCard(
          title: "Completion",
          value: "\(Int(analytics.completionRate))%",
          subtitle: "\(analytics.submittedCount)/\(analytics.totalSubmissions)",
          color: .blue
        )

        AssignmentStatCard(
          title: "Reviewed",
          value: "\(Int(analytics.reviewRate))%",
          subtitle: "\(analytics.reviewedCount)/\(analytics.submittedCount)",
          color: .green
        )

        AssignmentStatCard(
          title: "Drafts",
          value: "\(analytics.draftCount)",
          subtitle: "In progress",
          color: .orange
        )

        if let avgScore = analytics.averageScore {
          AssignmentStatCard(
            title: "Avg Score",
            value: String(format: "%.1f", avgScore),
            subtitle: "Out of 100",
            color: .purple
          )
        }
      }
    }
  }

  // MARK: - Submissions

  private var submissionsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Submissions (\(submissions.count))")
        .font(.headline)

      if isLoadingSubmissions {
        ProgressView()
      } else if submissions.isEmpty {
        Text("No submissions yet")
          .font(.subheadline)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding()
      } else {
        LazyVStack(spacing: 8) {
          ForEach(submissions) { submission in
            SubmissionRow(submission: submission) {
              selectedSubmission = submission
            }
          }
        }
      }
    }
  }

  // MARK: - Actions

  private func loadData() async {
    guard let assignmentId = assignment.id else { return }

    isLoadingSubmissions = true

    async let submissionsTask = submissionService.fetchSubmissions()
    async let analyticsTask = submissionService.getAnalytics(for: assignmentId)

    do {
      submissions = try await submissionsTask
      analytics = try await analyticsTask
    } catch {
      print("[FormAssignmentDetailView] Error loading data: \(error.localizedDescription)")
    }

    isLoadingSubmissions = false
  }

  private func exportSubmissions() async {
    do {
      let url = try await submissionService.exportToCSV(
        submissions: submissions,
        assignmentName: assignment.templateName
      )
      print("[FormAssignmentDetailView] Exported to: \(url.path)")
      // Would show share sheet here
    } catch {
      print("[FormAssignmentDetailView] Export failed: \(error.localizedDescription)")
    }
  }
}

// MARK: - Stat Card

struct AssignmentStatCard: View {
  let title: String
  let value: String
  let subtitle: String
  let color: Color

  var body: some View {
    VStack(spacing: 8) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)

      Text(value)
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(color)

      Text(subtitle)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
  }
}

// MARK: - Submission Row

struct SubmissionRow: View {
  let submission: FormSubmission
  let onTap: () -> Void

  private var statusColor: Color {
    switch submission.status {
    case "not_started": return .gray
    case "draft": return .orange
    case "submitted": return .blue
    case "reviewed": return .green
    default: return .gray
    }
  }

  var body: some View {
    Button(action: onTap) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(submission.studentId ?? "Unknown Student")
            .font(.subheadline)
            .fontWeight(.medium)

          Text(submission.submissionDate.formatted(date: .abbreviated, time: .shortened))
            .font(.caption2)
            .foregroundColor(.secondary)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text(submission.status.capitalized)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(statusColor)

          if let score = submission.score {
            Text("\(Int(score))%")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }

        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 8)
      .padding(.horizontal, 12)
      .background(Color(UIColor.secondarySystemBackground))
      .cornerRadius(8)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  FormAssignmentDetailView(
    assignment: FormAssignment(
      templateId: "template_001",
      templateName: "Student Intake Form",
      assignedBy: "user_001",
      cohort: .grade(grade: "9"),
      requiresReview: true,
      totalAssigned: 25,
      totalSubmitted: 18,
      totalReviewed: 12
    ),
    viewModel: FormAssignmentViewModel()
  )
}
