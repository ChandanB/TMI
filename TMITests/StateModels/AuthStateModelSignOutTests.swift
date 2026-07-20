import Foundation
import Testing
@testable import TMI

@Suite("Auth State Model Sign Out", .serialized)
@MainActor
struct AuthStateModelSignOutTests {
    @Test("A failed sign-out preserves authentication and records the error")
    func failedSignOutPreservesAuthentication() {
        let user = makeUser()
        let session = makeSession(user: user)
        let model = AuthStateModel(signOutOperation: {
            throw SignOutTestError.serviceUnavailable
        }, automaticallyStart: false)
        model.updateState(.loaded(.authenticated(session)))

        let didSignOut = model.signOut()
        let capturedAuthenticationError: AuthenticationError? = model.currentError

        #expect(didSignOut == false)
        #expect(model.isLoggedIn)
        #expect(model.currentAuthState == .authenticated(session))
        #expect(capturedAuthenticationError?.type == AuthenticationErrorType.serverError)
        #expect(capturedAuthenticationError?.message.contains("service unavailable") == true)
    }

    @Test("A successful sign-out clears authentication")
    func successfulSignOutClearsAuthentication() {
        let user = makeUser()
        let session = makeSession(user: user)
        var operationWasCalled = false
        let model = AuthStateModel(signOutOperation: {
            operationWasCalled = true
        }, automaticallyStart: false)
        model.updateState(.loaded(.authenticated(session)))

        let didSignOut = model.signOut()
        let capturedAuthenticationError: AuthenticationError? = model.currentError

        #expect(didSignOut)
        #expect(operationWasCalled)
        #expect(model.isLoggedIn == false)
        #expect(model.currentAuthState == AuthenticationState.unauthenticated)
        #expect(capturedAuthenticationError == nil)
    }

    private func makeUser() -> TMIUser {
        TMIUser(
            id: "sign-out-test-user",
            email: "educator@example.com",
            displayName: "Test Educator",
            role: .teacher,
            profileCreatedDate: .distantPast
        )
    }

    private func makeSession(user: TMIUser) -> AuthenticatedSession {
        let claim = TrustedTenantClaim(
            userID: user.userID,
            districtID: "district-1",
            accessClass: .staff,
            membershipVersion: 1
        )
        let membership = MembershipContext(
            userID: user.userID,
            districtID: "district-1",
            schoolIDs: ["school-1"],
            role: .teacher,
            capabilities: [.studentReadDetail],
            assignedStudentIDs: ["student-1"],
            isActive: true,
            version: 1
        )
        return AuthenticatedSession(
            profile: user,
            claim: claim,
            membership: membership
        )
    }
}

private enum SignOutTestError: LocalizedError {
    case serviceUnavailable

    var errorDescription: String? {
        "service unavailable"
    }
}
