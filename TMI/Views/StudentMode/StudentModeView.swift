import SwiftUI

struct StudentModeView: View {
    let profile: StudentModeProfile

    @Environment(\.studentModeSession) private var session
    @Environment(\.studentContext) private var studentContext
    @Environment(\.appDependencies) private var dependencies

    @State private var showingExitConfirmation = false
    @State private var isExiting = false
    @State private var showingExitFailure = false
    @State private var surveyRepository: SurveyRepository?
    @State private var surveyActivity: SurveyActivity?
    @State private var surveyActivitySessionID: String?
    @State private var activityError: String?
    @State private var studentPlanRepository: StudentPlanProjectionRepository?
    @State private var studentPlanState: StudentPlanProjectionState?

    init(
        profile: StudentModeProfile,
        surveyRepository: SurveyRepository? = nil,
        studentPlanRepository: StudentPlanProjectionRepository? = nil
    ) {
        self.profile = profile
        _surveyRepository = State(initialValue: surveyRepository)
        _studentPlanRepository = State(initialValue: studentPlanRepository)
    }

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeader
                ScrollView {
                    VStack(spacing: 0) {
                        studentHeader
                        containedContent
                            .frame(minHeight: 280)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.studentAccessMode, .studentMode)
        .alert("Exit Student Mode?", isPresented: $showingExitConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Exit", role: .destructive) {
                exitStudentMode()
            }
        } message: {
            Text("Staff authentication required to exit Student Mode.")
        }
        .alert("Student Mode Remains Locked", isPresented: $showingExitFailure) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "The secure exit could not be completed. Student Mode remains contained. "
                    + "Check the connection and try again."
            )
        }
        .interactiveDismissDisabled(true)
        .task {
            guard !profile.studentID.isEmpty else {
                return
            }
            await studentContext.setActiveStudent(
                profile.studentID,
                student: nil,
                scope: .studentMode,
                prefetchEdges: false
            )
        }
        .onAppear {
            session.updateActivity()
            if session.isStudentModeActive, surveyRepository == nil {
                surveyRepository = .firebase()
            }
        }
        .task(id: activityRequestKey) {
            await loadSurveyActivity()
        }
        .task(id: planRequestKey) {
            await loadStudentPlans()
        }
        .task(id: session.currentGrant?.sessionID) {
            while !Task.isCancelled, session.isStudentModeActive {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                session.evaluate()
            }
        }
    }

    @ViewBuilder
    private var containedContent: some View {
        switch session.state {
        case .restoring:
            ContentUnavailableView {
                Label("Student Mode Locked", systemImage: "lock.shield.fill")
            } description: {
                if session.isRestorationInProgress {
                    Text(
                        "Checking the protected session. Staff tools remain locked until "
                            + "the session is safely resolved."
                    )
                } else {
                    Text(
                        "The protected session could not be checked. Staff tools remain "
                            + "locked. Check the connection and try again."
                    )
                }
            } actions: {
                Button {
                    Task { @MainActor in
                        await session.retryPersistedContainment()
                    }
                } label: {
                    if session.isRestorationInProgress {
                        ProgressView()
                    } else {
                        Label("Try Again", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.isRestorationInProgress)
                .accessibilityIdentifier("studentMode.restore.retry")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("studentMode.restoring")

        case .active(let grant):
            VStack(spacing: TMISpacing.lg) {
#if DEBUG
                if ProcessInfo.processInfo.arguments.contains("student-mode-survey") {
                    Button("Lock for test") {
                        session.evaluate(
                            at: Date().addingTimeInterval(
                                StudentModeSession.inactivityInterval + 1
                            )
                        )
                    }
                    .accessibilityIdentifier("studentMode.testLock")
                }
#endif
                if grant.scope.allowedOperations.contains(.readAssignment) {
                    surveyContent(grant: grant)
                }
                if grant.scope.allowedOperations.contains(.readStudentVisiblePlan) {
                    studentPlanContent
                }
                if !grant.scope.allowedOperations.contains(.readAssignment),
                   !grant.scope.allowedOperations.contains(.readStudentVisiblePlan) {
                    ContentUnavailableView(
                        "No activity available",
                        systemImage: "lock.shield",
                        description: Text("Ask your educator to start an activity for you.")
                    )
                }
            }

        case .locked(let reason):
            ContentUnavailableView {
                Label("Student Mode Locked", systemImage: "lock.shield.fill")
            } description: {
                Text(lockDescription(reason))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("studentMode.locked")

        case .expired:
            ContentUnavailableView {
                Label("Student Mode Ended", systemImage: "clock.badge.exclamationmark")
            } description: {
                Text("Ask your educator to securely exit this session.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("studentMode.expired")

        case .inactive:
            EmptyView()
        }
    }

    @ViewBuilder
    private func surveyContent(grant: StudentModeGrant) -> some View {
        if let surveyActivity,
           let surveyRepository,
           surveyActivitySessionID == grant.sessionID,
           surveyActivity.assignment.assignmentID == grant.scope.assignmentIDs.first {
            StudentSurveyFlow(
                assignment: surveyActivity.assignment,
                definition: surveyActivity.definition,
                grant: grant,
                repository: surveyRepository,
                onActivity: { session.recordActivity() }
            )
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in
                session.recordActivity()
            })
        } else if let activityError {
            ContentUnavailableView(
                "Activity unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(activityError)
            )
        } else {
            ProgressView("Getting your activity ready…")
        }
    }

    @ViewBuilder
    private var studentPlanContent: some View {
        if let studentPlanState {
            switch studentPlanState.phase {
            case .loaded(let projections):
                StudentPlanProjectionView(projections: projections)
            case .failed:
                ContentUnavailableView(
                    "Plan unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Your plan steps could not be loaded safely.")
                )
            case .idle, .loading:
                ProgressView("Getting your plan ready…")
            case .unavailable:
                EmptyView()
            }
        } else {
            ProgressView("Getting your plan ready…")
        }
    }

    private var customHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                studentModeTitle
                Spacer()
                exitButton
            }

            VStack(alignment: .leading, spacing: TMISpacing.sm) {
                studentModeTitle
                exitButton
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, TMISpacing.screenPadding)
        .padding(.vertical, TMISpacing.md)
        .background(Color.tmiBackground)
    }

    private var studentModeTitle: some View {
        Text("Student Mode")
            .font(.headline)
            .foregroundStyle(Color.tmiTextPrimary)
    }

    private var exitButton: some View {
        Button {
            showingExitConfirmation = true
        } label: {
            Label("Exit", systemImage: "lock.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.tmiWarning)
                .padding(.horizontal, TMISpacing.md)
                .padding(.vertical, TMISpacing.sm)
                .background(
                    Color.tmiWarning.opacity(0.2),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(isExiting)
        .accessibilityIdentifier("studentMode.exit")
    }

    private var studentHeader: some View {
        VStack(spacing: TMISpacing.md) {
            TMIAvatar(
                initials: profile.initials,
                color: .tmiPrimary,
                size: 80
            )

            VStack(spacing: TMISpacing.xxs) {
                Text("Welcome, \(profile.firstName)")
                    .font(.title2.bold())
                    .foregroundStyle(Color.tmiTextPrimary)

                if !profile.grade.isEmpty {
                    Text("Grade \(profile.grade)")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.tmiTextSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TMISpacing.lg)
        .padding(.horizontal, TMISpacing.screenPadding)
        .background(
            LinearGradient(
                colors: [
                    Color.tmiPrimary.opacity(0.3),
                    Color.tmiPrimary.opacity(0.1),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func lockDescription(_ reason: StudentModeLockReason) -> String {
        switch reason {
        case .inactivity:
            "Student Mode locked after being inactive. Ask your educator to securely exit."
        case .backgroundProtection:
            "Student Mode locked to protect your information."
        case .failedExitAttempts:
            "Student Mode locked after unsuccessful exit attempts."
        case .assignmentRevoked:
            "This activity is no longer available."
        case .coldRelaunch:
            "Student Mode was restored securely. Ask your educator to exit."
        }
    }

    private func exitStudentMode() {
        isExiting = true
        Task { @MainActor in
            let success = await session.exitStudentMode()
            isExiting = false
            showingExitFailure = !success
        }
    }

    private func loadSurveyActivity() async {
        guard let grant = session.currentGrant,
              grant.scope.allowedOperations.contains(.readAssignment),
              let assignmentID = grant.scope.assignmentIDs.first else {
            surveyActivity = nil
            surveyActivitySessionID = nil
            activityError = nil
            return
        }
        surveyActivity = nil
        surveyActivitySessionID = nil
        activityError = nil
        if surveyRepository == nil { surveyRepository = .firebase() }
        guard let surveyRepository else { return }
        do {
            let activity = try await surveyRepository.activity(grant: grant)
            guard session.currentGrant?.sessionID == grant.sessionID,
                  session.currentGrant?.scope.assignmentIDs.first == assignmentID,
                  activity.assignment.assignmentID == assignmentID else { return }
            surveyActivity = activity
            surveyActivitySessionID = grant.sessionID
            activityError = nil
        } catch {
            guard session.currentGrant?.sessionID == grant.sessionID,
                  session.currentGrant?.scope.assignmentIDs.first == assignmentID else { return }
            activityError = "Please ask your educator to check this assignment."
        }
    }

    private func loadStudentPlans() async {
        guard let grant = session.currentGrant,
              grant.scope.allowedOperations.contains(.readStudentVisiblePlan) else {
            studentPlanState?.clear()
            return
        }
        if studentPlanRepository == nil {
            studentPlanRepository = .canonical(dependencies: dependencies)
        }
        guard let studentPlanRepository else { return }
        if studentPlanState == nil {
            studentPlanState = StudentPlanProjectionState(repository: studentPlanRepository)
        }
        await studentPlanState?.load(grant: grant)
    }

    private var activityRequestKey: String {
        guard let grant = session.currentGrant else { return "inactive" }
        return "\(grant.sessionID):\(grant.scope.assignmentIDs.first ?? "missing")"
    }

    private var planRequestKey: String {
        guard let grant = session.currentGrant,
              grant.scope.allowedOperations.contains(.readStudentVisiblePlan) else {
            return "inactive"
        }
        return "\(grant.sessionID):\(grant.scope.studentID):\(grant.recordVersion)"
    }
}

#if DEBUG
@MainActor
struct StudentModeSurveyUITestingContent: View {
    @State private var session: StudentModeSession
    private let activity: SurveyActivity?
    private let repository: SurveyRepository?
    private let profile = StudentModeProfile(
        studentID: "student-ui",
        displayName: "Taylor Morgan",
        grade: "8",
        pronouns: nil
    )
    private let grant: StudentModeGrant?

    init() {
        let session = StudentModeSession(
            authenticateStaff: { true },
            securelyEndRespondentSession: { _ in },
            securelyReleaseVerifiedTerminal: { _ in }
        )
        _session = State(initialValue: session)

        guard let assignment = try? SurveyAssignment(
            assignmentID: "assignment-ui",
            attemptID: "attempt-ui",
            districtID: "district-ui",
            studentID: "student-ui",
            definitionID: "interest-discovery",
            definitionVersion: 1,
            state: .active,
            assignedAt: Date(timeIntervalSince1970: 1_735_689_600)
        ), let definition = Self.makeDefinition(),
        let scope = try? StudentModeScope(
            districtID: "district-ui",
            studentID: "student-ui",
            assignmentIDs: ["assignment-ui"],
            allowedOperations: StudentModeOperation.surveyAssignment
        ) else {
            activity = nil
            repository = nil
            grant = nil
            return
        }
        let activity = SurveyActivity(assignment: assignment, definition: definition)
        let grant = StudentModeGrant(
            sessionID: "session-ui",
            scope: scope,
            recordVersion: 1,
            issuedAt: Date(),
            expiresAt: .distantFuture,
            staffIdentity: StudentModeStaffIdentity(
                userID: "staff-ui",
                districtID: "district-ui",
                membershipVersion: 1
            )
        )
        self.activity = activity
        self.grant = grant
        repository = SurveyRepository(
            loadActivity: { _, _ in activity },
            requestHelp: { _, _ in },
            draftStore: .memory,
            synchronizeDraft: { request in
                var response = request.response
                response.markSynchronized(serverRecordVersion: response.recordVersion + 1)
                return response
            },
            submitResponse: { request in
                var response = request.response
                try response.markSubmitted(
                    operationID: request.operationID,
                    submittedAt: Date(),
                    serverRecordVersion: response.recordVersion + 1,
                    definition: request.definition,
                    sessionID: request.sessionID
                )
                return response
            },
            reviewResponse: { $0.response },
            isOnline: { true }
        )
    }

    var body: some View {
        Group {
            if grant != nil, let repository {
                if session.state == .inactive {
                    Text("Staff workspace restored")
                        .accessibilityIdentifier("studentMode.staffReturned")
                } else {
                    StudentModeView(profile: profile, surveyRepository: repository)
                        .environment(\.studentModeSession, session)
                }
            } else {
                ContentUnavailableView("Fixture unavailable", systemImage: "xmark.circle")
            }
        }
        .task {
            guard let grant, session.state != .active(grant) else { return }
            session.activate(grant, profile: profile)
        }
    }

    private static func makeDefinition() -> SurveyDefinition? {
        try? SurveyDefinition(
            id: "interest-discovery",
            version: 1,
            title: "Things I Like",
            publishedAt: Date(timeIntervalSince1970: 1_735_689_600),
            questions: [
                SurveyQuestion(
                    id: "activities",
                    prompt: "What kinds of things do you enjoy?",
                    kind: .multiSelect(maxSelections: 2),
                    isRequired: true,
                    options: [
                        SurveyOption(id: "create", label: "Making or creating things"),
                        SurveyOption(id: "help", label: "Helping people"),
                        SurveyOption(id: "explore", label: "Exploring how things work"),
                    ]
                ),
                SurveyQuestion(
                    id: "create-detail",
                    prompt: "What do you like to create?",
                    kind: .singleChoice,
                    isRequired: true,
                    options: [
                        SurveyOption(id: "art", label: "Art or designs"),
                        SurveyOption(id: "build", label: "Things I can build"),
                        SurveyOption(id: "stories", label: "Stories or music"),
                    ]
                ),
                SurveyQuestion(
                    id: "helping",
                    prompt: "Do you like helping other people?",
                    kind: .singleChoice,
                    isRequired: true,
                    options: [
                        SurveyOption(id: "yes", label: "Yes"),
                        SurveyOption(id: "sometimes", label: "Sometimes"),
                        SurveyOption(id: "not-now", label: "Not right now"),
                    ]
                ),
                SurveyQuestion(
                    id: "help-detail",
                    prompt: "When do you most enjoy helping?",
                    kind: .singleChoice,
                    isRequired: true,
                    options: [
                        SurveyOption(id: "team", label: "When I am part of a team"),
                        SurveyOption(id: "teach", label: "When I can explain something"),
                        SurveyOption(id: "care", label: "When someone needs care"),
                    ]
                ),
            ],
            branchRules: [
                SurveyBranchRule(
                    id: "show-create-detail",
                    sourceQuestionID: "activities",
                    targetQuestionID: "create-detail",
                    predicate: .contains("create")
                ),
                SurveyBranchRule(
                    id: "show-help-detail",
                    sourceQuestionID: "helping",
                    targetQuestionID: "help-detail",
                    predicate: .equals("yes")
                ),
            ]
        )
    }
}
#endif

#Preview {
    StudentModeView(
        profile: StudentModeProfile(
            studentID: "student-preview",
            displayName: "Taylor Student",
            grade: "7",
            pronouns: nil
        )
    )
    .environment(StudentModeSession())
}
