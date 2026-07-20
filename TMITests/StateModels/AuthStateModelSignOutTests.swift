import Foundation
import Testing
@testable import TMI

@Suite("Auth State Model Sign Out", .serialized)
@MainActor
struct AuthStateModelSignOutTests {
    @Test("A failed sign-out preserves authentication and records the error")
    func failedSignOutPreservesAuthentication() {
        let user = makeUser()
        let model = AuthStateModel(signOutOperation: {
            throw SignOutTestError.serviceUnavailable
        })
        model.updateState(.loaded(.authenticated(user)))

        let didSignOut = model.signOut()
        let capturedAuthenticationError: AuthenticationError? = model.currentError

        #expect(didSignOut == false)
        #expect(model.isLoggedIn)
        #expect(model.currentAuthState == .authenticated(user))
        #expect(capturedAuthenticationError?.type == AuthenticationErrorType.serverError)
        #expect(capturedAuthenticationError?.message.contains("service unavailable") == true)
    }

    @Test("A successful sign-out clears authentication")
    func successfulSignOutClearsAuthentication() {
        let user = makeUser()
        var operationWasCalled = false
        let model = AuthStateModel(signOutOperation: {
            operationWasCalled = true
        })
        model.updateState(.loaded(.authenticated(user)))

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
}

private enum SignOutTestError: LocalizedError {
    case serviceUnavailable

    var errorDescription: String? {
        "service unavailable"
    }
}
