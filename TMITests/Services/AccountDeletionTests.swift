import Foundation
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

    @Test("Incorrect password never starts destructive cleanup")
    func incorrectPasswordStopsDeletion() async {
        let backend = FakeAccountDeletionBackend(failure: .reauthenticate)
        let service = AccountDeletionService(
            backend: backend,
            policy: .production,
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
            operationID: { "" }
        )
        await #expect(throws: AccountDeletionError.invalidOperation) {
            try await emptyOperationService.deleteAccount(password: "correct horse")
        }
        #expect(emptyOperationBackend.calls.isEmpty)
    }
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
