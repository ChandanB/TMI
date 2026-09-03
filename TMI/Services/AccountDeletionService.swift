import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseFunctions

nonisolated struct AccountDeletionPolicy: Sendable, Equatable {
    let personalSubcollections: Set<String>
    let retainedSubcollections: Set<String>

    var isValid: Bool {
        !personalSubcollections.isEmpty
            && !retainedSubcollections.isEmpty
            && personalSubcollections.isDisjoint(with: retainedSubcollections)
    }

    static let production = AccountDeletionPolicy(
        personalSubcollections: [
            "private",
            "preferences",
            "notifications",
            "recommendations",
            "savedCareers",
            "careerBookmarks",
            "careerExplorations",
            "careerState",
            "settings",
            "activity",
            "interests",
            "hobbies",
            "resources",
        ],
        retainedSubcollections: [
            "students",
            "plans",
            "tmiPlans",
            "formTemplates",
            "formAssignments",
            "formSubmissions",
            "meetings",
            "interestSurveys",
            "consents",
            "restrictedRecords",
            "auditLogs",
            "auditEvents",
            "complianceAudits",
            "metricSnapshots",
        ]
    )
}

nonisolated struct AccountDeletionIdentity: Sendable, Equatable {
    let userID: String
    let email: String
}

nonisolated enum AccountDeletionError: LocalizedError, Equatable {
    case noAuthenticatedUser
    case missingEmail
    case incorrectPassword
    case invalidPolicy
    case invalidOperation
    case cleanupFailed

    var errorDescription: String? {
        switch self {
        case .noAuthenticatedUser:
            return "No authenticated account was found."
        case .missingEmail:
            return "This account cannot be verified with an email and password."
        case .incorrectPassword:
            return "Incorrect password. Please try again."
        case .invalidPolicy, .invalidOperation:
            return "Account deletion is unavailable because its safety checks failed."
        case .cleanupFailed:
            return "Account deletion could not be completed. Check your connection and try again."
        }
    }
}

@MainActor
protocol AccountDeletionBackend: AnyObject {
    func currentIdentity() throws -> AccountDeletionIdentity
    func reauthenticate(email: String, password: String) async throws
    func deletePersonalAccount(
        identity: AccountDeletionIdentity,
        operationID: String
    ) async throws
}

@MainActor
protocol AccountDeletionLocalDataPurging: AnyObject {
    func purge() async throws
}

@MainActor
final class SecureAccountDeletionLocalDataPurger: AccountDeletionLocalDataPurging {
    private let storage: SecureStorage
    private let studentRosterCacheStorageKey: String
    private let deniedStudentRosterAuthoritiesStorageKeyPrefix: String
    private let pendingStudentCreateOutboxStorageKey: String

    init(
        storage: SecureStorage = .shared,
        studentRosterCacheStorageKey: String = SecureStudentPageCache.defaultStorageKey,
        deniedStudentRosterAuthoritiesStorageKeyPrefix: String =
            "\(SecureStudentPageCache.defaultDeniedAuthoritiesStorageKey).",
        pendingStudentCreateOutboxStorageKey: String =
            SecureStorageStudentCreateOutboxStorage.defaultStorageKey
    ) {
        self.storage = storage
        self.studentRosterCacheStorageKey = studentRosterCacheStorageKey
        self.deniedStudentRosterAuthoritiesStorageKeyPrefix =
            deniedStudentRosterAuthoritiesStorageKeyPrefix
        self.pendingStudentCreateOutboxStorageKey = pendingStudentCreateOutboxStorageKey
    }

    func purge() async throws {
        try storage.delete(for: studentRosterCacheStorageKey)
        try storage.deleteAll(
            withPrefix: deniedStudentRosterAuthoritiesStorageKeyPrefix
        )
        try storage.delete(for: pendingStudentCreateOutboxStorageKey)
    }
}

@MainActor
final class AccountDeletionService {
    private struct PendingOperation {
        let userID: String
        let operationID: String
    }

    static let shared = AccountDeletionService(
        backend: FeatureFlags.production.usesTrustedMutationCallables
            ? FirebaseAccountDeletionBackend()
            : FirestoreDirectAccountDeletionBackend(),
        policy: .production,
        localDataPurger: SecureAccountDeletionLocalDataPurger()
    )

    private let backend: any AccountDeletionBackend
    private let policy: AccountDeletionPolicy
    private let localDataPurger: any AccountDeletionLocalDataPurging
    private let makeOperationID: () -> String
    private var pendingOperation: PendingOperation?

    init(
        backend: any AccountDeletionBackend,
        policy: AccountDeletionPolicy,
        localDataPurger: any AccountDeletionLocalDataPurging,
        operationID: @escaping () -> String = { UUID().uuidString.lowercased() }
    ) {
        self.backend = backend
        self.policy = policy
        self.localDataPurger = localDataPurger
        self.makeOperationID = operationID
    }

    func deleteAccount(password: String) async throws {
        guard policy.isValid else {
            throw AccountDeletionError.invalidPolicy
        }

        guard !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountDeletionError.incorrectPassword
        }

        var operationID = pendingOperation?.operationID ?? makeOperationID()
        guard TrustedIdentifier.isValid(operationID) else {
            throw AccountDeletionError.invalidOperation
        }

        let identity = try backend.currentIdentity()
        if let pendingOperation, pendingOperation.userID != identity.userID {
            operationID = makeOperationID()
            guard TrustedIdentifier.isValid(operationID) else {
                throw AccountDeletionError.invalidOperation
            }
        }
        pendingOperation = PendingOperation(
            userID: identity.userID,
            operationID: operationID
        )
        try await backend.reauthenticate(email: identity.email, password: password)

