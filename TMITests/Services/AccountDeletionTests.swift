import Foundation
import Security
import Testing
@testable import TMI

@Suite("Account Deletion Policy")
struct AccountDeletionPolicyTests {
    @Test("Production policy preserves institutional collections")
    func policyPreservesInstitutionalCollections() {
        let protected = Set([
            "students",
            "plans",
            "tmiPlans",
            "formTemplates",
            "formAssignments",
            "formSubmissions",
            "meetings",
            "consents",
            "restrictedRecords",
            "auditLogs",
            "auditEvents",
            "complianceAudits",
            "metricSnapshots",
        ])

        #expect(protected.isSubset(of: AccountDeletionPolicy.production.retainedSubcollections))
        #expect(protected.isDisjoint(with: AccountDeletionPolicy.production.personalSubcollections))
        #expect(AccountDeletionPolicy.production.isValid)
    }

    @Test("Production policy includes canonical and legacy personal collections")
    func policyDeletesPersonalCollections() {
        let expected = Set([
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
        ])

        #expect(expected.isSubset(of: AccountDeletionPolicy.production.personalSubcollections))
    }

    @Test("Overlapping deletion policy fails closed")
    func overlappingPolicyFailsClosed() {
        let policy = AccountDeletionPolicy(
            personalSubcollections: ["students"],
            retainedSubcollections: ["students"]
        )
        #expect(!policy.isValid)
    }
}

