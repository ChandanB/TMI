#if DEBUG
import SwiftUI

@MainActor
private final class AuthenticationAcceptanceUITestingIdentityProvider:
    AuthenticationIdentityProviding
{
    private(set) var currentIdentity: AuthenticatedIdentity?
    private var listener: (@MainActor (AuthenticatedIdentity?) -> Void)?

    func trustedClaim(
        for identity: AuthenticatedIdentity
    ) async throws -> TrustedTenantClaim {
        guard identity == currentIdentity else {
            throw AuthenticationAcceptanceUITestingError.invalidIdentity
        }
        return TrustedTenantClaim(
            userID: identity.userID,
            districtID: AuthenticationAcceptanceFixture.districtID,
            accessClass: .staff,
            membershipVersion: 1
        )
    }

    func addStateDidChangeListener(
        _ listener: @escaping @MainActor (AuthenticatedIdentity?) -> Void
    ) -> AuthStateListenerHandle {
        self.listener = listener
        return AuthStateListenerHandle { [weak self] in
            self?.listener = nil
        }
    }

    func authenticate(userID: String) {
        let identity = AuthenticatedIdentity(
            userID: userID,
            isEmailVerified: true
        )
        currentIdentity = identity
        listener?(identity)
    }

    func signOut() {
        currentIdentity = nil
        listener?(nil)
    }
}

@MainActor
private final class AuthenticationAcceptanceUITestingRepository: AuthenticationProviding {
    private let identityProvider: AuthenticationAcceptanceUITestingIdentityProvider

    init(identityProvider: AuthenticationAcceptanceUITestingIdentityProvider) {
        self.identityProvider = identityProvider
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard email == AuthenticationAcceptanceFixture.signInEmail,
              password == AuthenticationAcceptanceFixture.password else {
            throw AuthenticationAcceptanceUITestingError.invalidCredentials
        }

        identityProvider.authenticate(
            userID: AuthenticationAcceptanceFixture.signInUserID
        )
        return AuthenticationAcceptanceFixture.session(
            userID: AuthenticationAcceptanceFixture.signInUserID,
            email: email
        )
    }

    func register(_ request: StaffRegistrationRequest) async throws -> AuthSession {
        let request = request.normalized
        guard request.displayName == AuthenticationAcceptanceFixture.invitationName,
              request.email == AuthenticationAcceptanceFixture.invitationEmail,
              request.password == AuthenticationAcceptanceFixture.password,
              request.requestedRole == .teacher,
              request.invitationCode == AuthenticationAcceptanceFixture.invitationCode,
              request.privacyPolicyVersion == StaffPolicyVersions.privacyPolicyVersion,
              request.acceptableUsePolicyVersion
                == StaffPolicyVersions.acceptableUsePolicyVersion else {
            throw AuthenticationAcceptanceUITestingError.invalidInvitation
        }

        identityProvider.authenticate(
            userID: AuthenticationAcceptanceFixture.invitationUserID
        )
        return AuthenticationAcceptanceFixture.session(
            userID: AuthenticationAcceptanceFixture.invitationUserID,
            email: request.email
        )
    }

    func completeStaffOnboarding(
        _ request: StaffOnboardingRequest
    ) async throws {
        throw AuthenticationAcceptanceUITestingError.invalidInvitation
    }

    func sendPasswordReset(email: String) async throws { }

    func sendVerification() async throws { }

    func refresh() async throws -> AuthSession {
        guard let identity = identityProvider.currentIdentity else {
            return .signedOut
        }
        return AuthenticationAcceptanceFixture.session(
            userID: identity.userID,
            email: AuthenticationAcceptanceFixture.email(for: identity.userID)
        )
    }

    func reauthenticate(password: String) async throws {
        guard password == AuthenticationAcceptanceFixture.password else {
            throw AuthenticationAcceptanceUITestingError.invalidCredentials
        }
    }

    func signOut() async throws {
        identityProvider.signOut()
    }
}

private struct AuthenticationAcceptanceUITestingProfileProvider: UserProfileProviding {
    func profile(for identity: AuthenticatedIdentity) async throws -> TMIUser? {
        guard let email = AuthenticationAcceptanceFixture.email(for: identity.userID),
              let displayName = AuthenticationAcceptanceFixture.displayName(
                for: identity.userID
              ) else {
            throw AuthenticationAcceptanceUITestingError.invalidIdentity
        }

        return TMIUser(
            id: identity.userID,
            userID: identity.userID,
            displayName: displayName,
            email: email,
            isEmailVerified: true,
            requestedRole: .teacher,
            createdAt: .distantPast
        )
    }
}

