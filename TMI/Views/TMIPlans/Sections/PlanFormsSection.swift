// PlanFormsSection.swift
// TMI
//
// Accordion section for displaying form assignments associated with a TMI Plan.
// Shows each assignment as a card with a status badge and a bottom CTA to assign new forms.

import SwiftUI
import FirebaseAuth

// MARK: - PlanFormsSection

/// Accordion-style section displaying form assignments linked to a TMI plan.
/// Loads assignments created by the current user via FormAssignmentService.
struct PlanFormsSection: View {
    var planId: String?

    // MARK: State

    @State private var assignments: [FormAssignment] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showAssignSheet: Bool = false

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoading {
                ProgressView("Loading assignments…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else if let error = errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.vertical, 8)
            } else if assignments.isEmpty {
                ContentUnavailableView {
                    Label("No Assignments", systemImage: "doc.badge.clock")
                } description: {
                    Text("Assign a form or survey to students linked to this plan.")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ForEach(assignments) { assignment in
                    PlanFormAssignmentCard(assignment: assignment)
                }
            }

            assignButton
        }
        .task {
            await loadAssignments()
        }
        .sheet(isPresented: $showAssignSheet) {
            // Placeholder sheet — wire up FormAssignmentCreateView when a plan-scoped flow is ready.
            NavigationStack {
                ContentUnavailableView {
                    Label("Coming Soon", systemImage: "doc.badge.plus")
                } description: {
                    Text("Plan-scoped form assignment is under construction.")
                }
                .navigationTitle("Assign Form or Survey")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showAssignSheet = false }
                    }
                }
            }
            .tmiSheetStyle()
        }
    }

    // MARK: - Assign Button

    private var assignButton: some View {
        Button {
            showAssignSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                    .font(.subheadline)
                Text("Assign Form or Survey")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(.tint)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundStyle(.tint.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadAssignments() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            assignments = []
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let service = FormAssignmentService()
            assignments = try await service.fetchAssignmentsCreatedBy(userId: uid)
        } catch {
            errorMessage = "Could not load assignments: \(error.localizedDescription)"
        }
    }
}

// MARK: - FormAssignmentCard

/// A card showing a single form assignment with status badge and completion info.
private struct PlanFormAssignmentCard: View {
    let assignment: FormAssignment

    // MARK: Computed

    private var isOverdue: Bool {
        guard let due = assignment.dueDate else { return false }
        return !assignment.isActive == false && due < Date()
    }

    private var statusLabel: String {
        if isOverdue { return "Overdue" }
        return assignment.isActive ? "Active" : "Inactive"
    }

    private var statusColor: Color {
        if isOverdue { return .red }
        return assignment.isActive ? .green : .secondary
    }

    private var statusIcon: String {
        if isOverdue { return "exclamationmark.clock.fill" }
        return assignment.isActive ? "checkmark.circle.fill" : "pause.circle.fill"
    }

    private var completionText: String {
        "\(assignment.totalSubmitted) / \(assignment.totalAssigned) submitted"
    }

    // MARK: Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.templateName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let due = assignment.dueDate {
                        Label(due.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(isOverdue ? .red : .secondary)
                    }
                }

                Spacer(minLength: 0)

                // Status badge
                Label(statusLabel, systemImage: statusIcon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor)
            }

            // Completion progress
            if assignment.totalAssigned > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(completionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(completionPercentage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    ProgressView(value: Double(assignment.totalSubmitted), total: Double(assignment.totalAssigned))
                        .tint(statusColor)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private var completionPercentage: String {
        guard assignment.totalAssigned > 0 else { return "0%" }
        let pct = Int(Double(assignment.totalSubmitted) / Double(assignment.totalAssigned) * 100)
        return "\(pct)%"
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        PlanFormsSection(planId: "preview-plan-id")
            .padding()
    }
}
