//
//  DashboardHeaderView.swift
//  TMI
//
//  Created by TMI App.
//

import SwiftUI

struct DashboardHeaderView: View {
    let data: DashboardData
    let attentionCount: Int
    let onNavigateToStudents: () -> Void
    let onNavigateToPlans: () -> Void
    
    private var surveysPending: Int {
        max(0, data.totalStudents - data.surveysCompleted)
    }
    
    private var plansPending: Int {
        max(0, data.totalStudents - data.plansAligned)
    }
    
    private var status: DashboardStatus {
        computeDashboardStatus(data: data, attentionCount: attentionCount, surveysPending: surveysPending, plansPending: plansPending)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.lg) {
            // Header: Status + Totals with enhanced visual hierarchy
            HStack(alignment: .center, spacing: TMISpacing.md) {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.15))
                        .frame(width: 52, height: 52)

                    Circle()
                        .stroke(status.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 52, height: 52)

                    Image(systemName: status.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(status.color)
                        .symbolEffect(.pulse, options: .repeating, value: status.status == .needsSupport || status.status == .actionNeeded)
                }
                .shadow(color: status.color.opacity(0.2), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 6) {
                    // Enhanced student count display
                    HStack(spacing: 10) {
                        Text("\(data.totalStudents)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.tmiTextPrimary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Students")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.tmiTextSecondary)

                            if max(attentionCount, surveysPending + plansPending) > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.tmiWarning)
                                    Text("\(max(attentionCount, surveysPending + plansPending)) Ready to Grow")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.tmiWarning)
                                }
                            }
                        }
                    }

                    // Enhanced status message with emoji
                    Text(status.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.tmiTextSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.bottom, 4)

            TMIDivider()

            // Priority Actions with enhanced interactivity
            if surveysPending > 0 || plansPending > 0 {
                VStack(alignment: .leading, spacing: TMISpacing.md) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.tmiWarning)
                        Text("Priority Actions")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.tmiTextSecondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                    }

                    VStack(alignment: .leading, spacing: TMISpacing.sm) {
                        if surveysPending > 0 {
                            PriorityActionButton(
                                icon: "chart.bar.doc.horizontal",
                                iconColor: .tmiWarning,
                                title: "Surveys Pending",
                                count: surveysPending,
                                action: onNavigateToStudents
                            )
                        }

                        if plansPending > 0 {
                            PriorityActionButton(
                                icon: "doc.text.magnifyingglass",
                                iconColor: .tmiSecondary,
                                title: "Plans Needed",
                                count: plansPending,
                                action: onNavigateToStudents
                            )
                        }
                    }
                }

                TMIDivider()
            } else {
                // Success state with celebration
                HStack(spacing: TMISpacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.tmiSuccess.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.tmiSuccess)
                            .symbolEffect(.bounce, options: .repeating.speed(0.5))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Excellent Progress!")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.tmiSuccess)

                        Text("All students have personalized pathways and surveys completed")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.tmiTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
                .padding(TMISpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: TMIRadius.md)
                        .fill(Color.tmiSuccess.opacity(0.08))
                )

                TMIDivider()
            }

            // Supporting Metrics with enhanced design
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                Text("Key Metrics")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.tmiTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                VStack(spacing: TMISpacing.sm) {
                    MetricPill(
                        icon: "doc.text.fill",
                        tint: .tmiSuccess,
                        value: "\(data.activeTMIPlans)",
                        label: "Active TMI Plans",
                        subtitle: data.totalStudents > 0 ? "\(Int(Double(data.activeTMIPlans) / Double(data.totalStudents) * 100))% coverage" : "No students yet",
                        action: onNavigateToPlans
                    )

                    MetricPill(
                        icon: "chart.bar.fill",
                        tint: .tmiPrimary,
                        value: "\(data.surveysCompleted)/\(data.totalStudents)",
                        label: "Surveys Completed",
                        subtitle: surveysPending > 0 ? "\(surveysPending) remaining" : "All complete!",
                        action: onNavigateToStudents
                    )

                    MetricPill(
                        icon: "checkmark.seal.fill",
                        tint: .tmiSecondary,
                        value: "\(data.plansAligned)",
                        label: "Plans Aligned with Goals",
                        subtitle: data.totalStudents > 0 ? "\(Int(Double(data.plansAligned) / Double(data.totalStudents) * 100))% aligned" : "Ready to start",
                        action: onNavigateToPlans
                    )
                }
            }
        }
        .padding(TMISpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .fill(Color.tmiSurface)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
                .shadow(color: status.color.opacity(0.1), radius: 24, x: 0, y: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TMIRadius.lg)
                .strokeBorder(
                    LinearGradient(
                        colors: [status.color.opacity(0.2), status.color.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Helper Types and Methods
    
    private enum DashboardStatusType {
        case onTrack, actionNeeded, growing, needsSupport
    }
    
    private struct DashboardStatus {
        let status: DashboardStatusType
        let title: String
        let icon: String
        let color: Color
    }
    
    private func computeDashboardStatus(data: DashboardData, attentionCount: Int, surveysPending: Int, plansPending: Int) -> DashboardStatus {
        // Determine status based on urgency signals with improved logic
        if attentionCount >= 2 {
            return DashboardStatus(status: .needsSupport, title: "🚨 Needs Support — multiple students at risk", icon: "exclamationmark.triangle.fill", color: .tmiError)
        }
        if surveysPending > 0 || plansPending > 0 {
             return DashboardStatus(status: .actionNeeded, title: "⚡ Action Needed — missing surveys or unassigned pathways", icon: "bolt.fill", color: .tmiWarning)
        }
        // If engagement is trending up or plans exist but not all, call it growing
        if data.activeTMIPlans > 0 && (data.activeTMIPlans < data.totalStudents) {
             return DashboardStatus(status: .growing, title: "🌱 Growing — progress improving", icon: "leaf.fill", color: .tmiPrimary)
        }
         return DashboardStatus(status: .onTrack, title: "🎯 On Track — surveys complete and plans active", icon: "checkmark.seal.fill", color: .tmiSuccess)
    }
}
