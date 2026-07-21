//
//  QuickActionCards.swift
//  TMI
//
//  Quick action cards for trauma-informed educator workflows
//

import SwiftUI

// MARK: - Quick Action Card Component

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let accentBorderColor: Color
    let badge: String?
    let action: () -> Void

    @State private var isPressed = false

    init(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        accentBorderColor: Color? = nil,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.accentBorderColor = accentBorderColor ?? iconColor
        self.badge = badge
        self.action = action
    }

    var body: some View {
        Button(action: {
            TMIHaptics.lightImpact()
            action()
        }) {
            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                // Header with icon and badge
                HStack(alignment: .top) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(iconColor)
                    }

                    Spacer()

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color.tmiTextPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(iconColor)
                            )
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.tmiBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.tmiTextPrimary)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                        .lineLimit(2)
                }
            }
            .padding(TMISpacing.md)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(Color.tmiSurface)
            .cornerRadius(TMIRadius.md)
            .overlay(alignment: .leading) {
                // 3px left accent border
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .fill(accentBorderColor)
                    .frame(width: 3)
            }
            .overlay(
                RoundedRectangle(cornerRadius: TMIRadius.md)
                    .strokeBorder(iconColor.opacity(0.1), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(isPressed ? 0.05 : 0.1),
                radius: isPressed ? 4 : 8,
                y: isPressed ? 2 : 4
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(TMIAnimation.springInteractive, value: isPressed)
    }
}

// MARK: - Quick Actions Grid

struct QuickActionsGrid: View {
    @Environment(\.dashboardStateModel) var dashboardModel
    @State private var studentStateModel = StudentListStateModel()
    @State private var showingAddStudent = false
    @State private var showingViewAllStudents = false
    @State private var showingCreatePlan = false
    @State private var showingStudentsNeedingSupport = false
    
    var data: DashboardData

    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Quick Actions")
                .font(.tmiTitle3.bold())
                .foregroundColor(.tmiTextPrimary)

            Divider()
            
            VStack(spacing: TMISpacing.md) {
                if let action = data.nextBestAction {
                    NextBestActionCard(action: action) {
                        handleNextAction(action)
                    }
                }
                
                
                QuickActionCard(
                    title: "Add Student",
                    subtitle: "Begin a new student profile",
                    icon: "person.badge.plus",
                    iconColor: .tmiPrimary,
                    accentBorderColor: .tmiPrimary,
                    badge: nil,
                    action: { showingAddStudent = true }
                )

                QuickActionCard(
                    title: "Create Plan",
                    subtitle: "Design a TMI intervention",
                    icon: "doc.badge.plus",
                    iconColor: .tmiSuccess,
                    accentBorderColor: .tmiSuccess,
                    badge: nil,
                    action: { showingCreatePlan = true }
                )

                QuickActionCard(
                    title: "Students Needing Support",
                    subtitle: "View students requiring attention",
                    icon: "heart.text.square",
                    iconColor: .tmiWarning,
                    accentBorderColor: .tmiWarning,
                    badge: studentsNeedingSupportCount,
                    action: { showingStudentsNeedingSupport = true }
                )

                QuickActionCard(
                    title: "All Students",
                    subtitle: "View complete student roster",
                    icon: "person.3.fill",
                    iconColor: .tmiSecondary,
                    accentBorderColor: .tmiSecondary,
                    badge: totalStudentsCount,
                    action: { showingViewAllStudents = true }
                )
            }
        }
        .task {
            await studentStateModel.fetch()
        }
        .sheet(isPresented: $showingAddStudent) {
            NavigationStack {
                StudentProfileView(onComplete: {
                    showingAddStudent = false
                    // Refresh data after adding student
                    Task {
                        await studentStateModel.fetch()
                        await dashboardModel.refresh()
                    }
                })
            }
            .tmiSheetStyle()
        }
        .sheet(isPresented: $showingCreatePlan) {
            NavigationStack {
                StudentSelectorForPlanView(onStudentSelected: { student in
                    showingCreatePlan = false
                    // Navigate to plan creation with selected student
                })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingCreatePlan = false
                            }
                        }
                    }
            }
            .tmiSheetStyle()
        }
        .navigationDestination(isPresented: $showingViewAllStudents) {
            StudentListView()
        }
        .navigationDestination(isPresented: $showingCreatePlan) {
            TMIPlanListView()
        }
        .sheet(isPresented: $showingStudentsNeedingSupport) {
            NavigationStack {
                StudentsNeedingSupportView()
            }
            .tmiSheetStyle()
        }
    }
    
    // MARK: - Next Action Handler

    private func handleNextAction(_ action: NextBestAction) {
        switch action.type {
        case .createPlan, .reviewPlan, .pendingApproval:
           showingCreatePlan = true
        case .scheduleMeeting, .completeNotes, .addInterests, .checkProgress:
            showingViewAllStudents = true
        }
    }

    // MARK: - Computed Properties with Real Data

    private var studentsNeedingSupport: [Student] {
        studentStateModel.students.filter { $0.engagementScore < 0.4 }
    }

    private var studentsNeedingSupportCount: String? {
        let count = studentsNeedingSupport.count
        return count > 0 ? "\(count)" : nil
    }

    private var totalStudentsCount: String? {
        let count = studentStateModel.students.count
        return count > 0 ? "\(count)" : nil
    }
}

