//
//  StaffAnalyticsView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #4
//

import SwiftUI
import Charts

struct StaffAnalyticsView: View {
    let assignment: FormAssignment
    @State private var submissions: [FormSubmission] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Need a way to fetch submissions for this assignment.
    // Using FormSubmissionService or FormAssignmentService? AssignmentService typically aggregates.
    // Let's assume FormSubmissionService has `fetchAssignmentSubmissions` which we created earlier.
    private let submissionService = FormSubmissionService()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Summary Cards
                summarySection
                
                // Charts
                if !submissions.isEmpty {
                    chartsSection
                }
                
                // Student List
                studentListSection
            }
            .padding()
        }
        .navigationTitle(assignment.templateName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }
    
    // MARK: - Sections
    
    private var summarySection: some View {
        HStack(spacing: 16) {
            StatCard(title: "Assigned", value: "\(assignment.totalAssigned)", icon: "person.3.fill", color: .blue)
            StatCard(title: "Submitted", value: "\(submissions.count)", icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Reviewed", value: "\(assignment.totalReviewed)", icon: "eye.fill", color: .orange)
        }
    }
    
    private var chartsSection: some View {
        VStack(alignment: .leading) {
            Text("Completion Progress")
                .font(.headline)
            
            Chart {
                BarMark(
                    x: .value("Status", "Submitted"),
                    y: .value("Count", submissions.count)
                )
                .foregroundStyle(Color.green)
                
                BarMark(
                    x: .value("Status", "Pending"),
                    y: .value("Count", max(0, assignment.totalAssigned - submissions.count))
                )
                .foregroundStyle(Color.gray.opacity(0.3))
            }
            .frame(height: 200)
            
            if let avgScore = averageScore {
                Text("Average Score: \(String(format: "%.1f", avgScore))%")
                    .padding(.top)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var studentListSection: some View {
        VStack(alignment: .leading) {
            Text("Submissions")
                .font(.headline)
            
            if submissions.isEmpty {
                Text("No submissions yet.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(submissions) { submission in
                    VStack(alignment: .leading) {
                        HStack {
                            Text(submission.studentId ?? "Unknown Student") // Ideally resolve name
                                .font(.body)
                            Spacer()
                            Text(submission.submissionDate.formatted(date: .numeric, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            SubmissionStatusBadge(status: submission.status)
                            Spacer()
                            if let score = submission.score {
                                Text("Score: \(Int(score))")
                                    .font(.caption)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private var averageScore: Double? {
        let scoredSubmissions = submissions.compactMap { $0.score }
        guard !scoredSubmissions.isEmpty else { return nil }
        return scoredSubmissions.reduce(0, +) / Double(scoredSubmissions.count)
    }
    
    private func loadData() async {
        guard let assignmentId = assignment.id else { return }
        isLoading = true
        do {
            submissions = try await submissionService.fetchAssignmentSubmissions(assignmentId: assignmentId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    
    // MARK: - Helper Views
    
    struct SubmissionStatusBadge: View {
        let status: String
        
        var color: Color {
            switch status.lowercased() {
            case "submitted": return .green
            case "reviewed": return .blue
            case "draft", "pending": return .orange
            default: return .gray
            }
        }
        
        var body: some View {
            Text(status.capitalized)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(color.opacity(0.2))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(color.opacity(0.4), lineWidth: 1)
                )
        }
    }
}