@Suite("Account Deletion Service")
@MainActor
struct AccountDeletionServiceTests {
    @Test("Deletion reauthenticates before invoking trusted cleanup")
    func deletionOrder() async throws {
        let backend = FakeAccountDeletionBackend()
        let service = AccountDeletionService(
            backend: backend,
            policy: .production,
            localDataPurger: FakeAccountDeletionLocalDataPurger(),
            operationID: { "delete-operation-1" }
        )

        try await service.deleteAccount(password: "correct horse")

        #expect(backend.calls == [
            .currentIdentity,
            .reauthenticate,
            .deletePersonalAccount,
        ])
        #expect(backend.receivedOperationID == "delete-operation-1")
        #expect(backend.receivedIdentity?.userID == "user-1")
    }

    @Test("Successful deletion makes encrypted student cache and pending creates unreadable")
    func successfulDeletionPurgesEncryptedStudentData() async throws {
        let serviceName = "com.tmi.tests.account-deletion-cache.\(UUID().uuidString)"
        let keychain = KeychainManager(service: serviceName)
        let storage = SecureStorage(
            keychain: keychain,
            encryptionKeyTag: "account-deletion-cache-key"
        )
        defer { try? keychain.deleteAll() }

        let pageKey = StudentPageCacheKey(
            districtID: "district-a",
            userID: "user-1",
            membershipVersion: 1,
            search: nil,
            schoolID: "school-a",
            grade: nil,
            assignedMemberID: nil,
            status: .active,
            sort: .alphabetical,
            cursor: nil,
            limit: 50
        )
        let cachedPage = StudentStorePage(
            documents: [
                FirebaseStudentSnapshot(
                    documentID: "student-a",
                    document: FirebaseStudentDocument(
                        districtId: "district-a",
                        schoolId: "school-a",
                        displayName: "Ava Stone",
                        grade: "7",
                        studentIdentifier: "0012",
                        dateOfBirth: nil,
                        pronouns: nil,
                        assignedMemberIDs: ["user-1"],
                        isArchived: false,
                        schemaVersion: 1,
                        recordVersion: 1,
                        createdAt: Date(timeIntervalSince1970: 10),
                        createdBy: "user-1",
                        updatedAt: Date(timeIntervalSince1970: 20),
                        updatedBy: "user-1"
                    )
                ),
            ],
            nextCursor: nil
        )
        let writer = SecureStudentPageCache(storage: storage)
        await writer.save(cachedPage, for: pageKey)
        #expect(await writer.page(for: pageKey) == cachedPage)

        let queuedCreate = PendingStudentCreate(
            operationID: UUID(uuidString: "00000000-0000-0000-0000-000000000321")!,
            districtID: "district-a",
            userID: "user-1",
            membershipVersion: 1,
            draft: StudentDraft(
                displayName: "Pending Student",
                schoolID: "school-a",
                grade: "7",
                studentIdentifier: "0099",
                dateOfBirth: nil,
                pronouns: nil,
                assignedMemberIDs: ["user-1"]
            ),
            enqueuedAt: Date(timeIntervalSince1970: 30)
        )
        let outboxStorage = SecureStorageStudentCreateOutboxStorage(
            secureStorage: storage
        )
        let outboxWriter = SecureStudentCreateOutbox(storage: outboxStorage)
        try await outboxWriter.enqueue(queuedCreate)
        #expect(try await outboxWriter.pending() == [queuedCreate])

        await writer.invalidate(
            authority: StudentCacheAuthority(
                districtID: "district-b",
                userID: "user-1"
            )
        )
        let deniedAuthorityStorageKeyPrefix =
            "\(SecureStudentPageCache.defaultDeniedAuthoritiesStorageKey)."
        #expect(
            try keychainAccounts(forService: serviceName).contains {
                $0.hasPrefix(deniedAuthorityStorageKeyPrefix)
            }
        )
        #expect(await writer.page(for: pageKey) == cachedPage)

        let backend = FakeAccountDeletionBackend()
        let purger = SecureAccountDeletionLocalDataPurger(storage: storage)
        let service = AccountDeletionService(
            backend: backend,
            policy: .production,
            localDataPurger: purger,
            operationID: { "delete-operation-cache-purge" }
        )

        try await service.deleteAccount(password: "correct horse")

        let reader = SecureStudentPageCache(storage: storage)
        let outboxReader = SecureStudentCreateOutbox(storage: outboxStorage)
        #expect(await reader.page(for: pageKey) == nil)
        #expect(try await outboxReader.pending().isEmpty)
        #expect(
            try !keychainAccounts(forService: serviceName).contains {
                $0.hasPrefix(deniedAuthorityStorageKeyPrefix)
            }
        )

        try await purger.purge()
        #expect(await reader.page(for: pageKey) == nil)
        #expect(try await outboxReader.pending().isEmpty)
        #expect(
            try !keychainAccounts(forService: serviceName).contains {
                $0.hasPrefix(deniedAuthorityStorageKeyPrefix)
            }
        )
    }

    @Test("Local purge failure prevents backend deletion and remains retryable")
    func localPurgeFailureStopsBackendDeletion() async throws {
        let backend = FakeAccountDeletionBackend()
        let purger = FakeAccountDeletionLocalDataPurger(failuresRemaining: 1)
        let service = AccountDeletionService(
            backend: backend,
            policy: .production,
            localDataPurger: purger,
            operationID: { "delete-operation-local-purge" }
        )

        await #expect(throws: AccountDeletionError.cleanupFailed) {
            try await service.deleteAccount(password: "correct horse")
        }
        #expect(purger.callCount == 1)
        #expect(backend.calls == [
            .currentIdentity,
            .reauthenticate,
        ])

        try await service.deleteAccount(password: "correct horse")

        #expect(purger.callCount == 2)
        #expect(backend.calls == [
            .currentIdentity,
            .reauthenticate,
            .currentIdentity,
            .reauthenticate,
            .deletePersonalAccount,
        ])
        #expect(backend.receivedOperationIDs == [
            "delete-operation-local-purge",
        ])
    }

    @Test("Incorrect password never starts destructive cleanup")
    func incorrectPasswordStopsDeletion() async {
        let backend = FakeAccountDeletionBackend(failure: .reauthenticate)
        let service = AccountDeletionService(
            backend: backend,
            policy: .production,
            localDataPurger: FakeAccountDeletionLocalDataPurger(),
            operationID: { "delete-operation-2" }
        )

        await #expect(throws: AccountDeletionError.incorrectPassword) {
            try await service.deleteAccount(password: "wrong password")
        }
        #expect(backend.calls == [.currentIdentity, .reauthenticate])
    }

    @Test("Cleanup failure remains retryable and is not reported as success")
    func cleanupFailureIsRetryable() async {
        let backend = FakeAccountDeletionBackend(failure: .deletePersonalAccount)
        let service = AccountDeletionService(
            backend: backend,
            policy: .production,
            localDataPurger: FakeAccountDeletionLocalDataPurger(),
            operationID: { "delete-operation-3" }
        )

        await #expect(throws: AccountDeletionError.cleanupFailed) {
            try await service.deleteAccount(password: "correct horse")
        }
        #expect(backend.calls.last == .deletePersonalAccount)
    }

    @Test("A retry reuses the original idempotency key")
    func retryReusesOperationID() async throws {
        let backend = FakeAccountDeletionBackend(failure: .deletePersonalAccount)
        var generatedOperationCount = 0
        let service = AccountDeletionService(
            backend: backend,
            policy: .production,
            localDataPurger: FakeAccountDeletionLocalDataPurger(),
            operationID: {
                generatedOperationCount += 1
                return "delete-operation-\(generatedOperationCount)"
            }
        )

        await #expect(throws: AccountDeletionError.cleanupFailed) {
            try await service.deleteAccount(password: "correct horse")
        }
        try await service.deleteAccount(password: "correct horse")

        #expect(generatedOperationCount == 1)
        #expect(backend.receivedOperationIDs == [
            "delete-operation-1",
            "delete-operation-1",
        ])
    }

    @Test("Invalid policy prevents every backend operation")
    func invalidPolicyFailsClosed() async {
        let backend = FakeAccountDeletionBackend()
        let invalidPolicy = AccountDeletionPolicy(
            personalSubcollections: ["students"],
            retainedSubcollections: ["students"]
        )
        let service = AccountDeletionService(
            backend: backend,
            policy: invalidPolicy,
            localDataPurger: FakeAccountDeletionLocalDataPurger(),
            operationID: { "delete-operation-4" }
        )

        await #expect(throws: AccountDeletionError.invalidPolicy) {
            try await service.deleteAccount(password: "correct horse")
        }
        #expect(backend.calls.isEmpty)
    }

    @Test("Empty password and operation identifiers fail before cleanup")
    func malformedInputFailsClosed() async {
        let emptyPasswordBackend = FakeAccountDeletionBackend()
        let emptyPasswordService = AccountDeletionService(
            backend: emptyPasswordBackend,
            policy: .production,
            localDataPurger: FakeAccountDeletionLocalDataPurger(),
            operationID: { "delete-operation-5" }
        )
        await #expect(throws: AccountDeletionError.incorrectPassword) {
            try await emptyPasswordService.deleteAccount(password: "   ")
        }
        #expect(emptyPasswordBackend.calls.isEmpty)

        let emptyOperationBackend = FakeAccountDeletionBackend()
        let emptyOperationService = AccountDeletionService(
            backend: emptyOperationBackend,
            policy: .production,
            localDataPurger: FakeAccountDeletionLocalDataPurger(),
            operationID: { "" }
        )
        await #expect(throws: AccountDeletionError.invalidOperation) {
            try await emptyOperationService.deleteAccount(password: "correct horse")
        }
        #expect(emptyOperationBackend.calls.isEmpty)
    }
}

