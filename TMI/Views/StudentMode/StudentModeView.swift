import SwiftUI

struct StudentModeView: View {
    let profile: StudentModeProfile

    @Environment(\.studentModeSession) private var session
    @Environment(\.studentContext) private var studentContext

    @State private var showingExitConfirmation = false
    @State private var isExiting = false
    @State private var showingExitFailure = false
    @State private var surveyRepository: SurveyRepository?

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
            if let assignment = surveyAssignment(for: grant),
               let definition = Self.interestSurveyDefinition,
               let surveyRepository {
                StudentSurveyFlow(
                    assignment: assignment,
                    definition: definition,
                    grant: grant,
                    repository: surveyRepository
                )
            } else {
                ProgressView("Getting your activity ready…")
                    .task {
                        if surveyRepository == nil { surveyRepository = .firebase() }
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

    private func surveyAssignment(for grant: StudentModeGrant) -> SurveyAssignment? {
        guard let assignmentID = grant.scope.assignmentIDs.first else { return nil }
        return try? SurveyAssignment(
            assignmentID: assignmentID,
            attemptID: grant.sessionID,
            districtID: grant.scope.districtID,
            studentID: grant.scope.studentID,
            definitionID: "interest-discovery",
            definitionVersion: 1,
            state: .active,
            assignedAt: grant.issuedAt
        )
    }

    private static let interestSurveyDefinition = try? SurveyDefinition(
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
