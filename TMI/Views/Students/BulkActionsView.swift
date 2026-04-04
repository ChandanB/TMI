//
//  BulkActionsView.swift
//  TMI
//
//  Extracted from StudentListView for better organization
//

import SwiftUI

struct BulkActionsView: View {
    let students: [Student]
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedStudents: Set<String> = []
    @State private var isPerformingAction = false
    @State private var actionCompleted = false

    var body: some View {
        ZStack {
            TMIBackgroundView(variant: .base)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.rectangle.stack.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.tmiSecondary)

                        Text("Bulk Actions")
                            .font(.title.bold())
                            .foregroundColor(Color.tmiTextPrimary)

                        Text("Select students and choose an action to apply to all selected students.")
                            .font(.body)
                            .foregroundColor(Color.tmiTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Student selection
                    TMICard(style: .default) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Select Students")
                                    .font(.headline)
                                    .foregroundColor(Color.tmiTextPrimary)

                                Spacer()

                                Button(selectedStudents.count == students.count ? "Deselect All" : "Select All") {
                                    if selectedStudents.count == students.count {
                                        selectedStudents.removeAll()
                                    } else {
                                        selectedStudents = Set(students.compactMap { $0.id })
                                    }
                                }
                                .foregroundColor(.tmiSecondary)
                            }

                            Divider()
                                .background(Color.white.opacity(0.1))

                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(students) { student in
                                        HStack {
                                            Button {
                                                if let studentId = student.id {
                                                    if selectedStudents.contains(studentId) {
                                                        selectedStudents.remove(studentId)
                                                    } else {
                                                        selectedStudents.insert(studentId)
                                                    }
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: selectedStudents.contains(student.id ?? "") ? "checkmark.circle.fill" : "circle")
                                                        .foregroundColor(selectedStudents.contains(student.id ?? "") ? .tmiSecondary : Color.tmiTextTertiary)

                                                    Text(student.name)
                                                        .foregroundColor(Color.tmiTextPrimary)

                                                    Spacer()
                                                }
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                    }

                    // Available actions
                    if !selectedStudents.isEmpty {
                        TMICard(style: .default) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Available Actions")
                                    .font(.headline)
                                    .foregroundColor(Color.tmiTextPrimary)

                                LazyVStack(spacing: 12) {
                                    BulkActionButton(
                                        icon: "envelope.fill",
                                        title: "Send Notifications",
                                        description: "Send notifications to selected students",
                                        color: .blue
                                    ) {
                                        Task {
                                            await performBulkAction("notify")
                                        }
                                    }

                                    BulkActionButton(
                                        icon: "doc.text.fill",
                                        title: "Generate Reports",
                                        description: "Create progress reports for selected students",
                                        color: .green
                                    ) {
                                        Task {
                                            await performBulkAction("report")
                                        }
                                    }

                                    BulkActionButton(
                                        icon: "person.badge.plus",
                                        title: "Assign TMI Plans",
                                        description: "Assign TMI plans to selected students",
                                        color: .orange
                                    ) {
                                        Task {
                                            await performBulkAction("assign_plan")
                                        }
                                    }

                                    BulkActionButton(
                                        icon: "archivebox.fill",
                                        title: "Archive Students",
                                        description: "Archive selected students (can be undone)",
                                        color: .gray
                                    ) {
                                        Task {
                                            await performBulkAction("archive")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("Bulk Actions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color.tmiTextPrimary)
                }
            }
    }

    @MainActor
    private func performBulkAction(_ action: String) async {
        isPerformingAction = true

        do {
            let selectedStudentObjects = students.filter { student in
                selectedStudents.contains(student.id ?? "")
            }

            switch action {
            case "notify":
                await sendNotifications(to: selectedStudentObjects)
            case "report":
                await generateReports(for: selectedStudentObjects)
            case "assign_plan":
                await assignPlans(to: selectedStudentObjects)
            case "archive":
                await archiveStudents(selectedStudentObjects)
            default:
                break
            }

            actionCompleted = true

            // Wait a moment to show success, then close
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            onComplete(action)

        } catch {
            // Handle error - in a real app, show error alert
            print("Bulk action failed: \(error)")
        }

        isPerformingAction = false
    }

    private func sendNotifications(to students: [Student]) async {
        // Simulate sending notifications
        print("Sending notifications to \(students.count) students")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    private func generateReports(for students: [Student]) async {
        // Simulate generating reports
        print("Generating reports for \(students.count) students")
        try? await Task.sleep(nanoseconds: 1_500_000_000)
    }

    private func assignPlans(to students: [Student]) async {
        // Simulate assigning plans
        print("Assigning plans to \(students.count) students")
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }

    private func archiveStudents(_ students: [Student]) async {
        // Simulate archiving students
        print("Archiving \(students.count) students")
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

// MARK: - Bulk Action Button

struct BulkActionButton: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.tmiTextPrimary)

                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(Color.tmiTextSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.tmiTextTertiary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationView {
        BulkActionsView(students: Student.sampleStudents) { action in
            print("Completed action: \(action)")
        }
    }
}