private func keychainAccounts(forService service: String) throws -> [String] {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        kSecReturnAttributes as String: true,
        kSecMatchLimit as String: kSecMatchLimitAll,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
        return []
    }
    guard status == errSecSuccess else {
        throw KeychainError.bulkRetrieveFailed(status: status)
    }
    guard let items = result as? [[String: Any]] else {
        throw KeychainError.invalidData
    }
    return items.compactMap { $0[kSecAttrAccount as String] as? String }
}

@Suite("Account Deletion UI Wiring")
struct AccountDeletionUIWiringTests {
    @Test("Profile exposes the reviewer-reachable deletion sheet")
    func profileWiring() throws {
        let source = try source(at: "TMI/Views/User/UserProfileView.swift")
        #expect(source.contains("showingDeleteAccount"))
        #expect(source.contains("Delete Account"))
        #expect(source.contains("person.crop.circle.badge.minus"))
        #expect(source.contains("Permanently delete your account and personal data"))
        #expect(source.contains("DeleteAccountView()"))
    }

    @Test("Confirmation accurately separates deleted and retained data")
    func accurateDisclosure() throws {
        let source = try source(at: "TMI/Views/Settings/DeleteAccountView.swift")
        #expect(source.contains("Personal profile and preferences"))
        #expect(source.contains("Institutional records retained"))
        #expect(source.contains("Student records and TMI plans"))
        #expect(source.contains("AccountDeletionService.shared.deleteAccount(password: password)"))
        #expect(source.contains("Incorrect password. Please try again."))
        #expect(source.contains("style: .destructive"))
        #expect(!source.contains("All student records"))
        #expect(!source.contains("All TMI plans"))
    }