// MARK: - Students Needing Support View

struct StudentsNeedingSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @State private var stateModel = StudentListStateModel()

    var studentsNeedingSupport: [Student] {
        stateModel.filteredStudents.filter { $0.engagementScore < 0.4 }
    }

    var body: some View {
        Group {
            if studentsNeedingSupport.isEmpty {
                TMIEmptyState(
                    icon: "checkmark.circle.fill",
                    title: "All Students Engaged",
                    message: "Great work! All your students are showing positive engagement levels.",
                    action: nil,
                    actionLabel: nil
                )
            } else {
                List(studentsNeedingSupport) { student in
                    if student.id != nil {
                        Button {
                            guard (try? router.open(student)) != nil else { return }
                            dismiss()
                        } label: {
                            HStack(spacing: TMISpacing.md) {
                                TMIAvatar(
                                    initials: student.initials,
                                    color: avatarColor(for: student),
                                    size: TMISizing.avatarSm
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                Text(student.name)
                                    .font(.tmiBody)
                                    .foregroundColor(.tmiTextPrimary)

                                Text("Grade \(student.grade) • \(student.school)")
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                Text("Engagement: \(Int(student.engagementScore * 100))%")
                                    .font(.tmiFootnote)
                                    .foregroundColor(.tmiWarning)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.tmiTextTertiary)
                            }
                            .padding(.vertical, TMISpacing.sm)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.tmiBackground)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color.tmiBackground)
        .navigationTitle("Students Needing Support")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            await stateModel.fetch()
        }
    }

    private func avatarColor(for student: Student) -> Color {
        switch student.avatarColor {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
}

// MARK: - Student Selector for Plan Creation

struct StudentSelectorForPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var studentStateModel = StudentListStateModel()
    @State private var selectedStudent: Student? = nil
    @State private var searchText = ""
    let onStudentSelected: (Student) -> Void
    let onPlanCreated: (() -> Void)?

    init(onStudentSelected: @escaping (Student) -> Void, onPlanCreated: (() -> Void)? = nil) {
        self.onStudentSelected = onStudentSelected
        self.onPlanCreated = onPlanCreated
    }

    var filteredStudents: [Student] {
        if searchText.isEmpty {
            return studentStateModel.students
        }
        return studentStateModel.students.filter { student in
            student.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            TMISearchBar(text: $searchText, placeholder: "Search students...")
                .padding(.horizontal, TMISpacing.screenPadding)
                .padding(.vertical, TMISpacing.md)

            // Student list
            switch studentStateModel.state {
            case .idle, .loading:
                ProgressView("Loading students...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, TMISpacing.xxl)
            case .loaded:
                if filteredStudents.isEmpty {
                    TMIEmptyState(
                        icon: "person.crop.circle.badge.plus",
                        title: searchText.isEmpty ? "No Students Yet" : "No Results",
                        message: searchText.isEmpty ? "Add a student first before creating a TMI plan" : "No students match your search",
                        action: nil,
                        actionLabel: nil
                    )
                } else {
                    List(filteredStudents) { student in
                        Button {
                            selectedStudent = student
                        } label: {
                            HStack(spacing: TMISpacing.md) {
                                TMIAvatar(
                                    initials: student.initials,
                                    color: avatarColor(for: student),
                                    size: TMISizing.avatarSm
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(student.name)
                                        .font(.tmiBody)
                                        .foregroundColor(.tmiTextPrimary)

                                    Text("Grade \(student.grade) • \(student.school)")
                                        .font(.tmiCaption)
                                        .foregroundColor(.tmiTextSecondary)
                                }

                                Spacer()

                                if selectedStudent?.id == student.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.tmiPrimary)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.tmiTextTertiary)
                                }
                            }
                            .padding(.vertical, TMISpacing.sm)
                        }
                    }
                    .listStyle(.plain)
                }
            case .error:
                TMIEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Unable to Load Students",
                    message: "Please try again",
                    action: { Task { await studentStateModel.fetch() } },
                    actionLabel: "Retry"
                )
            }
        }
        .navigationTitle("Select Student")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await studentStateModel.fetch()
        }
        .sheet(item: $selectedStudent) { student in
            NavigationStack {
                TMIPlanEditorView(preselectedStudent: student, onPlanCreated: onPlanCreated)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                selectedStudent = nil
                                dismiss()
                            }
                        }
                    }
            }
            .tmiSheetStyle()
        }
    }

    private func avatarColor(for student: Student) -> Color {
        switch student.avatarColor {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        case .teal: return .teal
        case .pink: return .pink
        case .indigo: return .indigo
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: TMISpacing.lg) {
                QuickActionsGrid(data: DashboardData(engagementData: [], totalStudents: 0, activeTMIPlans: 0, interestsIdentified: 0, surveysCompleted: 0, plansAligned: 0, recentActivities: [], nextBestAction: NextBestAction(id: "", type: .addInterests, title: "", description: "", priority: .high, targetStudentId: "", targetPlanId: ""), roleData: nil))
                    .padding()
            }
        }
        .background(Color.tmiBackground)
        .environment(\.dashboardStateModel, DashboardStateModel())
    }
}
