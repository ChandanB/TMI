//
//  StudentDetailView.swift
//  TMI
//
//  Simplified single-scroll student profile with pinned actions.
//  Sets shared StudentContext when displayed for cross-module coordination.
//

import SwiftUI
import Charts

struct StudentDetailView: View {
    let studentId: String
    @State private var stateModel: StudentDetailStateModel
    @State private var showingCreatePlan = false
    @State private var showingEditStudent = false
    @State private var showingAddInterest = false
    @State private var showingAllPlans = false
    @State private var showingProgress = false
    @State private var showingSurvey = false
    @State private var showRetakeConfirmation = false
    @State private var showingScheduleMeeting = false
    @State private var expandedSections: Set<String> = []
    @State private var planStateModel = TMIPlanListStateModel()
    @State private var interestsStateModel = InterestsAndHobbiesStateModel()
    @State private var studentMeetings: [Meeting] = []

    // Phase 2: Student Interest Edges
    @State private var studentInterestEdges: [StudentInterest] = []
    @State private var resolvedInterests: [Interest] = []
    @State private var isLoadingInterests = false

    // Saved Careers
    @State private var savedCareers: [Career] = []
    @State private var isLoadingSavedCareers = false

    // Environment dependencies
    @Environment(\.studentModeSession) private var studentModeSession
    @Environment(\.studentContext) private var studentContext
    @Environment(\.scheduleMeetingCoordinator) private var scheduleMeetingCoordinator

    private let meetingService = MeetingService.shared
    private let studentInterestService = StudentInterestService.shared
    private let interestLibraryService = InterestLibraryService.shared
    private let careerService = CareerService.shared

    init(studentId: String) {
        self.studentId = studentId
        _stateModel = State(initialValue: StudentDetailStateModel(studentId: studentId))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TMIBackgroundView(variant: .default)
                .ignoresSafeArea()

            contentView
        }
        .navigationTitle(stateModel.student?.name ?? "Student")
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
            // Start listening for real-time student updates
            stateModel.startListening()