    @Test("Legacy authentication service no longer owns deletion")
    func unsafeLegacyMethodRemoved() throws {
        let source = try source(at: "TMI/Services/AuthenticationService.swift")
        #expect(!source.contains("func deleteAccount(password: String)"))
        #expect(!source.contains("case deletionFailed"))
    }

    @Test("Account deletion works without the trusted callable")
    func deletionHasClientAuthorizedPath() throws {
        let source = try source(at: "TMI/Services/AccountDeletionService.swift")

        // The App Store requires in-app deletion, so it cannot depend on a
        // callable that is not deployed.
        #expect(source.contains("final class FirestoreDirectAccountDeletionBackend"))
        #expect(
            source.contains(
                "FeatureFlags.production.usesTrustedMutationCallables\n            ? FirebaseAccountDeletionBackend()\n            : FirestoreDirectAccountDeletionBackend()"
            )
        )

        let direct = try #require(
            source.range(of: "final class FirestoreDirectAccountDeletionBackend")
                .map { String(source[$0.lowerBound...]) }
        )
        // Personal data must be erased while the client still holds a
        // credential; deleting the identity first would strand it forever.
        let personal = try #require(direct.range(of: "root.delete()"))
        let identity = try #require(direct.range(of: "user.delete()"))
        #expect(personal.lowerBound < identity.lowerBound)
    }

    @Test("Institution-owned records survive account deletion")
    func deletionLeavesInstitutionalRecords() throws {
        let source = try source(at: "TMI/Services/AccountDeletionService.swift")
        let direct = try #require(
            source.range(of: "final class FirestoreDirectAccountDeletionBackend")
                .map { String(source[$0.lowerBound...]) }
        )
        // Nothing under districts/ may be touched by a personal deletion.
        #expect(!direct.contains("\"districts\""))
        #expect(!direct.contains("students"))
        #expect(!direct.contains("plans"))
    }

    private func source(at relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}

@MainActor
private final class FakeAccountDeletionBackend: AccountDeletionBackend {
    enum Call: Equatable {
        case currentIdentity
        case reauthenticate
        case deletePersonalAccount
    }

    enum Failure {
        case reauthenticate
        case deletePersonalAccount
    }

    private(set) var calls: [Call] = []
    private(set) var receivedIdentity: AccountDeletionIdentity?
    private(set) var receivedOperationIDs: [String] = []
    private let failure: Failure?
    private var hasFailedPersonalDeletion = false

    var receivedOperationID: String? {
        receivedOperationIDs.last
    }

    init(failure: Failure? = nil) {
        self.failure = failure
    }

    func currentIdentity() throws -> AccountDeletionIdentity {
        calls.append(.currentIdentity)
        return AccountDeletionIdentity(userID: "user-1", email: "user@example.com")
    }

    func reauthenticate(email: String, password: String) async throws {
        calls.append(.reauthenticate)
        if failure == .reauthenticate {
            throw AccountDeletionError.incorrectPassword
        }
    }

    func deletePersonalAccount(
        identity: AccountDeletionIdentity,
        operationID: String
    ) async throws {
        calls.append(.deletePersonalAccount)
        receivedIdentity = identity
        receivedOperationIDs.append(operationID)
        if failure == .deletePersonalAccount, !hasFailedPersonalDeletion {
            hasFailedPersonalDeletion = true
            throw AccountDeletionError.cleanupFailed
        }
    }
}

@MainActor
private final class FakeAccountDeletionLocalDataPurger: AccountDeletionLocalDataPurging {
    private(set) var callCount = 0
    private var failuresRemaining: Int

    init(failuresRemaining: Int = 0) {
        self.failuresRemaining = failuresRemaining
    }

    func purge() async throws {
        callCount += 1
        guard failuresRemaining > 0 else { return }
        failuresRemaining -= 1
        throw AccountDeletionError.cleanupFailed
    }
}
