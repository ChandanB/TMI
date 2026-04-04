//
//  AssignedResourcesView.swift
//  TMI
//
//  Created for Phase 1: District Pilot - PR #5
//  Displays resources assigned to a student with progress tracking
//

import SwiftUI

/// View displaying all resources assigned to a student with completion tracking
struct AssignedResourcesView: View {
    let student: Student

    @State private var assignments: [ResourceAssignment] = []
    @State private var analytics: ResourceAssignmentAnalytics?
    @State private var isLoading = false
    @State private var selectedStatus: ResourceAssignment.AssignmentStatus?
    @State private var selectedAssignment: ResourceAssignment?
    @State private var showingDetail = false

    private let assignmentService = ResourceAssignmentService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Analytics header
            if let analytics = analytics {
                analyticsHeader(analytics)
            }

            // Filter tabs
            filterTabs

            // Content
            if isLoading {
                loadingView
            } else if filteredAssignments.isEmpty {
                emptyView
            } else {
                assignmentsList
            }
        }
        .background(TMIBackgroundView(variant: .base).ignoresSafeArea())
        .navigationTitle("Assigned Resources")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAssignments()
        }
        .refreshable {
            await loadAssignments()
        }
        .sheet(isPresented: $showingDetail) {
            if let assignment = selectedAssignment {
                AssignmentDetailView(
                    assignment: assignment,
                    service: assignmentService,
                    onUpdate: {
                        Task { await loadAssignments() }
                    }
                )
                .tmiSheetStyle()
            }
        }
    }

    // MARK: - Analytics Header

    private func analyticsHeader(_ analytics: ResourceAssignmentAnalytics) -> some View {
        TMIGlassCard(style: .default) {
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    AssignmentAnalyticsMetric(
                        title: "Total",
                        value: "\(analytics.totalAssignments)",
                        icon: "doc.fill",
                        color: .blue
                    )

                    AssignmentAnalyticsMetric(
                        title: "Completed",
                        value: "\(analytics.completedAssignments)",
                        icon: "checkmark.circle.fill",
                        color: .green
                    )

                    AssignmentAnalyticsMetric(
                        title: "In Progress",
                        value: "\(analytics.inProgressAssignments)",
                        icon: "clock.fill",
                        color: .orange
                    )
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Completion Rate")
                            .font(.caption)
                            .foregroundColor(Color.tmiTextSecondary)

                        Spacer()

                        Text("\(Int(analytics.completionRate * 100))%")
                            .font(.caption.bold())
                            .foregroundColor(Color.tmiTextPrimary)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white.opacity(0.2))

                            RoundedRectangle(cornerRadius: 4)
                                .fill(LinearGradient(
                                    colors: [.green, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: geometry.size.width * analytics.completionRate)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterTab(
                    title: "All",
                    count: assignments.count,
                    isSelected: selectedStatus == nil,
                    action: { selectedStatus = nil }
                )

                ForEach(ResourceAssignment.AssignmentStatus.allCases, id: \.self) { status in
                    let count = assignments.filter { $0.status == status }.count
                    FilterTab(
                        title: status.displayName,
                        count: count,
                        isSelected: selectedStatus == status,
                        action: { selectedStatus = status }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Assignments List

    private var assignmentsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredAssignments) { assignment in
                    AssignmentCard(assignment: assignment) {
                        selectedAssignment = assignment
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
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(Color.tmiTextTertiary)

            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)

            Text(emptyStateSubtitle)
                .font(.caption)
                .foregroundColor(Color.tmiTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }

    private var emptyStateIcon: String {
        if let status = selectedStatus {
            switch status {
            case .assigned: return "envelope.open"
            case .viewed: return "eye.slash"
            case .inProgress: return "clock.badge.xmark"
            case .completed: return "checkmark.circle"
            }
        }
        return "tray"
    }

    private var emptyStateMessage: String {
        if let status = selectedStatus {
            return "No \(status.displayName.lowercased()) resources"
        }
        return "No assigned resources"
    }

    private var emptyStateSubtitle: String {
        if selectedStatus != nil {
            return "Try selecting a different filter"
        }
        return "Resources assigned to you will appear here"
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text("Loading assignments...")
                .font(.headline)
                .foregroundColor(Color.tmiTextPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    // MARK: - Data Loading

    @MainActor
    private func loadAssignments() async {
        guard let studentId = student.id else { return }

        isLoading = true

        do {
            assignments = try await assignmentService.getAssignments(forStudentId: studentId)
            
            // Calculate analytics from assignments
            analytics = ResourceAssignmentAnalytics(assignments: assignments)
        } catch {
            print("[AssignedResourcesView] Failed to load assignments: \(error)")
        }

        isLoading = false
    }

    // MARK: - Computed Properties

    private var filteredAssignments: [ResourceAssignment] {
        if let status = selectedStatus {
            return assignments.filter { $0.status == status }
        }
        return assignments
    }
}

// MARK: - Supporting Views

private struct AssignmentAnalyticsMetric: View {
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
                .foregroundColor(Color.tmiTextPrimary)

            Text(title)
                .font(.caption2)
                .foregroundColor(Color.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FilterTab: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.bold())

                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.tmiInputBackground)
                    .cornerRadius(8)
            }
            .foregroundColor(isSelected ? Color.tmiTextOnPrimary : Color.tmiTextSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color.tmiInputBackground], startPoint: .leading, endPoint: .trailing)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color.tmiBorder, lineWidth: 1)
            )
            .cornerRadius(20)
        }
    }
}

