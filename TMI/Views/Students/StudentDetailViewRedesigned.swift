//
//  StudentDetailViewRedesigned.swift
//  TMI
//
//  Simplified single-scroll student profile with pinned actions
//

import SwiftUI
import Charts

struct StudentDetailViewRedesigned: View {
    let student: Student
    @State private var showingCreatePlan = false
    @State private var showingEditStudent = false
    @State private var expandedSections: Set<String> = []
    @State private var planStateModel = TMIPlanListStateModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.tmiBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: TMISpacing.lg) {
                    // Hero Section
                    heroSection

                    // Quick Actions
                    quickActionsRow

                    // Key Stats
                    keyStatsSection

                    // Interests Section
                    interestsSection

                    // TMI Plans Section (NEW)
                    tmiPlansSection

                    // Engagement Chart
                    if let engagementHistory = student.engagementHistory, !engagementHistory.isEmpty {
                        engagementChartSection(engagementHistory)
                    }

                    // Academic Performance
                    if let academic = student.academicPerformance {
                        academicSection(academic)
                    }

                    // Notes & History
                    if let notes = student.notes, !notes.isEmpty {
                        notesSection(notes)
                    }

                    Spacer(minLength: 80) // Space for action bar
                }
                .padding(.horizontal, TMISpacing.screenPadding)
                .padding(.top, TMISpacing.md)
            }

            // Bottom Action Bar (Optional - can remove if using quick actions)
            // primaryActionBar
        }
        .navigationTitle(student.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingEditStudent = true }) {
                    Image(systemName: "pencil")
                        .foregroundColor(.tmiPrimary)
                }
            }
        }
        .sheet(isPresented: $showingCreatePlan) {
            NavigationStack {
                NewTMIPlanViewRedesigned(student: student)
            }
        }
        .sheet(isPresented: $showingEditStudent) {
            NavigationStack {
                // TODO: Create EditStudentViewRedesigned or use existing edit view
                AddStudentViewRedesigned(onComplete: { showingEditStudent = false })
            }
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: TMISpacing.md) {
            // Avatar
            TMIAvatar(
                initials: student.initials,
                color: avatarColor,
                size: TMISizing.avatarLg
            )

            // Name & Grade
            VStack(spacing: 4) {
                Text(student.name)
                    .font(.tmiTitle1)
                    .foregroundColor(.tmiTextPrimary)

                Text("Grade \(student.grade) • \(student.school)")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.lg)
    }

    // MARK: - Quick Actions

    private var quickActionsRow: some View {
        HStack(spacing: TMISpacing.md) {
            quickActionButton(
                icon: "doc.badge.plus",
                label: "Create Plan",
                action: { showingCreatePlan = true }
            )

            quickActionButton(
                icon: "list.clipboard",
                label: "View Plans",
                action: { /* Navigate to plans */ }
            )

            quickActionButton(
                icon: "chart.bar",
                label: "Progress",
                action: { /* Show progress */ }
            )
        }
    }

    private func quickActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: TMISpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.tmiPrimary)

                Text(label)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, TMISpacing.md)
            .background(Color.tmiSurface)
            .cornerRadius(TMIRadius.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Key Stats

    private var keyStatsSection: some View {
        HStack(spacing: TMISpacing.md) {
            statCard(
                value: "\(student.age)",
                label: "Years Old"
            )

            statCard(
                value: "\(Int(student.engagementScore * 100))%",
                label: "Engagement"
            )

            statCard(
                value: "\(student.interests.count)",
                label: "Interests"
            )
        }
    }

    private func statCard(value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.tmiTitle2)
                .foregroundColor(.tmiTextPrimary)

            Text(label)
                .font(.tmiCaption)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.md)
        .tmiCard()
    }

    // MARK: - Interests Section

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Button(action: {
                withAnimation {
                    toggleSection("interests")
                }
            }) {
                HStack {
                    Text("Interests")
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)

                    Spacer()

                    Image(systemName: expandedSections.contains("interests") ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiTextSecondary)
                }
            }
            .buttonStyle(.plain)

            if expandedSections.contains("interests") {
                if student.interests.isEmpty {
                    Text("No interests recorded yet")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, TMISpacing.lg)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TMISpacing.sm) {
                            ForEach(student.interests, id: \.id) { interest in
                                TMIBadge(
                                    text: interest.name,
                                    color: .tmiPrimary,
                                    style: .solid
                                )
                            }
                        }
                    }
                }
            }
        }
        .tmiCard()
    }

    // MARK: - TMI Plans Section

    private var tmiPlansSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TMI Plans")
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)

                    Text("Active intervention plans for this student")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()

                if studentHasPlans {
                    TMIBadge(
                        text: "\(studentPlans.count)",
                        color: .tmiPrimary,
                        style: .solid
                    )
                }
            }

            if studentHasPlans {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(studentPlans.prefix(3)) { plan in
                        NavigationLink(destination: TMIPlanDetailView(plan: plan)) {
                            planMiniCard(plan)
                        }
                        .buttonStyle(.plain)
                    }

                    if studentPlans.count > 3 {
                        Button(action: {
                            // Navigate to plans tab filtered by student
                        }) {
                            HStack {
                                Text("View All \(studentPlans.count) Plans")
                                    .font(.tmiCaption)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(.tmiPrimary)
                            .padding(.vertical, TMISpacing.sm)
                            .padding(.horizontal, TMISpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: TMIRadius.sm)
                                    .fill(Color.tmiPrimary.opacity(0.1))
                            )
                        }
                    }
                }
            } else {
                VStack(spacing: TMISpacing.md) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.tmiTextTertiary)

                    Text("No TMI plans yet")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)

                    Text("Create a trauma-informed intervention plan for \(student.name)")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextTertiary)
                        .multilineTextAlignment(.center)

                    TMIButton(
                        text: "Create First Plan",
                        icon: "plus",
                        style: .primary,
                        action: { showingCreatePlan = true }
                    )
                    .padding(.top, TMISpacing.sm)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, TMISpacing.lg)
            }
        }
        .tmiCard()
        .task {
            await planStateModel.fetch()
        }
    }

    private func planMiniCard(_ plan: TMIPlan) -> some View {
        HStack(spacing: TMISpacing.md) {
            // Model Icon
            ZStack {
                Circle()
                    .fill(planModelColor(for: plan.model).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: planModelIcon(for: plan.model))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(planModelColor(for: plan.model))
            }

            // Plan Info
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title)
                    .font(.tmiBody)
                    .fontWeight(.semibold)
                    .foregroundColor(.tmiTextPrimary)
                    .lineLimit(1)

                Text(plan.model.rawValue)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
            }

            Spacer()

            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.tmiTextTertiary.opacity(0.2), lineWidth: 3)
                    .frame(width: 32, height: 32)

                Circle()
                    .trim(from: 0, to: plan.progress)
                    .stroke(planModelColor(for: plan.model), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 32, height: 32)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(plan.progress * 100))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.tmiTextSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tmiTextTertiary)
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.sm)
                .fill(Color.tmiSurface)
        )
    }

    private var studentHasPlans: Bool {
        !studentPlans.isEmpty
    }

    private var studentPlans: [TMIPlan] {
        planStateModel.plans.filter { plan in
            plan.students.contains(where: { $0.id == student.id })
        }
    }

    private func planModelIcon(for model: TMIPlanModel) -> String {
        switch model {
        case .chaseYourSpace: return "arrow.up.right"
        case .acknowledgeInterests: return "heart.fill"
        case .alignYourMind: return "brain.head.profile"
        case .directAndCorrect: return "arrow.triangle.2.circlepath"
        case .bullyToBoss: return "person.fill.badge.plus"
        case .meekToProtector: return "shield.fill"
        }
    }

    private func planModelColor(for model: TMIPlanModel) -> Color {
        switch model {
        case .chaseYourSpace: return .blue
        case .acknowledgeInterests: return .purple
        case .alignYourMind: return .teal
        case .directAndCorrect: return .orange
        case .bullyToBoss: return .red
        case .meekToProtector: return .green
        }
    }

    // MARK: - Engagement Chart

    private func engagementChartSection(_ history: [EngagementRecord]) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Text("Engagement Over Time")
                .font(.tmiTitle3)
                .foregroundColor(.tmiTextPrimary)

            Chart(history.indices, id: \.self) { index in
                let record = history[index]
                LineMark(
                    x: .value("Date", record.date),
                    y: .value("Score", record.score * 100)
                )
                .foregroundStyle(Color.tmiPrimary)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))

                PointMark(
                    x: .value("Date", record.date),
                    y: .value("Score", record.score * 100)
                )
                .foregroundStyle(Color.tmiPrimary)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.tmiTextSecondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.tmiTextSecondary)
                }
            }
        }
        .tmiCard()
    }

    // MARK: - Academic Section

    private func academicSection(_ academic: AcademicPerformance) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Button(action: {
                withAnimation {
                    toggleSection("academic")
                }
            }) {
                HStack {
                    Text("Academic Performance")
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)

                    Spacer()

                    if let gpa = academic.gpa {
                        Text("GPA: \(String(format: "%.2f", gpa))")
                            .font(.tmiCaption)
                            .foregroundColor(.tmiTextSecondary)
                    }

                    Image(systemName: expandedSections.contains("academic") ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiTextSecondary)
                }
            }
            .buttonStyle(.plain)

            if expandedSections.contains("academic") {
                VStack(alignment: .leading, spacing: TMISpacing.sm) {
                    ForEach(academic.subjects, id: \.name) { subject in
                        HStack {
                            Text(subject.name)
                                .font(.tmiBody)
                                .foregroundColor(.tmiTextPrimary)

                            Spacer()

                            Text(subject.grade)
                                .font(.tmiLabelLarge)
                                .foregroundColor(.tmiPrimary)
                        }
                        .padding(.vertical, 8)

                        if subject.name != academic.subjects.last?.name {
                            TMIDivider()
                        }
                    }
                }
            }
        }
        .tmiCard()
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: [StudentNote]) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Button(action: {
                withAnimation {
                    toggleSection("notes")
                }
            }) {
                HStack {
                    Text("Notes & History")
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)

                    Spacer()

                    Text("\(notes.count)")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)

                    Image(systemName: expandedSections.contains("notes") ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.tmiTextSecondary)
                }
            }
            .buttonStyle(.plain)

            if expandedSections.contains("notes") {
                VStack(alignment: .leading, spacing: TMISpacing.md) {
                    ForEach(notes) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(note.author)
                                    .font(.tmiCaption)
                                    .foregroundColor(.tmiTextSecondary)

                                Spacer()

                                Text(note.date, style: .date)
                                    .font(.tmiFootnote)
                                    .foregroundColor(.tmiTextTertiary)
                            }

                            Text(note.content)
                                .font(.tmiBody)
                                .foregroundColor(.tmiTextPrimary)
                        }
                        .padding(.vertical, TMISpacing.sm)

                        if note.id != notes.last?.id {
                            TMIDivider()
                        }
                    }
                }
            }
        }
        .tmiCard()
    }

    // MARK: - Helpers

    private var avatarColor: Color {
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

    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }
}

#Preview {
    NavigationStack {
        StudentDetailViewRedesigned(student: Student.sampleStudent)
    }
}
