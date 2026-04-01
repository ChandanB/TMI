//
//  PlanApprovalDetailView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #6
//  Detail view for reviewing and approving a TMI plan
//

import SwiftUI

/// Detail view for approving or rejecting a TMI plan
struct PlanApprovalDetailView: View {
    let plan: TMIPlan
    let approvalService: PlanApprovalService
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedAction: ApprovalActionType?
    @State private var comment = ""
    @State private var isProcessing = false
    @State private var showingExport = false
    @State private var exportURL: URL?

    private let exportService = PlanExportService()

    enum ApprovalActionType {
        case approve
        case reject
        case requestChanges
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Plan header
                planHeader

                // Plan details
                planDetails

                // Approval history
                if !plan.approvalHistory.isEmpty {
                    approvalHistorySection
                }

                // Action section
                actionSection
            }
            .padding()
        }
        .background(TMIBackgroundView(variant: .default).ignoresSafeArea())
        .navigationTitle("Review Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { Task { await exportToPDF() } }) {
                        Label("Export to PDF", systemImage: "doc.fill")
                    }

                    Button(action: { Task { await exportToText() } }) {
                        Label("Export to Text", systemImage: "doc.text.fill")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            if let url = exportURL {
                ActivityViewController(activityItems: [url])
                    .tmiSheetStyle()
            }
        }
    }

    // MARK: - Plan Header

    private var planHeader: some View {
        TMIGlassCard(style: .elevated) {
            VStack(alignment: .leading, spacing: 12) {
                Text(plan.title)
                    .font(.title2.bold())
                    .foregroundColor(.white)

                HStack {
                    Label(plan.model.rawValue, systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: plan.approvalStatus.icon)
                        Text(plan.approvalStatus.displayName)
                    }
                    .font(.caption.bold())
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.2))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }

    // MARK: - Plan Details

    private var planDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan Details")
                .font(.title3.bold())
                .foregroundColor(.white)

            TMIGlassCard(style: .default) {
                VStack(alignment: .leading, spacing: 16) {
                    // Description
                    if let description = plan.description, !description.isEmpty {
                        DetailRow(title: "Description", value: description)
                    }

                    // Students
                    DetailRow(
                        title: "Students",
                        value: plan.students.map { $0.name }.joined(separator: ", ")
                    )

                    // Goals
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Goals (\(plan.goals.count))")
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.8))

                        ForEach(plan.goals) { goal in
                            HStack {
                                Image(systemName: goalStatusIcon(goal.status))
                                    .foregroundColor(goalStatusColor(goal.status))

                                Text(goal.description)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))

                                Spacer()

                                Text("\(Int(goal.progress * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }

                    // Interests
                    if !plan.interests.isEmpty {
                        DetailRow(
                            title: "Interests",
                            value: plan.interests.map { $0.name }.joined(separator: ", ")
                        )
                    }

                    // Dates
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(plan.creationDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.9))
                        }

                        Spacer()

                        if let submittedAt = plan.submittedForApprovalAt {
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("Submitted")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                Text(submittedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Approval History

    private var approvalHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Approval History")
                .font(.title3.bold())
                .foregroundColor(.white)

            TMIGlassCard(style: .elevated) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(plan.approvalHistory.enumerated()), id: \.offset) { index, entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: actionIcon(entry.action))
                                    .foregroundColor(actionColor(entry.action))

                                Text(entry.action.displayName)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)

                                Spacer()

                                Text(entry.timestamp.formatted(.relative(presentation: .named)))
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.6))
                            }

                            if let comment = entry.comment, !comment.isEmpty {
                                Text("\"\(comment)\"")
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.leading, 8)
                            }

                            Text("By: \(entry.actionBy)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.bottom, index < plan.approvalHistory.count - 1 ? 12 : 0)

                        if index < plan.approvalHistory.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Actions")
                .font(.title3.bold())
                .foregroundColor(.white)

            // Comment field
            TMIGlassCard(style: .default) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comment (Optional)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.8))

                    TextField("Add your feedback here...", text: $comment, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(4...8)
                }
                .padding()
            }

            // Action buttons
            VStack(spacing: 12) {
                // Approve
                Button(action: { performAction(.approve) }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve Plan")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.gradient)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .font(.headline)
                }
                .disabled(isProcessing)

                HStack(spacing: 12) {
                    // Request Changes
                    Button(action: { performAction(.requestChanges) }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Request Changes")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .font(.subheadline.bold())
                    }
                    .disabled(isProcessing)

                    // Reject
                    Button(action: { performAction(.reject) }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Reject")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.gradient)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .font(.subheadline.bold())
                    }
                    .disabled(isProcessing)
                }
            }

            if isProcessing {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Text("Processing...")
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding()
            }
        }
    }

    // MARK: - Helper Views

    private struct DetailRow: View {
        let title: String
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))

                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    // MARK: - Actions

    private func performAction(_ action: ApprovalActionType) {
        selectedAction = action
        isProcessing = true

        Task {
            do {
                switch action {
                case .approve:
                    try await approvalService.approvePlan(
                        plan: plan,
                        comment: comment.isEmpty ? nil : comment
                    )

                case .reject:
                    guard !comment.isEmpty else {
                        await MainActor.run {
                            isProcessing = false
                        }
                        return
                    }
                    try await approvalService.rejectPlan(
                        plan: plan,
                        reason: comment
                    )

                case .requestChanges:
                    guard !comment.isEmpty else {
                        await MainActor.run {
                            isProcessing = false
                        }
                        return
                    }
                    try await approvalService.requestChanges(
                        plan: plan,
                        feedback: comment
                    )
                }

                await MainActor.run {
                    isProcessing = false
                    onUpdate()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                }
                print("[PlanApprovalDetailView] Failed to perform action: \(error)")
            }
        }
    }

    private func exportToPDF() async {
        do {
            let url = try await exportService.exportPlanToPDF(plan)
            await MainActor.run {
                exportURL = url
                showingExport = true
            }
        } catch {
            print("[PlanApprovalDetailView] Failed to export PDF: \(error)")
        }
    }

    private func exportToText() async {
        do {
            let url = try await exportService.exportPlanToText(plan)
            await MainActor.run {
                exportURL = url
                showingExport = true
            }
        } catch {
            print("[PlanApprovalDetailView] Failed to export text: \(error)")
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch plan.approvalStatus {
        case .draft: return .gray
        case .pendingApproval: return .orange
        case .approved: return .green
        case .rejected: return .red
        case .changesRequested: return .yellow
        }
    }

    private func goalStatusIcon(_ status: GoalStatus) -> String {
        switch status {
        case .notStarted: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        }
    }

    private func goalStatusColor(_ status: GoalStatus) -> Color {
        switch status {
        case .notStarted: return .gray
        case .inProgress: return .orange
        case .completed: return .green
        }
    }

    private func actionIcon(_ action: ApprovalAction) -> String {
        switch action {
        case .submitted: return "arrow.up.circle.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .changesRequested: return "exclamationmark.triangle.fill"
        case .resubmitted: return "arrow.clockwise.circle.fill"
        }
    }

    private func actionColor(_ action: ApprovalAction) -> Color {
        switch action {
        case .submitted: return .blue
        case .approved: return .green
        case .rejected: return .red
        case .changesRequested: return .orange
        case .resubmitted: return .cyan
        }
    }
}

// MARK: - Activity View Controller

#if canImport(UIKit)
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
struct ActivityViewController: View {
    let activityItems: [Any]

    var body: some View {
        if let url = activityItems.first as? URL {
            ShareLink(item: url) {
                Label("Share Export", systemImage: "square.and.arrow.up")
            }
            .padding()
        } else {
            Text("Sharing is unavailable for this item.")
                .padding()
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    NavigationStack {
        PlanApprovalDetailView(
            plan: .samplePlan,
            approvalService: .shared,
            onUpdate: {}
        )
    }
}
