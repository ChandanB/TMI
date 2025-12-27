//
//  SubmissionReviewView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI

struct SubmissionReviewView: View {
  @Environment(\.dismiss) private var dismiss
  let submission: FormSubmission
  let assignment: FormAssignment

  @State private var score: String = ""
  @State private var maxScore: String = "100"
  @State private var feedback: String = ""
  @State private var isSaving = false

  private let submissionService = FormSubmissionService()

  var body: some View {
    NavigationStack {
      ZStack {
        TMIBackgroundView(variant: .dashboard)

        ScrollView {
          VStack(spacing: 20) {
            // Submission info
            submissionInfo

            // Submission data
            submissionDataSection

            // Review section
            if assignment.requiresReview {
              reviewSection
            }
          }
          .padding()
        }
      }
      .navigationTitle("Review Submission")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Close") {
            dismiss()
          }
        }

        if assignment.requiresReview && submission.status != "reviewed" {
          ToolbarItem(placement: .confirmationAction) {
            Button("Submit Review") {
              Task {
                await submitReview()
              }
            }
            .disabled(isSaving)
          }
        }
      }
      .onAppear {
        if let existingScore = submission.score {
          score = String(format: "%.0f", existingScore)
        }
        if let existingMax = submission.maxScore {
          maxScore = String(format: "%.0f", existingMax)
        }
        feedback = submission.feedback ?? ""
      }
    }
  }

  // MARK: - Submission Info

  private var submissionInfo: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Student")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(submission.studentId ?? "Unknown")
            .font(.subheadline)
            .fontWeight(.medium)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("Submitted")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(submission.submissionDate.formatted(date: .abbreviated, time: .shortened))
            .font(.subheadline)
        }
      }

      Divider()

      HStack {
        Label(submission.status.capitalized, systemImage: "circle.fill")
          .font(.caption)
          .foregroundColor(statusColor)

        Spacer()

        if let completion = submission.completionPercentage as Double? {
          Text("\(Int(completion))% complete")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      if let reviewedBy = submission.reviewedByName, let reviewedAt = submission.reviewedAt {
        Divider()

        VStack(alignment: .leading, spacing: 4) {
          Text("Reviewed by \(reviewedBy)")
            .font(.caption)
            .foregroundColor(.secondary)

          Text(reviewedAt.formatted(date: .abbreviated, time: .shortened))
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
  }

  // MARK: - Submission Data

  private var submissionDataSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Responses")
        .font(.headline)

      ForEach(Array(submission.data.keys.sorted()), id: \.self) { key in
        VStack(alignment: .leading, spacing: 4) {
          Text(formatFieldLabel(key))
            .font(.caption)
            .foregroundColor(.secondary)

          if let value = submission.data[key]?.value {
            Text(formatFieldValue(value))
              .font(.subheadline)
              .padding(.vertical, 8)
              .padding(.horizontal, 12)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color(UIColor.secondarySystemBackground))
              .cornerRadius(8)
          }
        }
      }
    }
  }

  // MARK: - Review Section

  private var reviewSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Review")
        .font(.headline)

      // Score
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Score")
            .font(.caption)
            .foregroundColor(.secondary)

          TextField("Score", text: $score)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
        }

        Text("/")
          .font(.title3)
          .foregroundColor(.secondary)

        VStack(alignment: .leading, spacing: 4) {
          Text("Max Score")
            .font(.caption)
            .foregroundColor(.secondary)

          TextField("Max", text: $maxScore)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
        }
      }

      // Feedback
      VStack(alignment: .leading, spacing: 4) {
        Text("Feedback")
          .font(.caption)
          .foregroundColor(.secondary)

        TextEditor(text: $feedback)
          .frame(minHeight: 100)
          .padding(8)
          .background(Color(UIColor.secondarySystemBackground))
          .cornerRadius(8)
      }
    }
    .padding()
    .background(Color(UIColor.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
  }

  // MARK: - Actions

  private func submitReview() async {
    isSaving = true

    let scoreValue = Double(score)
    let maxScoreValue = Double(maxScore)

    do {
      try await submissionService.reviewSubmission(
        submission,
        score: scoreValue,
        maxScore: maxScoreValue,
        feedback: feedback.isEmpty ? nil : feedback
      )

      dismiss()
    } catch {
      print("[SubmissionReviewView] Error submitting review: \(error.localizedDescription)")
    }

    isSaving = false
  }

  // MARK: - Helpers

  private var statusColor: Color {
    switch submission.status {
    case "draft": return .orange
    case "submitted": return .blue
    case "reviewed": return .green
    default: return .gray
    }
  }

  private func formatFieldLabel(_ key: String) -> String {
    // Convert "question_1" to "Question 1"
    key.replacingOccurrences(of: "_", with: " ").capitalized
  }

  private func formatFieldValue(_ value: Any) -> String {
    if let string = value as? String {
      return string
    } else if let number = value as? Int {
      return String(number)
    } else if let double = value as? Double {
      return String(format: "%.2f", double)
    } else if let bool = value as? Bool {
      return bool ? "Yes" : "No"
    }
    return String(describing: value)
  }
}

#Preview {
  SubmissionReviewView(
    submission: FormSubmission(
      formId: "form_001",
      data: [
        "question_1": AnyCodable("This is my response to question 1"),
        "question_2": AnyCodable("This is my response to question 2"),
        "question_3": AnyCodable(42)
      ],
      assignmentId: "assignment_001",
      studentId: "John Doe",
      status: "submitted"
    ),
    assignment: FormAssignment(
      templateId: "template_001",
      templateName: "Student Intake",
      assignedBy: "teacher_001",
      cohort: .allStudents,
      requiresReview: true
    )
  )
}