            await planStateModel.fetch()
            await loadMeetings()
            await loadStudentInterests()
            await loadSavedCareers()
        }
        .onChange(of: stateModel.student?.id) { _, newStudentId in
            // Set shared student context when student loads
            if let student = stateModel.student, newStudentId != nil {
                Task {
                    await studentContext.setActiveStudent(
                        studentId,
                        student: student,
                        scope: .staff,
                        prefetchEdges: true
                    )
                }
            }
        }
        .onDisappear {
            // Stop listening when view disappears
            stateModel.stopListening()
        }
        .sheet(isPresented: $showingCreatePlan) {
            if let student = stateModel.student {
                NavigationStack {
                    TMIPlanEditorView(preselectedStudent: student, onPlanCreated: {
                        Task {
                            await planStateModel.refresh()
                        }
                    })
                }
                .tmiSheetStyle()
            }
        }
        .sheet(isPresented: $showingEditStudent) {
            if let student = stateModel.student {
                NavigationStack {
                    StudentProfileView(existingStudent: student) {
                        // No need to manually refresh - listener will update automatically
                    }
                }
                .tmiSheetStyle()
            }
        }
        .sheet(isPresented: $showingAllPlans) {
            if let student = stateModel.student {
                NavigationStack {
                    StudentPlansListView(student: student, plans: studentPlans(for: student))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingAllPlans = false
                                }
                            }
                        }
                }
                .tmiSheetStyle()
            }
        }
        .sheet(isPresented: $showingProgress) {
            if let student = stateModel.student {
                NavigationStack {
                    StudentProgressView(student: student, plans: studentPlans(for: student))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showingProgress = false
                                }
                            }
                        }
                }
                .tmiSheetStyle()
            }
        }
        .alert("Retake Survey?", isPresented: $showRetakeConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Retake", role: .destructive) {
                retakeSurvey()
            }
        } message: {
            if let student = stateModel.student {
                Text("This will allow \(student.name) to take the interest survey again. Current survey results will be replaced, but manually added interests will be preserved.")
            }
        }

        // MARK: - Interests Section Sheet: showingSurvey replaced with corrected labeled parameters
        .sheet(isPresented: $showingSurvey, onDismiss: {
            // Refresh interests after survey completion
            Task {
                await loadStudentInterests()
            }
        }) {
            if let student = stateModel.student, let studentId = student.id {
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
                .tmiSheetStyle()
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch stateModel.state {
        case .loading:
            VStack(spacing: TMISpacing.md) {
                ProgressView()
                    .tint(.tmiPrimary)
                Text("Loading student...")
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
            }

        case .error(let error):
            VStack(spacing: TMISpacing.md) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                Text("Failed to load student")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)
                Text(error.localizedDescription)
                    .font(.tmiBody)
                    .foregroundColor(.tmiTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(TMISpacing.screenPadding)

        case .loaded, .idle:
            if let student = stateModel.student {
                studentContentView(student: student)
            } else {
                VStack(spacing: TMISpacing.md) {
                    ProgressView()
                        .tint(.tmiPrimary)
                    Text("Loading student...")
                        .font(.tmiBody)
                        .foregroundColor(.tmiTextSecondary)
                }
            }
        }
    }

    // MARK: - Student Content View

    @ViewBuilder
    private func studentContentView(student: Student) -> some View {
        ScrollView {
            VStack(spacing: TMISpacing.lg) {
                // Hero Section
                heroSection(student: student)

                // Quick Actions
                quickActionsRow(student: student)

                // Key Stats
                keyStatsSection(student: student)

                // Interests Section
                interestsSection(student: student)

                // Saved Careers Section
                savedCareersSection(student: student)

                // TMI Plans Section
                tmiPlansSection(student: student)

                // Meetings Section
                meetingsSection(student: student)

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
    }

    // MARK: - Hero Section

    private func heroSection(student: Student) -> some View {
        VStack(spacing: TMISpacing.md) {
            // Avatar
            TMIAvatar(
                initials: student.initials,
                color: avatarColor(for: student),
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

    private func quickActionsRow(student: Student) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TMISpacing.md) {
                quickActionButton(
                    icon: "person.crop.circle.badge.checkmark",
                    label: "Student Mode",
                    color: .tmiSuccess,
                    action: { enableStudentMode(student: student) }
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

    private func keyStatsSection(student: Student) -> some View {
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

    private func interestsSection(student: Student) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            HStack {
                Text("Interests")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                Spacer()

                // Show "Retake Survey" button if student has completed a survey
                if hasSurveyResults(for: student) {
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
            if let student = stateModel.student {
                NavigationStack {
                    AddInterestToStudentView(student: student) { _ in
                        // No need to manually refresh - listener will update automatically
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showingAddInterest = false
                            }
                        }
                    }
                }
                .tmiSheetStyle()
            }
        }
    }

    // MARK: - Saved Careers Section

    private func savedCareersSection(student: Student) -> some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            if isLoadingSavedCareers {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.tmiPrimary)
                    Spacer()
                }
                .padding(.vertical, TMISpacing.lg)
            } else if !savedCareers.isEmpty {
                Text("Saved Careers")
                    .font(.tmiTitle3)
                    .foregroundColor(.tmiTextPrimary)

                VStack(alignment: .leading, spacing: TMISpacing.md) {
                    ForEach(savedCareers) { career in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(career.title)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.tmiTextPrimary)
                                Text(career.field)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(career.education)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .tmiCard()
    }

    // MARK: - TMI Plans Section

    private func tmiPlansSection(student: Student) -> some View {
        let studentPlans = self.studentPlans(for: student)

        return VStack(alignment: .leading, spacing: TMISpacing.md) {
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

                if !studentPlans.isEmpty {
                    TMIBadge(
                        text: "\(studentPlans.count)",
                        color: .tmiPrimary,
                        style: .solid
                    )
                }
            }

            if !studentPlans.isEmpty {
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
    }

    // MARK: - Meetings Section

    private func meetingsSection(student: Student) -> some View {
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

                    TMIButton(
                        text: "Schedule Meeting",
                        icon: "calendar.badge.plus",
                        style: .secondary,
                        action: {
                            scheduleMeetingCoordinator.startScheduling(
                                forStudentId: student.id,
                                withStudents: [student]
                            )
                        }
                    )
                    .padding(.top, TMISpacing.sm)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, TMISpacing.lg)
            }
        }
        .tmiCard()
        .sheet(isPresented: Binding(
            get: { scheduleMeetingCoordinator.isShowingScheduler },
            set: { scheduleMeetingCoordinator.isShowingScheduler = $0 }
        )) {
            if let studentId = student.id {
                ScheduleMeetingView(
                    planId: scheduleMeetingCoordinator.planId ?? "",
                    relatedStudentIds: [studentId]
                )
                .tmiSheetStyle()
            }
        }
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

    private func studentPlans(for student: Student) -> [TMIPlan] {
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

    private func toggleSection(_ section: String) {
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
    }

    @MainActor
    private func loadMeetings() async {
        do {
            let allMeetings = try await meetingService.fetchMeetings()
            studentMeetings = allMeetings.filter { meeting in
                meeting.relatedStudentIds.contains(studentId)
            }
            .sorted { $0.startTime < $1.startTime }
        } catch {
            print("Failed to load meetings: \(error)")
            studentMeetings = []
        }
    }

    private func hasSurveyResults(for student: Student) -> Bool {
        return student.surveyResults?.isEmpty == false
    }

    private func retakeSurvey() {
        Task {
            do {
                guard let student = stateModel.student, let studentId = student.id else { return }

                // Clear survey-generated interests from edge collection
                // This preserves manually added interests (source != .survey)
                try await StudentInterestService.shared.clearSurveyInterests(studentId: studentId)

                // Archive the old survey response in Firestore
                try await SurveyService.shared.archiveLatestSurvey(studentId: studentId)

                print("[StudentDetail] Survey data cleared, preserving manual interests")

                // Now show the survey
                await MainActor.run {
                    showingSurvey = true
                }

                // Refresh interests after clearing
                await loadStudentInterests()
            } catch {
                print("[StudentDetail] Error clearing survey data: \(error.localizedDescription)")
                // Show survey anyway
                await MainActor.run {
                    showingSurvey = true
                }
            }
        }
    }

    // MARK: - Student Interest Loading (Phase 2)

    /// Load student interests from edge collection and resolve them via library
    @MainActor
    private func loadStudentInterests() async {
        isLoadingInterests = true

        do {
            // Fetch student interest edges
            studentInterestEdges = try await studentInterestService.getStudentInterests(studentId: studentId)

            // Resolve interest IDs to full Interest objects.
            // Primary: look up in Firestore global library.
            // Fallback: match against PredefinedInterestsData so survey-saved interests
            //           (which use stable hash IDs) resolve even if the library isn't seeded.
            var interests: [Interest] = []
            for edge in studentInterestEdges {
                if let firestoreInterest = try await interestLibraryService.fetchInterest(id: edge.interestId) {
                    interests.append(firestoreInterest)
                } else if let predefined = PredefinedInterestsData.allPredefinedInterests.first(where: { $0.id == edge.interestId }) {
                    interests.append(predefined)
                    print("[StudentDetailView] Resolved interest \(edge.interestId) from PredefinedInterestsData")
                } else {
                    print("[StudentDetailView] Could not resolve interest ID: \(edge.interestId)")
                }
            }

            resolvedInterests = interests
            print("[StudentDetailView] Loaded \(resolvedInterests.count) interests for student ID: \(studentId)")
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

    private func loadSavedCareers() async {
        isLoadingSavedCareers = true
        defer { isLoadingSavedCareers = false }
        do {
            savedCareers = try await careerService.fetchSavedCareers(for: studentId)
        } catch {
            print("Failed to load saved careers: \(error)")
        }
    }

    // MARK: - Student Mode

    private func enableStudentMode(student: Student) {
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
        StudentDetailView(studentId: Student.sampleStudent.id ?? "preview-student-id")
    }
}
