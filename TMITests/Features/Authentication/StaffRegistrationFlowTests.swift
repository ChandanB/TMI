import Foundation
import Testing
@testable import TMI

@Suite("Staff registration flow")
@MainActor
struct StaffRegistrationFlowTests {
    @Test("Successful registration waits for its exact trusted identity")
    func successWaitsForMatchingIdentity() async {
        let authentication = RegistrationFlowAuthenticationFake(
            registerResults: [.success(session(userID: "created-user"))]
        )
        let flow = StaffRegistrationFlow()

        let accepted = await flow.submit(request(), using: authentication)

        #expect(accepted)
        #expect(flow.phase == .awaitingAuthorization(userID: "created-user"))
        #expect(flow.isOperationActive)
        #expect(flow.expectedIdentityID == "created-user")
        #expect(flow.acceptPublishedIdentity("other-user") == false)
        #expect(flow.phase == .awaitingAuthorization(userID: "created-user"))
        #expect(flow.acceptPublishedIdentity("created-user"))
        #expect(flow.phase == .complete)
        #expect(authentication.registerCallCount == 1)
        #expect(authentication.refreshCallCount == 0)
    }

    @Test("Terminal registration failure permits correction without recovery")
    func terminalFailureStopsOperation() async {
        let authentication = RegistrationFlowAuthenticationFake(
            registerResults: [.failure(RegistrationFlowTestError.terminal)]
        )
        let flow = StaffRegistrationFlow()

        let accepted = await flow.submit(request(), using: authentication)

        #expect(accepted)
        #expect(
            flow.phase == .failed(
                message: AuthenticationPresentationPolicy.registrationFailureMessage,
                recoveryAvailable: false
            )
        )
        #expect(flow.isOperationActive == false)
        #expect(flow.recoveryAvailable == false)
        #expect(authentication.registerCallCount == 1)
        #expect(authentication.refreshCallCount == 0)
    }

    @Test("Ambiguous result recovers without creating a second identity")
    func ambiguousResultUsesRefreshOnly() async {
        let authentication = RegistrationFlowAuthenticationFake(
            registerResults: [
                .failure(StaffInvitationProvisioningError.claimRefreshPending),
            ],
            refreshResults: [
                .failure(StaffInvitationProvisioningError.claimRefreshPending),
                .success(session(userID: "created-user")),
            ]
        )
        let flow = StaffRegistrationFlow()

        let accepted = await flow.submit(request(), using: authentication)

        #expect(accepted)
        #expect(flow.recoveryAvailable)
        #expect(
            flow.errorMessage
                == AuthenticationPresentationPolicy.registrationRecoveryMessage
        )
        #expect(authentication.registerCallCount == 1)
        #expect(authentication.refreshCallCount == 1)

        let duplicateAccepted = await flow.submit(request(), using: authentication)

        #expect(duplicateAccepted == false)
        #expect(authentication.registerCallCount == 1)
        #expect(authentication.refreshCallCount == 1)

        await flow.retryRecovery(using: authentication)

        #expect(flow.phase == .awaitingAuthorization(userID: "created-user"))
        #expect(authentication.registerCallCount == 1)
        #expect(authentication.refreshCallCount == 2)
    }

    @Test("Finished authorization fails closed for a missing identity")
    func missingAuthorizedIdentityFailsClosed() async {
        let authentication = RegistrationFlowAuthenticationFake(
            registerResults: [.success(session(userID: "created-user"))]
        )
        let flow = StaffRegistrationFlow()
        await flow.submit(request(), using: authentication)

        #expect(flow.finishAuthorization(with: nil) == false)
        #expect(flow.isOperationActive == false)
        #expect(flow.errorMessage == AuthStateModel.organizationAccessErrorMessage)
    }

    @Test("Finished authorization fails closed for a mismatched identity")
    func mismatchedAuthorizedIdentityFailsClosed() async {
        let authentication = RegistrationFlowAuthenticationFake(
            registerResults: [.success(session(userID: "created-user"))]
        )
        let flow = StaffRegistrationFlow()
        await flow.submit(request(), using: authentication)

        #expect(flow.finishAuthorization(with: "other-user") == false)
        #expect(
            flow.phase == .failed(
                message: AuthStateModel.organizationAccessErrorMessage,
                recoveryAvailable: false
            )
        )
    }

    @Test("Registration session without an identity fails terminally")
    func missingRegistrationIdentityFailsTerminally() async {
        let authentication = RegistrationFlowAuthenticationFake(
            registerResults: [.success(.signedOut)]
        )
        let flow = StaffRegistrationFlow()

        await flow.submit(request(), using: authentication)

        #expect(
            flow.phase == .failed(
                message: AuthenticationPresentationPolicy.registrationFailureMessage,
                recoveryAvailable: false
            )
        )
        #expect(flow.isOperationActive == false)
        #expect(authentication.registerCallCount == 1)
        #expect(authentication.refreshCallCount == 0)
    }

    private func request() -> StaffRegistrationRequest {
        StaffRegistrationRequest(
            displayName: "Morgan Lee",
            email: "morgan@example.edu",
            password: "secure-password",
            requestedRole: .teacher,
            invitationCode: "invite-a",
            privacyPolicyVersion: StaffPolicyVersions.privacyPolicyVersion,
            acceptableUsePolicyVersion: StaffPolicyVersions.acceptableUsePolicyVersion
        )
    }

    private func session(userID: String) -> AuthSession {
        AuthSession(
            identity: AuthIdentity(
                userID: userID,
                email: "morgan@example.edu",
                isEmailVerified: true
            ),
            membership: nil
        )
    }
}

private enum RegistrationFlowTestError: Error {
    case terminal
    case unexpectedCall
}

@MainActor
private final class RegistrationFlowAuthenticationFake: AuthenticationProviding {
    private var registerResults: [Result<AuthSession, any Error>]
    private var refreshResults: [Result<AuthSession, any Error>]

    private(set) var registerCallCount = 0
    private(set) var refreshCallCount = 0

    init(
        registerResults: [Result<AuthSession, any Error>] = [],
        refreshResults: [Result<AuthSession, any Error>] = []
    ) {
        self.registerResults = registerResults
        self.refreshResults = refreshResults
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        throw RegistrationFlowTestError.unexpectedCall
    }

    func register(_ request: StaffRegistrationRequest) async throws -> AuthSession {
        registerCallCount += 1
        guard !registerResults.isEmpty else {
            throw RegistrationFlowTestError.unexpectedCall
        }
        return try registerResults.removeFirst().get()
    }

    func completeStaffOnboarding(_ request: StaffOnboardingRequest) async throws {
        throw RegistrationFlowTestError.unexpectedCall
    }

    func sendPasswordReset(email: String) async throws {
        throw RegistrationFlowTestError.unexpectedCall
    }

    func sendVerification() async throws {
        throw RegistrationFlowTestError.unexpectedCall
    }

    func refresh() async throws -> AuthSession {
        refreshCallCount += 1
        guard !refreshResults.isEmpty else {
            throw RegistrationFlowTestError.unexpectedCall
        }
        return try refreshResults.removeFirst().get()
    }

    func reauthenticate(password: String) async throws {
        throw RegistrationFlowTestError.unexpectedCall
    }

    func signOut() async throws {
        throw RegistrationFlowTestError.unexpectedCall
    }
}
