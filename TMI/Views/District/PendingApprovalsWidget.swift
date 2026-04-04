//
//  PendingApprovalsWidget.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #6
//  Widget showing pending plan approvals on district dashboard
//

import SwiftUI

/// Widget displaying pending plan approvals for district dashboard
struct PendingApprovalsWidget: View {
    let districtId: String

    @State private var pendingPlans: [TMIPlan] = []
    @State private var isLoading = false

    private let approvalService = PlanApprovalService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(.orange)

                    Text("Pending Approvals")
                        .font(.title3.bold())
                        .foregroundColor(Color.tmiTextPrimary)
                }

                Spacer()

                if !pendingPlans.isEmpty {
                    Text("\(pendingPlans.count)")
                        .font(.caption.bold())
                        .foregroundColor(Color.tmiTextPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(12)
                }

                NavigationLink(destination: PlanApprovalView()) {
                    HStack(spacing: 4) {
                        Text("View All")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.cyan)
                }
            }

            // Content
            if isLoading {
                loadingView
            } else if pendingPlans.isEmpty {
                emptyView
            } else {
                plansPreview
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.tmiSurface)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .task {
            await loadPendingPlans()
        }
    }

    // MARK: - Plans Preview

    private var plansPreview: some View {
        VStack(spacing: 10) {
            ForEach(Array(pendingPlans.prefix(3).enumerated()), id: \.element.id) { index, plan in
                NavigationLink(destination: PlanApprovalDetailView(
                    plan: plan,
                    approvalService: approvalService,
                    onUpdate: { Task { await loadPendingPlans() } }
                )) {
                    HStack(spacing: 12) {
                        // Priority indicator
                        ZStack {
                            Circle()
                                .fill(urgencyColor(for: plan).opacity(0.2))
                                .frame(width: 40, height: 40)

                            Image(systemName: urgencyIcon(for: plan))
                                .foregroundColor(urgencyColor(for: plan))
                        }

                        // Plan info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title)
                                .font(.subheadline.bold())
                                .foregroundColor(Color.tmiTextPrimary)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                Text(plan.model.rawValue)
                                    .font(.caption2)

                                Text("•")
                                    .font(.caption2)

                                if let submittedAt = plan.submittedForApprovalAt {
                                    Text(submittedAt.formatted(.relative(presentation: .named)))
                                        .font(.caption2)
                                }
                            }
                            .foregroundColor(Color.tmiTextSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(Color.tmiTextTertiary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            // Show more indicator
            if pendingPlans.count > 3 {
                NavigationLink(destination: PlanApprovalView()) {
                    HStack {
                        Spacer()
                        Text("+ \(pendingPlans.count - 3) more")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.title2)
                    .foregroundColor(.green.opacity(0.6))

                Text("No pending approvals")
                    .font(.subheadline)
                    .foregroundColor(Color.tmiTextSecondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(.white)
            Text("Loading...")
                .font(.caption)
                .foregroundColor(Color.tmiTextSecondary)
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadPendingPlans() async {
        isLoading = true

        do {
            pendingPlans = try await approvalService.fetchPendingApprovals(districtId: districtId)
        } catch {
            print("[PendingApprovalsWidget] Failed to load pending plans: \(error)")
        }

        isLoading = false
    }

    // MARK: - Helpers

    private func urgencyColor(for plan: TMIPlan) -> Color {
        guard let submittedAt = plan.submittedForApprovalAt else { return .gray }

        let daysSinceSubmission = Date().timeIntervalSince(submittedAt) / 86400

        if daysSinceSubmission > 7 {
            return .red
        } else if daysSinceSubmission > 3 {
            return .orange
        } else {
            return .yellow
        }
    }

    private func urgencyIcon(for plan: TMIPlan) -> String {
        guard let submittedAt = plan.submittedForApprovalAt else { return "clock" }

        let daysSinceSubmission = Date().timeIntervalSince(submittedAt) / 86400

        if daysSinceSubmission > 7 {
            return "exclamationmark.3"
        } else if daysSinceSubmission > 3 {
            return "exclamationmark.2"
        } else {
            return "clock.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScrollView {
            PendingApprovalsWidget(districtId: "sample_district")
                .padding()
        }
        .background(TMIBackgroundView(variant: TMIBackgroundView.BackgroundVariant.base))
    }
}
