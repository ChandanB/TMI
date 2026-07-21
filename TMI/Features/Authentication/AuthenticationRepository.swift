import Foundation

nonisolated struct StaffRegistrationRequest: Sendable, Equatable {
    let displayName: String
    let email: String
    let password: String
    let requestedRole: StaffRole
    let invitationCode: String
    let privacyPolicyVersion: String
    let acceptableUsePolicyVersion: String

    var normalized: StaffRegistrationRequest {
        StaffRegistrationRequest(
            displayName: displayName
                .split(whereSeparator: \.isWhitespace)
                .joined(separator: " "),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            password: password,
            requestedRole: requestedRole,
            invitationCode: invitationCode.trimmingCharacters(in: .whitespacesAndNewlines),
            privacyPolicyVersion: privacyPolicyVersion,
            acceptableUsePolicyVersion: acceptableUsePolicyVersion
        )
    }
}

@MainActor
protocol AuthenticationProviding: Sendable {
    func signIn(email: String, password: String) async throws -> AuthSession
    func register(_ request: StaffRegistrationRequest) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func sendVerification() async throws
    func refresh() async throws -> AuthSession
    func reauthenticate(password: String) async throws
    func signOut() async throws
}

@MainActor
protocol AuthenticationBackend {
    func signIn(email: String, password: String) async throws -> AuthIdentity
    func createUser(email: String, password: String) async throws -> AuthIdentity
    func deleteCurrentUser() async throws
    func sendPasswordReset(email: String) async throws
    func sendVerification() async throws
    func refreshIdentity() async throws -> AuthIdentity
    func reauthenticate(password: String) async throws
    func signOut() async throws
}

@MainActor
protocol AuthenticationSessionLoading {
    func session(for identity: AuthIdentity) async throws -> AuthSession
}

@MainActor
protocol StaffInvitationProvisioning {
    func provision(
        request: StaffRegistrationRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext
}

nonisolated enum AuthenticationRepositoryError: Error, Equatable {
    case invitationRequired
    case registrationRollbackFailed
}

@MainActor
final class AuthenticationRepository: AuthenticationProviding {
    private let backend: any AuthenticationBackend
    private let sessionLoader: any AuthenticationSessionLoading
    private let invitationProvisioner: any StaffInvitationProvisioning

    init(
        backend: any AuthenticationBackend,
        sessionLoader: any AuthenticationSessionLoading,
        invitationProvisioner: any StaffInvitationProvisioning
    ) {
        self.backend = backend
        self.sessionLoader = sessionLoader
        self.invitationProvisioner = invitationProvisioner
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let identity = try await backend.signIn(
            email: normalizedEmail,
            password: password
        )
        return try await sessionLoader.session(for: identity)
    }

    func register(_ request: StaffRegistrationRequest) async throws -> AuthSession {
        let request = request.normalized
        guard !request.invitationCode.isEmpty else {
            throw AuthenticationRepositoryError.invitationRequired
        }

        let identity = try await backend.createUser(
            email: request.email,
            password: request.password
        )

        do {
            let membership = try await invitationProvisioner.provision(
                request: request,
                identity: identity
            )
            try await backend.sendVerification()
            return AuthSession(identity: identity, membership: membership)
        } catch {
            do {
                try await backend.deleteCurrentUser()
            } catch {
                throw AuthenticationRepositoryError.registrationRollbackFailed
            }
            throw error
        }
    }

    func sendPasswordReset(email: String) async throws {
        try await backend.sendPasswordReset(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    func sendVerification() async throws {
        try await backend.sendVerification()
    }

    func refresh() async throws -> AuthSession {
        let identity = try await backend.refreshIdentity()
        return try await sessionLoader.session(for: identity)
    }

    func reauthenticate(password: String) async throws {
        try await backend.reauthenticate(password: password)
    }

    func signOut() async throws {
        try await backend.signOut()
    }
}
