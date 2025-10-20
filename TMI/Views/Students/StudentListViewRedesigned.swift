//
//  StudentListViewRedesigned.swift
//  TMI
//
//  Simplified student list with integrated search and filters
//

import SwiftUI

struct StudentListViewRedesigned: View {
    @State private var stateModel = StudentListStateModel()
    @State private var searchText = ""
    @State private var selectedGradeFilter: String? = nil
    @State private var selectedEngagementFilter: EngagementFilter? = nil
    @State private var showingAddStudent = false
    @State private var studentToDelete: Student? = nil
    @State private var showingDeleteConfirmation = false
    @State private var studentForNewPlan: Student? = nil

    enum EngagementFilter: String, CaseIterable {
        case all = "All Students"
        case engaged = "Engaged"
        case growing = "Growing"
        case needsSupport = "Needs Support"

        var icon: String {
            switch self {
            case .all: return "person.3"
            case .engaged: return "checkmark.circle.fill"
            case .growing: return "chart.line.uptrend.xyaxis"
            case .needsSupport: return "heart.fill"
            }
        }

        var description: String {
            switch self {
            case .all: return "Show all students"
            case .engaged: return "Students with 70%+ engagement"
            case .growing: return "Students with 40-70% engagement"
            case .needsSupport: return "Students below 40% engagement"
            }
        }
    }

