import Foundation
@preconcurrency import FirebaseAuth

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

nonisolated struct PendingStaffRegistration: Codable, Sendable, Equatable {
    let identityID: String
    let displayName: String
    let email: String
    let requestedRole: StaffRole
    let invitationCode: String
    let privacyPolicyVersion: String
    let acceptableUsePolicyVersion: String

    init(identity: AuthIdentity, request: StaffRegistrationRequest) {
        identityID = identity.userID
        displayName = request.displayName
        email = request.email
        requestedRole = request.requestedRole
        invitationCode = request.invitationCode
        privacyPolicyVersion = request.privacyPolicyVersion
        acceptableUsePolicyVersion = request.acceptableUsePolicyVersion
    }

    var request: StaffRegistrationRequest {
        StaffRegistrationRequest(
            displayName: displayName,
            email: email,
            password: "",
            requestedRole: requestedRole,
            invitationCode: invitationCode,
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

nonisolated protocol PendingStaffRegistrationStoring: Sendable {
    func save(_ registration: PendingStaffRegistration) async throws
    func pendingRegistration() async throws -> PendingStaffRegistration?
    func clear() async throws
}

nonisolated enum StaffInvitationProvisioningError: Error, Equatable {
    case claimRefreshPending
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
    private let pendingRegistrationStore: any PendingStaffRegistrationStoring

    init(
        backend: any AuthenticationBackend,
        sessionLoader: any AuthenticationSessionLoading,
        invitationProvisioner: any StaffInvitationProvisioning,
        pendingRegistrationStore: any PendingStaffRegistrationStoring =
            InMemoryPendingStaffRegistrationStore()
    ) {
        self.backend = backend
        self.sessionLoader = sessionLoader
        self.invitationProvisioner = invitationProvisioner
        self.pendingRegistrationStore = pendingRegistrationStore
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let identity = try await backend.signIn(
            email: normalizedEmail,
            password: password
        )
        if identity.isEmailVerified,
           let pendingRegistration = try await pendingRegistrationStore
            .pendingRegistration(),
           pendingRegistration.identityID == identity.userID {
            do {
                return try await completePendingRegistration(
                    pendingRegistration,
                    identity: identity
                )
            } catch {
                if error as? StaffInvitationProvisioningError == .claimRefreshPending {
                    throw error
                }
                try await rollbackRegistration()
                throw error
            }
        }
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
        let pendingRegistration = PendingStaffRegistration(
            identity: identity,
            request: request
        )

        do {
            try await pendingRegistrationStore.save(pendingRegistration)
            try await backend.sendVerification()
            guard identity.isEmailVerified else {
                return AuthSession(identity: identity, membership: nil)
            }
            return try await completePendingRegistration(
                pendingRegistration,
                identity: identity
            )
        } catch {
            if error as? StaffInvitationProvisioningError == .claimRefreshPending {
                throw error
            }
            try await rollbackRegistration()
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
        guard identity.isEmailVerified else {
            return AuthSession(identity: identity, membership: nil)
        }
        if let pendingRegistration = try await pendingRegistrationStore
            .pendingRegistration(),
           pendingRegistration.identityID == identity.userID {
            do {
                return try await completePendingRegistration(
                    pendingRegistration,
                    identity: identity
                )
            } catch {
                if error as? StaffInvitationProvisioningError == .claimRefreshPending {
                    throw error
                }
                try await rollbackRegistration()
                throw error
            }
        }
        return try await sessionLoader.session(for: identity)
    }

    func reauthenticate(password: String) async throws {
        try await backend.reauthenticate(password: password)
    }

    func signOut() async throws {
        try await backend.signOut()
    }

    private func completePendingRegistration(
        _ pendingRegistration: PendingStaffRegistration,
        identity: AuthIdentity
    ) async throws -> AuthSession {
        guard identity.isEmailVerified,
              pendingRegistration.identityID == identity.userID else {
            return AuthSession(identity: identity, membership: nil)
        }
        let membership = try await invitationProvisioner.provision(
            request: pendingRegistration.request,
            identity: identity
        )
        try await pendingRegistrationStore.clear()
        return AuthSession(identity: identity, membership: membership)
    }

    private func rollbackRegistration() async throws {
        do {
            try await backend.deleteCurrentUser()
            try await pendingRegistrationStore.clear()
        } catch {
            throw AuthenticationRepositoryError.registrationRollbackFailed
        }
    }
}

actor InMemoryPendingStaffRegistrationStore: PendingStaffRegistrationStoring {
    private var registration: PendingStaffRegistration?

    func save(_ registration: PendingStaffRegistration) {
        self.registration = registration
    }

    func pendingRegistration() -> PendingStaffRegistration? {
        registration
    }

    func clear() {
        registration = nil
    }
}

actor SecurePendingStaffRegistrationStore: PendingStaffRegistrationStoring {
    private static let storageKey = "authentication.pending-staff-registration"
    private let storage: SecureStorage

    init(storage: SecureStorage = .shared) {
        self.storage = storage
    }

    func save(_ registration: PendingStaffRegistration) async throws {
        try await storage.store(registration, for: Self.storageKey)
    }

    func pendingRegistration() async throws -> PendingStaffRegistration? {
        guard storage.exists(for: Self.storageKey) else {
            return nil
        }
        return try await storage.retrieve(
            PendingStaffRegistration.self,
            for: Self.storageKey
        )
    }

    func clear() async throws {
        guard storage.exists(for: Self.storageKey) else {
            return
        }
        try storage.delete(for: Self.storageKey)
    }
}

nonisolated enum FirebaseAuthenticationError: Error, Equatable {
    case noAuthenticatedUser
    case missingEmail
    case identityMismatch
}

@MainActor
final class FirebaseAuthenticationBackend: AuthenticationBackend {
    private let auth: Auth

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    func signIn(email: String, password: String) async throws -> AuthIdentity {
        let result = try await auth.signIn(withEmail: email, password: password)
        return identity(for: result.user)
    }

    func createUser(email: String, password: String) async throws -> AuthIdentity {
        let result = try await auth.createUser(withEmail: email, password: password)
        return identity(for: result.user)
    }

    func deleteCurrentUser() async throws {
        guard let user = auth.currentUser else {
            throw FirebaseAuthenticationError.noAuthenticatedUser
        }
        try await user.delete()
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }

    func sendVerification() async throws {
        guard let user = auth.currentUser else {
            throw FirebaseAuthenticationError.noAuthenticatedUser
        }
        try await user.sendEmailVerification()
    }

    func refreshIdentity() async throws -> AuthIdentity {
        guard let user = auth.currentUser else {
            throw FirebaseAuthenticationError.noAuthenticatedUser
        }
        try await user.reload()
        let token = try await user.getIDTokenResult(forcingRefresh: true)
        return AuthIdentity(
            userID: user.uid,
            email: user.email,
            isEmailVerified: user.isEmailVerified,
            districtID: token.claims[TrustedTenantClaim.districtIDClaimKey] as? String
        )
    }

    func reauthenticate(password: String) async throws {
        guard let user = auth.currentUser else {
            throw FirebaseAuthenticationError.noAuthenticatedUser
        }
        guard let email = user.email, !email.isEmpty else {
            throw FirebaseAuthenticationError.missingEmail
        }
        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: password
        )
        try await user.reauthenticate(with: credential)
        _ = try await user.getIDTokenResult(forcingRefresh: true)
    }

    func signOut() async throws {
        try auth.signOut()
    }

    private func identity(for user: User) -> AuthIdentity {
        AuthIdentity(
            userID: user.uid,
            email: user.email,
            isEmailVerified: user.isEmailVerified
        )
    }
}

@MainActor
final class FirebaseAuthenticationSessionLoader: AuthenticationSessionLoading {
    private let auth: Auth
    private let membershipProvider: any MembershipProviding

    init(
        auth: Auth = Auth.auth(),
        membershipProvider: any MembershipProviding
    ) {
        self.auth = auth
        self.membershipProvider = membershipProvider
    }

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        guard let user = auth.currentUser, user.uid == identity.userID else {
            throw FirebaseAuthenticationError.identityMismatch
        }
        guard identity.isEmailVerified else {
            return AuthSession(identity: identity, membership: nil)
        }

        let token = try await user.getIDTokenResult(forcingRefresh: true)
        let claim = try TrustedTenantClaim(
            userID: identity.userID,
            tokenClaims: token.claims
        )
        let trustedIdentity = AuthIdentity(
            userID: identity.userID,
            email: identity.email,
            isEmailVerified: identity.isEmailVerified,
            districtID: claim.districtID
        )

        do {
            let membership = try await membershipProvider.membership(for: claim)
            return AuthSession(
                identity: trustedIdentity,
                membership: membership
            )
        } catch MembershipRepositoryError.inactive {
            return AuthSession(
                identity: trustedIdentity,
                membershipState: .inactive
            )
        } catch MembershipRepositoryError.notFound {
            return AuthSession(
                identity: trustedIdentity,
                membership: nil
            )
        }
    }
}