private struct AssignmentCard: View {
    let assignment: ResourceAssignment
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TMIGlassCard(style: .default) {
                VStack(alignment: .leading, spacing: 12) {
                    // Header
                    HStack {
                        Image(systemName: categoryIcon)
                            .font(.title2)
                            .foregroundStyle(categoryColor.gradient)
                            .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(assignment.resourceTitle)
                                .font(.headline)
                                .foregroundColor(Color.tmiTextPrimary)
                                .lineLimit(2)

                            Text(assignment.resourceCategory.capitalized)
                                .font(.caption)
                                .foregroundColor(Color.tmiTextSecondary)
                        }

                        Spacer()

                        Image(systemName: assignment.status.icon)
                            .foregroundColor(statusColor)
                    }

                    // Context
                    if let relatedCareer = assignment.relatedCareer {
                        Label(relatedCareer, systemImage: "briefcase.fill")
                            .font(.caption)
                            .foregroundColor(Color.tmiTextSecondary)
                    }

                    if let relatedInterest = assignment.relatedInterest {
                        Label(relatedInterest, systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(Color.tmiTextSecondary)
                    }

                    // Metadata
                    HStack {
                        Text("Assigned \(assignment.assignedAt.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundColor(Color.tmiTextTertiary)

                        Spacer()

                        Text(assignment.status.displayName)
                            .font(.caption2.bold())
                            .foregroundColor(statusColor)
                    }
                }
                .padding()
            }
        }
        .buttonStyle(.plain)
    }

    private var categoryIcon: String {
        switch assignment.resourceCategory.lowercased() {
        case "article": return "doc.text.fill"
        case "video": return "play.rectangle.fill"
        case "course": return "book.fill"
        case "book": return "book.closed.fill"
        case "tool": return "hammer.fill"
        case "interactivecontent": return "gamecontroller.fill"
        default: return "doc.fill"
        }
    }

    private var categoryColor: Color {
        switch assignment.resourceCategory.lowercased() {
        case "article": return .blue
        case "video": return .red
        case "course": return .green
        case "book": return .purple
        case "tool": return .orange
        case "interactivecontent": return .pink
        default: return .gray
        }
    }

    private var statusColor: Color {
        switch assignment.status {
        case .assigned: return .gray
        case .viewed: return .blue
        case .inProgress: return .orange
        case .completed: return .green
        }
    }
}

// MARK: - Assignment Detail View

private struct AssignmentDetailView: View {
    let assignment: ResourceAssignment
    let service: ResourceAssignmentService
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var notes = ""
    @State private var isUpdating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Resource info
                    VStack(alignment: .leading, spacing: 12) {
                        Text(assignment.resourceTitle)
                            .font(.title2.bold())

                        HStack {
                            Label(assignment.resourceCategory.capitalized, systemImage: "tag.fill")
                            Spacer()
                            Label(assignment.status.displayName, systemImage: assignment.status.icon)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Context
                    if assignment.relatedCareer != nil || assignment.relatedInterest != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Context")
                                .font(.headline)

                            if let career = assignment.relatedCareer {
                                Label("Related to: \(career)", systemImage: "briefcase")
                                    .font(.subheadline)
                            }

                            if let interest = assignment.relatedInterest {
                                Label("Based on interest: \(interest)", systemImage: "lightbulb")
                                    .font(.subheadline)
                            }

                            if let reason = assignment.reason {
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.headline)

                        TextField("Add your notes here...", text: $notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(4...8)
                    }

                    // Actions
                    VStack(spacing: 12) {
                        Button(action: { openURL(URL(string: assignment.resourceURL)!) }) {
                            Label("Open Resource", systemImage: "arrow.up.right.square.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        if assignment.status != .completed {
                            Button(action: { updateStatus(.completed) }) {
                                Label("Mark as Completed", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isUpdating)
                        }

                        if assignment.status == .assigned {
                            Button(action: { updateStatus(.inProgress) }) {
                                Label("Start Working", systemImage: "clock.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(isUpdating)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Resource Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            notes = assignment.notes ?? ""
            Task {
                guard let id = assignment.id else { return }
                try? await service.trackResourceView(assignmentId: id)
            }
        }
    }

    private func updateStatus(_ status: ResourceAssignment.AssignmentStatus) {
        guard let id = assignment.id else { return }

        isUpdating = true

        Task {
            do {
                try await service.updateAssignmentStatus(
                    id,
                    status: status,
                    notes: notes.isEmpty ? nil : notes
                )

                await MainActor.run {
                    isUpdating = false
                    onUpdate()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                }
                print("[AssignmentDetailView] Failed to update status: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AssignedResourcesView(student: .sampleStudents[0])
    }
}
