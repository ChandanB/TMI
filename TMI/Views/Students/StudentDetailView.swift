//
//  StudentDetailView.swift
//  TMI
//
//  Simplified single-scroll student profile with pinned actions
//

import SwiftUI
import Charts

struct StudentDetailView: View {
    let initialStudent: Student
    @State private var student: Student
    @State private var refreshID = UUID()
    @State private var showingCreatePlan = false
    @State private var showingEditStudent = false
    @State private var showingAddInterest = false
    @State private var showingAllPlans = false
    @State private var showingProgress = false
    @State private var showingSurvey = false
    @State private var showRetakeConfirmation = false
    @State private var expandedSections: Set<String> = []
    @State private var planStateModel = TMIPlanListStateModel()
    @State private var interestsStateModel = InterestsAndHobbiesStateModel()
    @State private var studentService = StudentService()
    @State private var studentMeetings: [Meeting] = []

    // Phase 2: Student Interest Edges
    @State private var studentInterestEdges: [StudentInterest] = []
    @State private var resolvedInterests: [Interest] = []
    @State private var isLoadingInterests = false

    @Environment(\.studentModeSession) private var studentModeSession

    private let meetingService = MeetingService.shared
    private let studentInterestService = StudentInterestService.shared
    private let interestLibraryService = InterestLibraryService.shared