        do {
            try await localDataPurger.purge()
            try await backend.deletePersonalAccount(
                identity: identity,
                operationID: operationID
            )
            pendingOperation = nil
        } catch let error as AccountDeletionError {
            throw error
        } catch {
            throw AccountDeletionError.cleanupFailed
        }
    }
}

@MainActor
private final class FirebaseAccountDeletionBackend: AccountDeletionBackend {
    private let auth: Auth
    private let firestore: Firestore
    private let functions: Functions

    init(
        auth: Auth = Auth.auth(),
        firestore: Firestore = Firestore.firestore(),
        functions: Functions = Functions.functions(region: "us-central1")
    ) {
        self.auth = auth
        self.firestore = firestore
        self.functions = functions
    }

    func currentIdentity() throws -> AccountDeletionIdentity {
        guard let user = auth.currentUser else {
            throw AccountDeletionError.noAuthenticatedUser
        }
        guard let email = user.email, !email.isEmpty else {
            throw AccountDeletionError.missingEmail
        }
        return AccountDeletionIdentity(userID: user.uid, email: email)
    }

    func reauthenticate(email: String, password: String) async throws {
        guard let user = auth.currentUser else {
            throw AccountDeletionError.noAuthenticatedUser
        }

        do {
            let credential = EmailAuthProvider.credential(
                withEmail: email,
                password: password
            )
            try await user.reauthenticate(with: credential)
            _ = try await user.getIDTokenResult(forcingRefresh: true)
        } catch {
            let code = AuthErrorCode(rawValue: (error as NSError).code)
            if code == .wrongPassword || code == .invalidCredential {
                throw AccountDeletionError.incorrectPassword
            }
            throw error
        }
    }

    func deletePersonalAccount(
        identity: AccountDeletionIdentity,
        operationID: String
    ) async throws {
        guard let user = auth.currentUser, user.uid == identity.userID else {
            throw AccountDeletionError.noAuthenticatedUser
        }

        do {
            let token = try await user.getIDTokenResult(forcingRefresh: true)
            let claim = try TrustedTenantClaim(
                userID: identity.userID,
                tokenClaims: token.claims
            )
            let userSnapshot = try await firestore
                .collection("users")
                .document(identity.userID)
                .getDocument()
            let recordVersion = Self.recordVersion(in: userSnapshot.data())

            _ = try await functions
                .httpsCallable("deletePersonalAccountData")
                .call([
                    "districtID": claim.districtID,
                    "userID": identity.userID,
                    "expectedRecordVersion": recordVersion,
                    "idempotencyKey": operationID,
                    "reasonCode": "user-requested-account-deletion",
                ])
        } catch let error as AccountDeletionError {
            throw error
        } catch {
            throw AccountDeletionError.cleanupFailed
        }
    }

    private static func recordVersion(in data: [String: Any]?) -> Int {
        guard let value = data?["recordVersion"], !(value is Bool) else {
            return 0
        }
        if let value = value as? Int {
            return max(value, 0)
        }
        if let value = value as? NSNumber {
            return max(value.intValue, 0)
        }
        return 0
    }
}


/// Deletes the account without the `deletePersonalAccountData` callable.
///
/// The callable erases personal data, deactivates the membership, and
/// reassigns authored institutional records to an opaque former-author
/// identifier, all in one trusted transaction. Only the first and last steps of
/// that have a client-authorized equivalent.
///
/// What this does: purge the personal documents under `users/{uid}`, then
/// delete the Firebase Auth identity. Educational records under `districts/`
/// are institution property and are deliberately left intact, which matches the
/// deployed policy.
///
/// What it cannot do: the membership document is `allow write: if false`, so it
/// is left in place rather than deactivated. The account it names no longer
/// exists and cannot authenticate, so this is a stale record rather than
/// lingering access, but an operator should clear it. Authored records keep the
/// deleted user's identifier instead of an opaque one.
@MainActor
final class FirestoreDirectAccountDeletionBackend: AccountDeletionBackend {
    private let auth: Auth
    private let firestore: Firestore

    init(
        auth: Auth = Auth.auth(),
        firestore: Firestore = Firestore.firestore()
    ) {
        self.auth = auth
        self.firestore = firestore
    }

    func currentIdentity() throws -> AccountDeletionIdentity {
        guard let user = auth.currentUser else {
            throw AccountDeletionError.noAuthenticatedUser
        }
        guard let email = user.email, !email.isEmpty else {
            throw AccountDeletionError.missingEmail
        }
        return AccountDeletionIdentity(userID: user.uid, email: email)
    }

    func reauthenticate(email: String, password: String) async throws {
        guard let user = auth.currentUser else {
            throw AccountDeletionError.noAuthenticatedUser
        }
        let credential = EmailAuthProvider.credential(
            withEmail: email,
            password: password
        )
        do {
            _ = try await user.reauthenticate(with: credential)
        } catch {
            let code = AuthErrorCode(rawValue: (error as NSError).code)
            if code == .wrongPassword || code == .invalidCredential {
                throw AccountDeletionError.incorrectPassword
            }
            throw error
        }
    }

    func deletePersonalAccount(
        identity: AccountDeletionIdentity,
        operationID: String
    ) async throws {
        guard let user = auth.currentUser, user.uid == identity.userID else {
            throw AccountDeletionError.noAuthenticatedUser
        }

        do {
            // Personal data first: once the identity is gone the client has no
            // credential left to delete anything with.
            let root = firestore.collection("users").document(identity.userID)
            try await root.collection("private").document("profile").delete()
            try await root.collection("preferences").document("settings").delete()
            try await root.delete()
            try await user.delete()
        } catch {
            throw AccountDeletionError.cleanupFailed
        }
    }
}
