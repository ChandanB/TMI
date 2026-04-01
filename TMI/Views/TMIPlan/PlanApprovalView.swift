//
//  PlanApprovalView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #6
//  View for administrators to review and approve TMI plans
//

import SwiftUI

/// View for reviewing and approving TMI plans
struct PlanApprovalView: View {
    @Environment(\.authStateModel) private var authState

    @State private var pendingPlans: [TMIPlan] = []
    @State private var isLoading = false
    @State private var selectedPlan: TMIPlan?
    @State private var showingDetail = false
    @State private var statistics: PlanApprovalStatistics?

    private let approvalService = PlanApprovalService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Statistics header
            if let stats = statistics {
                statisticsHeader(stats)
            }

            // Content
            if isLoading {
                loadingView
            } else if pendingPlans.isEmpty {
                emptyView
            } else {
                plansList
            }
        }
        .background(TMIBackgroundView(variant: .default).ignoresSafeArea())
        .navigationTitle("Plan Approvals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPendingPlans()
        }
        .refreshable {
            await loadPendingPlans()
        }
        .sheet(isPresented: $showingDetail) {
            if let plan = selectedPlan {
                NavigationStack {
                    PlanApprovalDetailView(
                        plan: plan,
                        approvalService: approvalService,
                        onUpdate: {
                            Task { await loadPendingPlans() }
                        }
                    )
                }
                .tmiSheetStyle()
            }
        }
    }

    // MARK: - Statistics Header

    private func statisticsHeader(_ stats: PlanApprovalStatistics) -> some View {
        TMIGlassCard(style: .elevated) {
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    StatMetric(
                        title: "Pending",
                        value: "\(stats.pendingApprovalPlans)",
                        icon: "clock.fill",
                        color: .orange
                    )

                    Divider()
                        .frame(height: 40)

                    StatMetric(
                        title: "Approved",
                        value: "\(stats.approvedPlans)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    Divider()
                        .frame(height: 40)

                    StatMetric(
                        title: "Rate",
                        value: "\(Int(stats.approvalRate * 100))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .cyan
                    )
                }
            }
            .padding()
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Plans List

    private var plansList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(pendingPlans) { plan in
                    PendingPlanCard(plan: plan) {
                        selectedPlan = plan
                        showingDetail = true
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.green.opacity(0.5))

            Text("All caught up!")
                .font(.title2.bold())
                .foregroundColor(.white)

            Text("No plans pending approval")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading plans...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadPendingPlans() async {
        guard let user = authState.currentUser,
              let districtId = user.districtId else {
            return
        }

        isLoading = true

        do {
            pendingPlans = try await approvalService.fetchPendingApprovalPlans(districtId: districtId)
            statistics = try await approvalService.getApprovalStatistics(districtId: districtId)
        } catch {
            print("[PlanApprovalView] Failed to load pending plans: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Supporting Views

private struct StatMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color.gradient)

            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PendingPlanCard: View {
    let plan: TMIPlan
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TMIGlassCard(style: .default) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(plan.title)
                                .font(.headline)
                                .foregroundColor(.white)

                            Text(plan.model.rawValue)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.5))
                    }

                    // Students
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                        Text(plan.students.map { $0.firstName }.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(.white.opacity(0.7))

                    // Submitted date
                    if let submittedAt = plan.submittedForApprovalAt {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text("Submitted \(submittedAt.formatted(.relative(presentation: .named)))")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }

                    // Creator
                    HStack {
                        Text("Created by: \(plan.createdBy)")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))

                        Spacer()

                        Text("\(plan.goals.count) goals")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlanApprovalView()
    }
}