    var filteredStudents: [Student] {
        var students = stateModel.filteredStudents

        // Apply search filter
        if !searchText.isEmpty {
            students = students.filter { student in
                student.name.localizedCaseInsensitiveContains(searchText) ||
                student.grade.localizedCaseInsensitiveContains(searchText) ||
                student.school.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply grade filter
        if let gradeFilter = selectedGradeFilter {
            students = students.filter { $0.grade == gradeFilter }
        }

        // Apply engagement filter
        if let engagementFilter = selectedEngagementFilter, engagementFilter != .all {
            students = students.filter { student in
                let engagement = student.engagementScore
                switch engagementFilter {
                case .engaged: return engagement >= 0.7
                case .growing: return engagement >= 0.4 && engagement < 0.7
                case .needsSupport: return engagement < 0.4
                case .all: return true
                }
            }
        }

        return students
    }

    var availableGrades: [String] {
        let grades = Set(stateModel.filteredStudents.map { $0.grade })
        return grades.sorted()
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.tmiBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search Bar
                TMISearchBarRedesigned(text: $searchText, placeholder: "Search students...")
                    .padding(.horizontal, TMISpacing.screenPadding)
                    .padding(.top, TMISpacing.sm)

                // Filter Chips
                if !availableGrades.isEmpty {
                    filterChipsRow
                        .padding(.top, TMISpacing.md)
                }

                // Student List
                Group {
                    switch stateModel.state {
                    case .idle, .loading:
                        loadingView
                    case .loaded:
                        if filteredStudents.isEmpty {
                            emptyStateView
                        } else {
                            studentList
                        }
                    case .error(let error):
                        errorView(error)
                    }
                }
            }

            // FAB for Add Student
            TMIFAB(
                icon: "plus",
                label: "Add Student",
                action: { showingAddStudent = true }
            )
            .padding(TMISpacing.md)
        }
        .navigationTitle("Students")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddStudent) {
            NavigationStack {
                AddStudentViewRedesigned {
                    Task { await stateModel.fetch() }
                    showingAddStudent = false
                }
            }
        }
        .task {
            await stateModel.fetch()
        }
        .refreshable {
            await stateModel.fetch()
        }
    }

    // MARK: - Filter Chips Row

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TMISpacing.sm) {
                // Grade Filters
                ForEach(availableGrades, id: \.self) { grade in
                    TMIFilterChip(
                        label: "Grade \(grade)",
                        isSelected: selectedGradeFilter == grade,
                        action: {
                            selectedGradeFilter = selectedGradeFilter == grade ? nil : grade
                        }
                    )
                }

                // Engagement Filters
                ForEach(EngagementFilter.allCases, id: \.self) { filter in
                    TMIFilterChip(
                        label: filter.rawValue,
                        isSelected: selectedEngagementFilter == filter,
                        action: {
                            selectedEngagementFilter = selectedEngagementFilter == filter ? nil : filter
                        }
                    )
                }
            }
            .padding(.horizontal, TMISpacing.screenPadding)
        }
    }

    // MARK: - Student List

    private var studentList: some View {
        List {
            ForEach(filteredStudents) { student in
                NavigationLink(destination: StudentDetailViewRedesigned(student: student)) {
                    studentRow(student)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: TMISpacing.screenPadding, bottom: 6, trailing: TMISpacing.screenPadding))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Delete action
                    Button(role: .destructive) {
                        studentToDelete = student
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    // Create Plan action
                    Button {
                        studentForNewPlan = student
                        TMIHaptics.lightImpact()
                    } label: {
                        Label("Create Plan", systemImage: "doc.badge.plus")
                    }
                    .tint(.tmiSuccess)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .alert("Delete Student", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let student = studentToDelete {
                    Task {
                        TMIHaptics.mediumImpact()
                        _ = await stateModel.deleteStudent(student)
                        studentToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                studentToDelete = nil
            }
        } message: {
            if let student = studentToDelete {
                Text("Are you sure you want to delete \(student.name)? This action cannot be undone.")
            }
        }
        .sheet(item: $studentForNewPlan) { student in
            NavigationStack {
                NewTMIPlanViewRedesigned(student: student)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                studentForNewPlan = nil
                            }
                        }
                    }
            }
        }
    }

    private func studentRow(_ student: Student) -> some View {
        HStack(spacing: TMISpacing.md) {
            // Avatar
            TMIAvatar(
                initials: student.initials,
                color: avatarColor(for: student),
                size: TMISizing.avatarSm
            )

            // Student Info
            VStack(alignment: .leading, spacing: 6) {
                // Name with alert indicator
                HStack(spacing: 6) {
                    Text(student.name)
                        .font(.tmiBody)
                        .fontWeight(.semibold)
                        .foregroundColor(.tmiTextPrimary)

                    if student.engagementScore < 0.4 {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.tmiWarning)
                    }
                }

                // Grade and School
                Text("Grade \(student.grade) • \(student.school)")
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)

                // Status indicators row
                HStack(spacing: 8) {
                    // Engagement badge
                    engagementBadge(for: student)

                    // TMI Plan indicator
                    if let plan = activePlanForStudent(student) {
                        tmiPlanBadge(plan: plan)
                    }

                    // Survey status
                    if student.interests.count > 0 {
                        surveyCompleteBadge()
                    }
                }
            }

            Spacer()

            // Quick actions menu
            quickActionsMenu(for: student)
        }
        .padding(.vertical, TMISpacing.sm)
        .padding(.horizontal, TMISpacing.md)
        .background(Color.tmiSurface)
        .cornerRadius(TMIRadius.md)
    }

    private func engagementBadge(for student: Student) -> some View {
        let engagement = student.engagementScore
        let color: Color
        let label: String

        // Trauma-sensitive language: focus on support needs, not deficits
        if engagement >= 0.7 {
            color = .tmiSuccess
            label = "Engaged"
        } else if engagement >= 0.4 {
            color = .tmiWarning
            label = "Growing"
        } else {
            color = Color(hex: "#FB923C") // Soft orange, not harsh red
            label = "Support"
        }

        return TMIBadge(text: label, color: color, style: .solid)
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

    // MARK: - Additional Badge Components

    private func tmiPlanBadge(plan: TMIPlan) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "doc.fill")
                .font(.system(size: 10))
                .foregroundColor(modelColor(for: plan.model))

            Text(plan.model.shortName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(modelColor(for: plan.model))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(modelColor(for: plan.model).opacity(0.1))
        .cornerRadius(4)
    }

    private func surveyCompleteBadge() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.tmiSuccess)

            Text("Survey")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.tmiSuccess)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.tmiSuccess.opacity(0.1))
        .cornerRadius(4)
    }

    private func quickActionsMenu(for student: Student) -> some View {
        Menu {
            Button {
                // View student detail
            } label: {
                Label("View Details", systemImage: "person.circle")
            }

            Button {
                // Create new plan
                studentForNewPlan = student
            } label: {
                Label("Create TMI Plan", systemImage: "doc.badge.plus")
            }

            Button {
                // Send interest survey
            } label: {
                Label("Send Survey", systemImage: "envelope")
            }

            Divider()

            Button(role: .destructive) {
                studentToDelete = student
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Student", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22))
                .foregroundColor(.tmiTextSecondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Methods

    private func activePlanForStudent(_ student: Student) -> TMIPlan? {
        // In a real app, this would query the TMIPlanService
        // For now, return nil or a sample plan
        return nil
    }

    private func modelColor(for model: TMIPlanModel) -> Color {
        switch model {
        case .chaseYourSpace: return .blue
        case .acknowledgeInterests: return .pink
        case .alignYourMind: return .purple
        case .directAndCorrect: return .orange
        case .bullyToBoss: return .red
        case .meekToProtector: return .green
        }
    }

    // MARK: - Empty/Loading States

    private var loadingView: some View {
        VStack(spacing: TMISpacing.lg) {
            ProgressView()
                .tint(.tmiPrimary)

            Text("Loading students...")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        TMIEmptyStateRedesigned(
            icon: searchText.isEmpty ? "heart.circle" : "magnifyingglass",
            title: searchText.isEmpty ? "Ready to Make an Impact" : "No Matches Found",
            message: searchText.isEmpty ?
                "Add your first student to begin creating personalized, trauma-informed intervention plans" :
                "Try adjusting your search terms or remove some filters to see more students",
            action: searchText.isEmpty ? { showingAddStudent = true } : nil,
            actionLabel: searchText.isEmpty ? "Add Your First Student" : nil
        )
    }

    private func errorView(_ error: IdentifiableError) -> some View {
        TMIEmptyStateRedesigned(
            icon: "exclamationmark.triangle",
            title: "Unable to Load",
            message: error.message,
            action: {
                Task { await stateModel.fetch() }
            },
            actionLabel: "Try Again"
        )
    }
}

// MARK: - TMIPlanModel Extension

extension TMIPlanModel {
    var shortName: String {
        switch self {
        case .chaseYourSpace: return "Chase"
        case .acknowledgeInterests: return "Acknowledge"
        case .alignYourMind: return "Align"
        case .directAndCorrect: return "Direct"
        case .bullyToBoss: return "Boss"
        case .meekToProtector: return "Protector"
        }
    }
}

#Preview("With Students") {
    NavigationStack {
        StudentListViewRedesigned()
    }
}

#Preview("Empty") {
    NavigationStack {
        StudentListViewRedesigned()
    }
}
