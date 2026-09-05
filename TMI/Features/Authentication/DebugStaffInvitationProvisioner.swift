#if DEBUG
import Foundation

nonisolated enum DebugStaffInvitationError: Error, Equatable {
    case emailNotAllowed
}

/// Debug-only record of which accounts redeemed the universal Debug invitation.
/// Persisted so that relaunch, sign-out, and sign-in resolve the same synthetic
/// membership without contacting Cloud Functions.
nonisolated enum DebugStaffAccessRegistry {
    private static let defaultsKey = "debug.staff-access.emails"

    static func normalized(_ email: String?) -> String? {
        guard let email = email?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !email.isEmpty else {
            return nil
        }
        return email
    }

    static func contains(_ email: String?) -> Bool {
        guard let email = normalized(email) else {
            return false
        }
        if email == DebugStaffInvitationProvisioner.allowedEmail {
            return true
        }
        return storedEmails().contains(email)
    }

    static func register(_ email: String?) {
        guard let email = normalized(email) else {
            return
        }
        var emails = storedEmails()
        guard emails.insert(email).inserted else {
            return
        }
        UserDefaults.standard.set(Array(emails), forKey: defaultsKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private static func storedEmails() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
    }
}

@MainActor
final class DebugStaffInvitationProvisioner: StaffInvitationProvisioning {
    nonisolated static let invitationAlias = "TMI-DEBUG-ACCESS-2026"
    nonisolated static let allowedEmail = "tmi-debug@example.com"
    nonisolated static let districtID = "district-debug"
    nonisolated static let schoolID = "school-debug"

    private let delegate: any StaffInvitationProvisioning

    init(delegate: any StaffInvitationProvisioning) {
        self.delegate = delegate
    }

    func requiresTrustedClaimRefresh(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) -> Bool {
        !Self.isAllowed(request: request, identity: identity)
    }

    func provision(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) async throws -> MembershipContext {
        guard request.invitationCode == Self.invitationAlias else {
            return try await delegate.provision(request: request, identity: identity)
        }
        guard let email = DebugStaffAccessRegistry.normalized(identity.email) else {
            throw DebugStaffInvitationError.emailNotAllowed
        }
        DebugStaffAccessRegistry.register(email)

        return Self.membership(for: identity)
    }

    nonisolated static func isAllowed(
        request: StaffInvitationAcceptanceRequest,
        identity: AuthIdentity
    ) -> Bool {
        request.invitationCode == invitationAlias && isAllowed(identity: identity)
    }

    nonisolated static func isAllowed(identity: AuthIdentity) -> Bool {
        DebugStaffAccessRegistry.contains(identity.email)
    }

    nonisolated static func membership(for identity: AuthIdentity) -> MembershipContext {
        membership(userID: identity.userID)
    }

    nonisolated static func membership(userID: String) -> MembershipContext {
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

    nonisolated static func session(for identity: AuthIdentity) -> AuthSession {
        AuthSession(
            identity: AuthIdentity(
                userID: identity.userID,
                email: identity.email,
                isEmailVerified: identity.isEmailVerified,
                districtID: districtID
            ),
            membership: membership(for: identity)
        )
    }
}

@MainActor
final class DebugAuthenticationIdentityProvider: AuthenticationIdentityProviding {
    private let delegate: any AuthenticationIdentityProviding
    private let eligibilityStore: DebugIdentityEligibilityStore

    init(
        delegate: any AuthenticationIdentityProviding,
        eligibilityStore: DebugIdentityEligibilityStore
    ) {
        self.delegate = delegate
        self.eligibilityStore = eligibilityStore
    }

    var currentIdentity: AuthenticatedIdentity? {
        delegate.currentIdentity
    }

    func trustedClaim(for identity: AuthenticatedIdentity) async throws -> TrustedTenantClaim {
        let isAllowed = Self.isAllowed(identity)
        await eligibilityStore.setEligible(isAllowed, userID: identity.userID)
        guard isAllowed else {
            return try await delegate.trustedClaim(for: identity)
        }
        return Self.claim(userID: identity.userID)
    }

    func addStateDidChangeListener(
        _ listener: @escaping @MainActor (AuthenticatedIdentity?) -> Void
    ) -> AuthStateListenerHandle {
        delegate.addStateDidChangeListener(listener)
    }

    nonisolated static func isAllowed(_ identity: AuthenticatedIdentity) -> Bool {
        DebugStaffAccessRegistry.contains(identity.email)
    }

    nonisolated static func claim(userID: String) -> TrustedTenantClaim {
        TrustedTenantClaim(
            userID: userID,
            districtID: DebugStaffInvitationProvisioner.districtID,
            accessClass: .staff,
            membershipVersion: 1
        )
    }
}

actor DebugIdentityEligibilityStore {
    private var eligibleUserIDs: Set<String> = []

    func setEligible(_ isEligible: Bool, userID: String) {
        if isEligible {
            eligibleUserIDs.insert(userID)
        } else {
            eligibleUserIDs.remove(userID)
        }
    }

    func isEligible(userID: String) -> Bool {
        eligibleUserIDs.contains(userID)
    }
}

struct DebugUserProfileProvider: UserProfileProviding {
    private let delegate: any UserProfileProviding

    init(delegate: any UserProfileProviding) {
        self.delegate = delegate
    }

    func profile(for identity: AuthenticatedIdentity) async throws -> TMIUser? {
        guard DebugAuthenticationIdentityProvider.isAllowed(identity) else {
            return try await delegate.profile(for: identity)
        }
        return TMIUser(
            id: identity.userID,
            userID: identity.userID,
            displayName: "Debug Staff",
            email: DebugStaffAccessRegistry.normalized(identity.email)
                ?? DebugStaffInvitationProvisioner.allowedEmail,
            isEmailVerified: identity.isEmailVerified,
            requestedRole: .teacher
        )
    }
}

struct DebugMembershipProvider: MembershipProviding {
    private let delegate: any MembershipProviding
    private let eligibilityStore: DebugIdentityEligibilityStore

    init(
        delegate: any MembershipProviding,
        eligibilityStore: DebugIdentityEligibilityStore
    ) {
        self.delegate = delegate
        self.eligibilityStore = eligibilityStore
    }

    func membership(for claim: TrustedTenantClaim) async throws -> MembershipContext {
        guard claim.districtID == DebugStaffInvitationProvisioner.districtID,
              claim.accessClass == .staff,
              await eligibilityStore.isEligible(userID: claim.userID) else {
            return try await delegate.membership(for: claim)
        }
        return DebugStaffInvitationProvisioner.membership(userID: claim.userID)
    }
}

/// Durable, Debug-only backing store for the synthetic roster.
///
/// Accounts created under the Debug school (`district-debug`/`school-debug`) are
/// served entirely from `DebugStudentRepository` instead of Firestore. Without a
/// durable store those records lived only in process memory, so every rebuild or
/// relaunch started with an empty roster. This persists them to disk so the Debug
/// tenant behaves like a real one across launches. It only covers the Debug
/// tenant; real accounts still read and write Firestore directly.
nonisolated struct DebugStudentPersistence: Sendable {
    var load: @Sendable () -> [StudentRecord]
    var save: @Sendable ([StudentRecord]) -> Void

    static let standard = DebugStudentPersistence.file(url: defaultURL)

    static func file(url: URL) -> DebugStudentPersistence {
        DebugStudentPersistence(
            load: {
                guard let data = try? Data(contentsOf: url) else { return [] }
                return (try? JSONDecoder().decode([StudentRecord].self, from: data)) ?? []
            },
            save: { records in
                let directory = url.deletingLastPathComponent()
                try? FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
                guard let data = try? JSONEncoder().encode(records) else { return }
                try? data.write(to: url, options: .atomic)
            }
        )
    }

    private static var defaultURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("DebugStudentRoster.json")
    }
}

actor DebugStudentRepository: StudentRepository {
    private let delegate: any StudentRepository
    private let persistence: DebugStudentPersistence
    private var cachedRecordsByID: [String: StudentRecord]?

    init(
        delegate: any StudentRepository,
        persistence: DebugStudentPersistence = .standard
    ) {
        self.delegate = delegate
        self.persistence = persistence
    }

    /// Lazily loads the durable roster on first access, then keeps it in memory.
    private func recordsByID() -> [String: StudentRecord] {
        if let cachedRecordsByID { return cachedRecordsByID }
        let loaded = Dictionary(
            persistence.load().map { ($0.id, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        cachedRecordsByID = loaded
        return loaded
    }

    /// Applies an in-place mutation and writes the result back to disk.
    private func mutateRecords(_ body: (inout [String: StudentRecord]) -> Void) {
        var records = recordsByID()
        body(&records)
        cachedRecordsByID = records
        persistence.save(Array(records.values))
    }

    func page(
        _ request: StudentPageRequest,
        member: MembershipContext
    ) async throws -> StudentPage {
        guard isDebug(member) else {
            return try await delegate.page(request, member: member)
        }
        guard request.limit > 0, request.limit <= StudentPageRequest.maximumPageSize else {
            throw StudentRepositoryError.invalidRequest
        }
        var records = recordsByID().values.filter { record in
            switch request.status {
            case .active: !record.isArchived
            case .archived: record.isArchived
            case .all: true
            }
        }
        if let schoolID = request.schoolID {
            records = records.filter { $0.schoolID == schoolID }
        }
        if let grade = request.grade {
            records = records.filter { $0.grade == grade }
        }
        if let assignedMemberID = request.assignedMemberID {
            records = records.filter { $0.assignedMemberIDs.contains(assignedMemberID) }
        }
        if let search = request.search?
            .trimmingCharacters(in: .whitespacesAndNewlines), !search.isEmpty {
            records = records.filter {
                $0.displayName.localizedCaseInsensitiveContains(search)
                    || ($0.studentIdentifier?.localizedCaseInsensitiveContains(search) ?? false)
            }
        }
        records.sort {
            switch request.sort {
            case .alphabetical:
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            case .recentlyUpdated:
                $0.metadata.updatedAt > $1.metadata.updatedAt
            }
        }
        return StudentPage(
            records: Array(records.prefix(request.limit)),
            nextCursor: nil,
            // The durable local roster is authoritative for the Debug tenant, so
            // it is treated as a live source rather than a stale offline cache.
            source: .server
        )
    }

    func student(id: String, member: MembershipContext) async throws -> StudentRecord {
        guard isDebug(member) else {
            return try await delegate.student(id: id, member: member)
        }
        guard let record = recordsByID()[id] else {
            throw StudentRepositoryError.notFound
        }
        return record
    }

    func create(
        _ draft: StudentDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        guard isDebug(member) else {
            return try await delegate.create(draft, operationID: operationID, member: member)
        }
        let draft = draft.normalized
        guard member.schoolIDs.contains(draft.schoolID),
              draft.assignedMemberIDs.contains(member.userID),
              StudentValidation.issues(
                for: draft,
                districtID: member.districtID,
                policy: .standard
              ).isEmpty else {
            throw StudentRepositoryError.invalidDraft
        }
        let now = Date()
        let record = StudentRecord(
            id: operationID.uuidString.lowercased(),
            districtID: member.districtID,
            schoolID: draft.schoolID,
            displayName: draft.displayName,
            grade: draft.grade,
            studentIdentifier: draft.studentIdentifier,
            dateOfBirth: draft.dateOfBirth,
            pronouns: draft.pronouns,
            assignedMemberIDs: draft.assignedMemberIDs,
            isArchived: false,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 1,
                createdAt: now,
                createdBy: member.userID,
                updatedAt: now,
                updatedBy: member.userID
            )
        )
        mutateRecords { $0[record.id] = record }
        return record
    }

    func reconcilePendingCreates(member: MembershipContext) async throws -> [StudentRecord] {
        guard isDebug(member) else {
            return try await delegate.reconcilePendingCreates(member: member)
        }
        return []
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        guard isDebug(member) else {
            return try await delegate.update(
                id: id,
                draft: draft,
                expectedVersion: expectedVersion,
                operationID: operationID,
                member: member
            )
        }
        guard let existing = recordsByID()[id] else {
            throw StudentRepositoryError.notFound
        }
        guard existing.metadata.recordVersion == expectedVersion else {
            throw StudentRepositoryError.versionConflict(
                expected: expectedVersion,
                actual: existing.metadata.recordVersion
            )
        }
        let draft = draft.normalized
        guard member.schoolIDs.contains(draft.schoolID),
              draft.assignedMemberIDs.contains(member.userID),
              StudentValidation.issues(
                for: draft,
                districtID: member.districtID,
                policy: .standard
              ).isEmpty else {
            throw StudentRepositoryError.invalidDraft
        }
        let updated = StudentRecord(
            id: existing.id,
            districtID: existing.districtID,
            schoolID: draft.schoolID,
            displayName: draft.displayName,
            grade: draft.grade,
            studentIdentifier: draft.studentIdentifier,
            dateOfBirth: draft.dateOfBirth,
            pronouns: draft.pronouns,
            assignedMemberIDs: draft.assignedMemberIDs,
            isArchived: existing.isArchived,
            metadata: CanonicalRecordMetadata(
                schemaVersion: existing.metadata.schemaVersion,
                recordVersion: expectedVersion + 1,
                createdAt: existing.metadata.createdAt,
                createdBy: existing.metadata.createdBy,
                updatedAt: Date(),
                updatedBy: member.userID
            )
        )
        mutateRecords { $0[id] = updated }
        return updated
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws {
        guard isDebug(member) else {
            try await delegate.archive(
                id: id,
                expectedVersion: expectedVersion,
                operationID: operationID,
                member: member
            )
            return
        }
        guard var existing = recordsByID()[id] else {
            throw StudentRepositoryError.notFound
        }
        guard existing.metadata.recordVersion == expectedVersion else {
            throw StudentRepositoryError.versionConflict(
                expected: expectedVersion,
                actual: existing.metadata.recordVersion
            )
        }
        existing.isArchived = true
        existing.metadata = CanonicalRecordMetadata(
            schemaVersion: existing.metadata.schemaVersion,
            recordVersion: expectedVersion + 1,
            createdAt: existing.metadata.createdAt,
            createdBy: existing.metadata.createdBy,
            updatedAt: Date(),
            updatedBy: member.userID
        )
        mutateRecords { $0[id] = existing }
    }

    private func isDebug(_ member: MembershipContext) -> Bool {
        member.districtID == DebugStaffInvitationProvisioner.districtID
            && member.schoolIDs == [DebugStaffInvitationProvisioner.schoolID]
    }
}

@MainActor
final class DebugAuthenticationSessionLoader: AuthenticationSessionLoading {
    private let delegate: any AuthenticationSessionLoading

    init(delegate: any AuthenticationSessionLoading) {
        self.delegate = delegate
    }

    func session(for identity: AuthIdentity) async throws -> AuthSession {
        guard DebugStaffInvitationProvisioner.isAllowed(identity: identity) else {
            return try await delegate.session(for: identity)
        }
        return DebugStaffInvitationProvisioner.session(for: identity)
    }
}
#endif
