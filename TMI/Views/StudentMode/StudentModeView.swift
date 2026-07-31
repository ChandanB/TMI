import SwiftUI

struct StudentModeView: View {
    let profile: StudentModeProfile

    @Environment(\.studentModeSession) private var session
    @Environment(\.studentContext) private var studentContext

    @State private var showingExitConfirmation = false
    @State private var isExiting = false
    @State private var showingExitFailure = false

    var body: some View {
        ZStack {
            Color.tmiBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                customHeader
                studentHeader
                containedContent
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
            await studentContext.setActiveStudent(
                profile.studentID,
                student: nil,
                scope: .studentMode,
                prefetchEdges: false
            )
        }
        .onAppear {
            session.updateActivity()
        }
    }

    @ViewBuilder
    private var containedContent: some View {
        switch session.state {
        case .active:
            ContentUnavailableView {
                Label("Your Activity", systemImage: "list.clipboard")
            } description: {
                Text("Your educator will guide you through the assigned activity.")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
        HStack {
            Text("Student Mode")
                .font(.headline)
                .foregroundStyle(Color.tmiTextPrimary)

            Spacer()

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
        .padding(.horizontal, TMISpacing.screenPadding)
        .padding(.vertical, TMISpacing.md)
        .background(Color.tmiBackground)
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

                Text("Grade \(profile.grade)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.tmiTextSecondary)
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