private enum AuthenticationAcceptanceUITestingError: Error {
    case invalidCredentials
    case invalidIdentity
    case invalidInvitation
}

private actor AuthenticationAcceptanceUITestingStudentRepository: StudentRepository {
    func page(
        _ request: StudentPageRequest,
        member: MembershipContext
    ) async throws -> StudentPage {
        StudentPage(records: [], nextCursor: nil, source: .server)
    }

    func student(
        id: String,
        member: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.notFound
    }

    func create(
        _ draft: StudentDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.unavailable
    }

    func reconcilePendingCreates(
        member: MembershipContext
    ) async throws -> [StudentRecord] {
        []
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        throw StudentRepositoryError.unavailable
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws {
        throw StudentRepositoryError.unavailable
    }
}

private enum AuthenticationAcceptanceFixture {
    static let districtID = "district-fixture"
    static let schoolID = "school-fixture"
    static let signInUserID = "authentication-sign-in-fixture"
    static let invitationUserID = "authentication-invitation-fixture"
    static let signInEmail = "educator@example.org"
    static let invitationEmail = "taylor@example.org"
    static let invitationName = "Taylor Educator"
    static let invitationCode = "DISTRICT-INVITE-2026"
    static let password = "release-one-password"

    static func membership(userID: String) -> MembershipContext {
        MembershipContext(
            userID: userID,
            districtID: districtID,
            schoolIDs: [schoolID],
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: [],
            isActive: true,
            version: 1
        )
    }

    static func session(userID: String, email: String?) -> AuthSession {
        AuthSession(
            identity: AuthIdentity(
                userID: userID,
                email: email,
                isEmailVerified: true,
                districtID: districtID
            ),
            membership: membership(userID: userID)
        )
    }

    static func email(for userID: String) -> String? {
        switch userID {
        case signInUserID:
            signInEmail
        case invitationUserID:
            invitationEmail
        default:
            nil
        }
    }

    static func displayName(for userID: String) -> String? {
        switch userID {
        case signInUserID:
            "Release 1 Educator"
        case invitationUserID:
            invitationName
        default:
            nil
        }
    }
}

@MainActor
struct AuthenticationAcceptanceUITestingContent: View {
    @State private var authStateModel: AuthStateModel
    @State private var appRouter = AppRouter()
    @State private var studentContext = StudentContextStateModel()

    private let dependencies: AppDependencies

    init() {
        let identityProvider = AuthenticationAcceptanceUITestingIdentityProvider()
        let authentication = AuthenticationAcceptanceUITestingRepository(
            identityProvider: identityProvider
        )
        let memberships = [
            AuthenticationAcceptanceFixture.membership(
                userID: AuthenticationAcceptanceFixture.signInUserID
            ),
            AuthenticationAcceptanceFixture.membership(
                userID: AuthenticationAcceptanceFixture.invitationUserID
            ),
        ]
        let membershipProvider = InMemoryMembershipProvider(
            memberships: memberships
        )
        let students = AuthenticationAcceptanceUITestingStudentRepository()
        let dependencies = AppDependencies(
            runtime: .preview,
            flags: .production,
            membership: membershipProvider,
            authentication: authentication,
            studentRepository: students,
            studentDetailRepository: Release1StudentDetailRepository(students: students),
            logger: TMILogger(category: "UITesting")
        )

        self.dependencies = dependencies
        _authStateModel = State(
            initialValue: AuthStateModel(
                authentication: authentication,
                identityProvider: identityProvider,
                profileProvider: AuthenticationAcceptanceUITestingProfileProvider(),
                membershipProvider: membershipProvider,
                automaticallyStart: false
            )
        )
    }

    var body: some View {
        NavigationStack {
            if authStateModel.isLoggedIn {
                StudentListView()
                    .accessibilityIdentifier(
                        "uiTesting.authentication.staffWorkspace"
                    )
            } else {
                AuthenticationView()
            }
        }
        .environment(\.appDependencies, dependencies)
        .environment(\.authStateModel, authStateModel)
        .environment(\.studentContext, studentContext)
        .environment(appRouter)
        .tint(TMIColors.teal)
        .preferredColorScheme(.light)
    }
}
#endif