    init(student: Student) {
        self.initialStudent = student
        _student = State(initialValue: student)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TMIBackgroundView(variant: .default)
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

                    // Meetings Section
                    meetingsSection

                    // Engagement Chart
//                    if let engagementHistory = student.engagementHistory, !engagementHistory.isEmpty {
//                        engagementChartSection(engagementHistory)
//                    }

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
            .id(refreshID)

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
        .task {
            await refreshStudent()
            await planStateModel.fetch()
            await loadMeetings()
            await loadStudentInterests()
        }
        .refreshable {
            await refreshStudent()
            await planStateModel.fetch()
            await loadMeetings()
            await loadStudentInterests()
        }
        .sheet(isPresented: $showingCreatePlan) {
            NavigationStack {
                NewTMIPlanView(student: student) {
                    Task {
                        await planStateModel.refresh()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditStudent) {
            NavigationStack {
                EditStudentView(student: student) { updatedStudent in
                    student = updatedStudent
                    refreshID = UUID()
                }
            }
        }
        .sheet(isPresented: $showingAllPlans) {
            NavigationStack {
                StudentPlansListView(student: student, plans: studentPlans)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingAllPlans = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingProgress) {
            NavigationStack {
                StudentProgressView(student: student, plans: studentPlans)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingProgress = false
                            }
                        }
                    }
            }
        }
        .alert("Retake Survey?", isPresented: $showRetakeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Retake", role: .destructive) {
                retakeSurvey()
            }
        } message: {
            Text("This will allow \(student.name) to take the interest survey again. Current survey results will be replaced, but manually added interests will be preserved.")
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TMISpacing.md) {
                quickActionButton(
                    icon: "person.crop.circle.badge.checkmark",
                    label: "Student Mode",
                    color: .tmiSuccess,
                    action: { enableStudentMode() }
                )

                quickActionButton(
                    icon: "doc.badge.plus",
                    label: "Create Plan",
                    action: { showingCreatePlan = true }
                )

                quickActionButton(
                    icon: "list.clipboard",
                    label: "View Plans",
                    action: { showingAllPlans = true }
                )

                quickActionButton(
                    icon: "chart.bar",
                    label: "Progress",
                    action: { showingProgress = true }
                )
            }
            .padding(.horizontal, TMISpacing.screenPadding)
        }
        .padding(.horizontal, -TMISpacing.screenPadding)
    }

    private func quickActionButton(icon: String, label: String, color: Color = .tmiPrimary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: TMISpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(label)
                    .font(.tmiCaption)
                    .foregroundColor(.tmiTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 100, height: 80)
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
                value: "\(resolvedInterests.count)",
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
            HStack {
                Text("Interests")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                Spacer()

                // Show "Retake Survey" button if student has completed a survey
                if hasSurveyResults {
                    Button(action: {
                        showRetakeConfirmation = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 16))
                            Text("Retake")
                                .font(.tmiCaption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    showingAddInterest = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("Add")
                            .font(.tmiCaption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.tmiPrimary)
                }
                .buttonStyle(.plain)
            }

            if isLoadingInterests {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.tmiPrimary)
                    Spacer()
                }
                .padding(.vertical, TMISpacing.lg)
            } else if resolvedInterests.isEmpty {
                VStack(spacing: TMISpacing.md) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32))
                        .foregroundColor(.tmiTextTertiary)

                    Text("No interests recorded yet")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)

                    Text("Add interests to personalize \(student.name)'s learning experience")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextTertiary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: TMISpacing.md) {
                        TMIButton(
                            text: "Add Interest",
                            icon: "plus",
                            style: .secondary,
                            action: { showingAddInterest = true }
                        )

                        TMIButton(
                            text: "Take Survey",
                            icon: "list.clipboard",
                            style: .primary,
                            action: { showingSurvey = true }
                        )
                    }
                    .padding(.top, TMISpacing.sm)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, TMISpacing.lg)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TMISpacing.sm) {
                        ForEach(resolvedInterests, id: \.id) { interest in
                            StudentInterestBadge(
                                interest: interest,
                                level: getInterestLevel(for: interest.id ?? "")
                            )
                        }
                    }
                }
            }
        }
        .tmiCard()
        .sheet(isPresented: $showingAddInterest) {
            NavigationStack {
                AddInterestToStudentView(student: student) { updatedStudent in
                    student = updatedStudent
                    refreshID = UUID()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingAddInterest = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSurvey) {
            if let studentId = student.id {
                NavigationStack {
                    StudentSurveyFlow(studentId: studentId)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingSurvey = false
                                }
                                .foregroundColor(.tmiPrimary)
                            }
                        }
                }
                .onDisappear {
                    // Refresh student data after survey completion
                    Task {
                        await refreshStudent()
                    }
                }
            }
        }
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

    // MARK: - Meetings Section

    private var meetingsSection: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meetings")
                        .font(.tmiTitle3)
                        .foregroundColor(.tmiTextPrimary)

                    Text("Scheduled meetings for this student")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextSecondary)
                }

                Spacer()

                if !studentMeetings.isEmpty {
                    TMIBadge(
                        text: "\(studentMeetings.count)",
                        color: .tmiPrimary,
                        style: .solid
                    )
                }
            }

            if !studentMeetings.isEmpty {
                VStack(spacing: TMISpacing.sm) {
                    ForEach(studentMeetings.prefix(3)) { meeting in
                        NavigationLink(destination: MeetingDetailView(meeting: meeting, onUpdate: { Task { await loadMeetings() } })) {
                            meetingMiniCard(meeting)
                        }
                        .buttonStyle(.plain)
                    }

                    if studentMeetings.count > 3 {
                        NavigationLink(destination: MeetingListView()) {
                            HStack {
                                Text("View All \(studentMeetings.count) Meetings")
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
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 32))
                        .foregroundColor(.tmiTextTertiary)

                    Text("No meetings scheduled")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)

                    Text("Schedule a meeting to discuss \(student.name)'s progress")
                        .font(.tmiCaption)
                        .foregroundColor(.tmiTextTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, TMISpacing.lg)
            }
        }
        .tmiCard()
    }

    private func meetingMiniCard(_ meeting: Meeting) -> some View {
        HStack(spacing: TMISpacing.md) {
            // Meeting Type Icon
            ZStack {
                Circle()
                    .fill(Color(hex: meeting.meetingType.color).opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: meeting.meetingType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: meeting.meetingType.color))
            }

            // Meeting Info
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.tmiBody)
                    .fontWeight(.medium)
                    .foregroundColor(.tmiTextPrimary)

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text(meeting.startTime.formatted(date: .abbreviated, time: .shortened))
                        .font(.tmiCaption)
                }
                .foregroundColor(.tmiTextSecondary)

                if let location = meeting.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                        Text(location)
                            .font(.tmiCaption)
                    }
                    .foregroundColor(.tmiTextSecondary)
                }
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(meetingStatusColor(meeting.status))
                .frame(width: 8, height: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tmiTextTertiary)
        }
        .padding(TMISpacing.md)
        .background(
            RoundedRectangle(cornerRadius: TMIRadius.md)
                .fill(Color.tmiSurface)
        )
    }

    private func meetingStatusColor(_ status: Meeting.MeetingStatus) -> Color {
        switch status {
        case .scheduled: return .orange
        case .confirmed: return .cyan
        case .completed: return .green
        case .cancelled: return .red
        case .rescheduled: return .yellow
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
        case .chaseYourSpace: return "airplane.departure"
        case .acknowledgeInterests: return "heart.fill"
        case .alignYourMind: return "brain.head.profile"
        case .directAndCorrect: return "arrow.up.forward.circle.fill"
        case .bullyToBoss: return "person.fill.badge.plus"
        case .meekToProtector: return "shield.lefthalf.filled"
        }
    }

    private func planModelColor(for model: TMIPlanModel) -> Color {
        switch model {
        case .chaseYourSpace: return .blue
        case .acknowledgeInterests: return .pink
        case .alignYourMind: return .purple
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

    @MainActor
    private func refreshStudent() async {
        do {
            if let updatedStudent = try await studentService.getStudent(by: student.id ?? "") {
                student = updatedStudent
            }
        } catch {
            // If fetch fails, keep using the existing student
            print("Failed to refresh student: \(error)")
        }
    }

    @MainActor
    private func loadMeetings() async {
        do {
            let allMeetings = try await meetingService.fetchMeetings()
            studentMeetings = allMeetings.filter { meeting in
                meeting.relatedStudentIds.contains(student.id ?? "")
            }
            .sorted { $0.startTime < $1.startTime }
        } catch {
            print("Failed to load meetings: \(error)")
            studentMeetings = []
        }
    }

    private var hasSurveyResults: Bool {
        return student.surveyResults?.isEmpty == false
    }

    private func retakeSurvey() {
        // Clear survey results but keep manually added interests
        // For now, we'll just trigger the survey flow again
        // In a full implementation, we would mark which interests came from survey vs manual
        showingSurvey = true
    }

    // MARK: - Student Interest Loading (Phase 2)

    /// Load student interests from edge collection and resolve them via library
    @MainActor
    private func loadStudentInterests() async {
        guard let studentId = student.id else {
            print("[StudentDetailView] Cannot load interests: student has no ID")
            return
        }

        isLoadingInterests = true

        do {
            // Fetch student interest edges
            studentInterestEdges = try await studentInterestService.getStudentInterests(studentId: studentId)

            // Resolve interest IDs to full Interest objects
            var interests: [Interest] = []
            for edge in studentInterestEdges {
                if let interest = try await interestLibraryService.fetchInterest(id: edge.interestId) {
                    interests.append(interest)
                }
            }

            resolvedInterests = interests
            print("[StudentDetailView] Loaded \(resolvedInterests.count) interests for student \(student.name)")
        } catch {
            print("[StudentDetailView] Error loading student interests: \(error.localizedDescription)")
            resolvedInterests = []
        }

        isLoadingInterests = false
    }

    /// Get the affinity level for a specific interest
    private func getInterestLevel(for interestId: String) -> Int {
        studentInterestEdges.first { $0.interestId == interestId }?.level ?? 0
    }

    // MARK: - Student Mode

    private func enableStudentMode() {
        print("[StudentDetail] 🎓 Button tapped - Enabling student mode for: \(student.name)")

        // Use Task to avoid "modifying state during view update" warning
        Task { @MainActor in
            studentModeSession.startStudentMode(for: student)
            print("[StudentDetail] 🎓 Active student after start: \(studentModeSession.activeStudent?.name ?? "nil")")
        }
    }
}

// MARK: - Student Interest Badge (Phase 2)

/// Badge showing interest with affinity level indicator
private struct StudentInterestBadge: View {
    let interest: Interest
    let level: Int

    var body: some View {
        HStack(spacing: 6) {
            // Interest name
            Text(interest.name)
                .font(.tmiCaption)
                .fontWeight(.medium)

            // Affinity level stars
            if level > 0 {
                HStack(spacing: 2) {
                    ForEach(1...level, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(interest.primaryCategory?.color.opacity(0.2) ?? Color.tmiPrimary.opacity(0.2))
        )
        .overlay(
            Capsule()
                .stroke(interest.primaryCategory?.color ?? .tmiPrimary, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        StudentDetailView(student: Student.sampleStudent)
    }
}
