#if DEBUG
import SwiftUI

@MainActor
struct StudentRosterUITestingContent: View {
    @State private var state: StudentListState
    @State private var router: AppRouter

    private let member: MembershipContext

    init(fixture: String) {
        let member = Self.fixtureMember
        let scenario = StudentRosterUITestingRepository.Scenario(rawValue: fixture) ?? .empty
        self.member = member
        _state = State(
            initialValue: StudentListState(
                repository: StudentRosterUITestingRepository(scenario: scenario),
                member: member,
                debounceDuration: .zero
            )
        )
        _router = State(initialValue: AppRouter(policy: AppNavigationPolicy(membership: member)))
    }

    var body: some View {
        NavigationStack {
            StudentListView(state: state, member: member)
        }
        .environment(router)
        .tint(TMIColors.teal)
        .preferredColorScheme(.light)
    }

    fileprivate static let fixtureMember = MembershipContext(
        userID: "administrator-fixture",
        districtID: "district-fixture",
        schoolIDs: ["school-fixture"],
        role: .schoolAdministrator,
        capabilities: [.studentReadDetail, .studentWriteDetail, .staffManage],
        assignedStudentIDs: [],
        isActive: true,
        version: 1
    )
}

private actor StudentRosterUITestingRepository: StudentRepository {
    enum Scenario: String {
        case populated = "roster-populated"
        case empty = "roster-empty"
        case offline = "roster-offline"
        case permissionDenied = "roster-permission-denied"
        case createQueued = "roster-create-queued"
        case createSaving = "roster-create-saving"
        case archived = "roster-archived"
        case createDuplicate = "roster-create-duplicate"
        case createConfirmed = "roster-create-confirmed"
        case workflow = "roster-workflow"
        case cachePrime = "roster-cache-prime"
        case cacheOffline = "roster-cache-offline"
    }

    private let scenario: Scenario
    private let acceptanceCache: SecureStudentPageCache
    private var records: [StudentRecord]
    private var shouldResetAcceptanceCache: Bool

    init(scenario: Scenario) {
        self.scenario = scenario
        let keychain = KeychainManager(
            service: "com.tmi.education.uitesting.release1-student-cache"
        )
        acceptanceCache = SecureStudentPageCache(
            storage: SecureStorage(
                keychain: keychain,
                encryptionKeyTag: "release1-student-cache-key"
            ),
            storageKey: "release1-student-pages"
        )
        shouldResetAcceptanceCache = ProcessInfo.processInfo.arguments.contains(
            "-reset-release1-acceptance-cache"
        )
        switch scenario {
        case .workflow:
            records = Self.workflowRecords
        case .cachePrime:
            records = [Self.cached]
        case .cacheOffline:
            records = []
        case .populated, .offline:
            records = [Self.ava]
        case .archived:
            records = [Self.archivedAva]
        case .empty,
             .permissionDenied,
             .createQueued,
             .createSaving,
             .createDuplicate,
             .createConfirmed:
            records = []
        }

    }

    func page(
        _ request: StudentPageRequest,
        member: MembershipContext
    ) async throws -> StudentPage {
        switch scenario {
        case .populated, .archived:
            return StudentPage(records: records, nextCursor: nil, source: .server)
        case .empty, .createQueued, .createSaving, .createDuplicate, .createConfirmed:
            return StudentPage(records: records, nextCursor: nil, source: .server)
        case .offline:
            return StudentPage(records: records, nextCursor: nil, source: .cache)
        case .permissionDenied:
            throw StudentRepositoryError.permissionDenied
        case .workflow:
            return workflowPage(request)
        case .cachePrime:
            await resetAcceptanceCacheIfNeeded(member: member)
            await acceptanceCache.save(
                StudentStorePage(
                    documents: records.map(Self.snapshot),
                    nextCursor: nil
                ),
                for: Self.acceptanceCacheKey(request: request, member: member)
            )
            return StudentPage(records: records, nextCursor: nil, source: .server)
        case .cacheOffline:
            await resetAcceptanceCacheIfNeeded(member: member)
            guard let cached = await acceptanceCache.page(
                for: Self.acceptanceCacheKey(request: request, member: member)
            ) else {
                throw StudentRepositoryError.unavailable
            }
            let cachedRecords = try cached.documents.map { try $0.record() }
            records = cachedRecords
            return StudentPage(
                records: cachedRecords,
                nextCursor: cached.nextCursor,
                source: .cache
            )
        }
    }

    func student(
        id: String,
        member: MembershipContext
    ) async throws -> StudentRecord {
        guard let record = records.first(where: { $0.id == id }) else {
            throw StudentRepositoryError.notFound
        }
        return record
    }

    func create(
        _ draft: StudentDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> StudentRecord {
        switch scenario {
        case .createQueued:
            throw StudentRepositoryError.createQueued(operationID: operationID)
        case .createSaving:
            try await Task.sleep(for: .seconds(8))
            return Self.record(
                id: "student-created",
                draft: draft,
                member: member,
                version: 1
            )
        case .createDuplicate:
            throw StudentRepositoryError.duplicate(candidateIDs: [Self.ava.id])
        case .createConfirmed, .workflow:
            let record = Self.record(
                id: "student-created",
                draft: draft,
                member: member,
                version: 1
            )
            records.append(record)
            return record
        case .populated,
             .empty,
             .offline,
             .permissionDenied,
             .archived,
             .cachePrime,
             .cacheOffline:
            throw StudentRepositoryError.unavailable
        }
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
        guard scenario == .workflow,
              let index = records.firstIndex(where: { $0.id == id }) else {
            throw StudentRepositoryError.unavailable
        }
        let current = records[index]
        guard current.metadata.recordVersion == expectedVersion else {
            throw StudentRepositoryError.versionConflict(
                expected: expectedVersion,
                actual: current.metadata.recordVersion
            )
        }
        let updated = Self.record(
            id: id,
            draft: draft,
            member: member,
            version: expectedVersion + 1,
            createdAt: current.metadata.createdAt
        )
        records[index] = updated
        return updated
    }

    func archive(
        id: String,
        expectedVersion: Int,
        operationID: UUID,
        member: MembershipContext
    ) async throws {
        guard scenario == .workflow,
              let index = records.firstIndex(where: { $0.id == id }) else {
            throw StudentRepositoryError.unavailable
        }
        guard records[index].metadata.recordVersion == expectedVersion else {
            throw StudentRepositoryError.versionConflict(
                expected: expectedVersion,
                actual: records[index].metadata.recordVersion
            )
        }
        records[index].isArchived = true
        let currentMetadata = records[index].metadata
        records[index].metadata = CanonicalRecordMetadata(
            schemaVersion: currentMetadata.schemaVersion,
            recordVersion: expectedVersion + 1,
            createdAt: currentMetadata.createdAt,
            createdBy: currentMetadata.createdBy,
            updatedAt: Date(timeIntervalSince1970: 300),
            updatedBy: member.userID
        )
    }

    private func workflowPage(_ request: StudentPageRequest) -> StudentPage {
        var matches = records.filter { record in
            switch request.status {
            case .active:
                return !record.isArchived
            case .archived:
                return record.isArchived
            case .all:
                return true
            }
        }

        if let search = normalized(request.search) {
            matches = matches.filter {
                $0.displayName.localizedCaseInsensitiveContains(search)
                    || ($0.studentIdentifier?.localizedCaseInsensitiveContains(search) ?? false)
            }
        }
        if let schoolID = normalized(request.schoolID) {
            matches = matches.filter { $0.schoolID == schoolID }
        }
        if let grade = normalized(request.grade) {
            matches = matches.filter { $0.grade == grade }
        }
        if let assignedMemberID = normalized(request.assignedMemberID) {
            matches = matches.filter { $0.assignedMemberIDs.contains(assignedMemberID) }
        }

        matches.sort {
            switch request.sort {
            case .alphabetical:
                return $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                    == .orderedAscending
            case .recentlyUpdated:
                return $0.metadata.updatedAt > $1.metadata.updatedAt
            }
        }

        let isUnfiltered = normalized(request.search) == nil
            && normalized(request.schoolID) == nil
            && normalized(request.grade) == nil
            && normalized(request.assignedMemberID) == nil
            && request.status == .active

        if isUnfiltered, request.cursor == nil {
            return StudentPage(
                records: Array(matches.prefix(50)),
                nextCursor: matches.count > 50
                    ? StudentPageCursor(token: "release1-page-2", sort: request.sort)
                    : nil,
                source: .server
            )
        }
        if isUnfiltered, request.cursor?.token == "release1-page-2" {
            return StudentPage(
                records: Array(matches.dropFirst(50)),
                nextCursor: nil,
                source: .server
            )
        }
        return StudentPage(records: matches, nextCursor: nil, source: .server)
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    nonisolated private static func record(
        id: String,
        draft: StudentDraft,
        member: MembershipContext,
        version: Int,
        createdAt: Date = Date(timeIntervalSince1970: 100)
    ) -> StudentRecord {
        StudentRecord(
            id: id,
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
                recordVersion: version,
                createdAt: createdAt,
                createdBy: member.userID,
                updatedAt: Date(timeIntervalSince1970: 200 + Double(version)),
                updatedBy: member.userID
            )
        )
    }

    private func resetAcceptanceCacheIfNeeded(
        member: MembershipContext
    ) async {
        guard shouldResetAcceptanceCache else { return }
        shouldResetAcceptanceCache = false
        await acceptanceCache.invalidate(
            authority: StudentCacheAuthority(
                districtID: member.districtID,
                userID: member.userID
            )
        )
    }

    nonisolated private static func acceptanceCacheKey(
        request: StudentPageRequest,
        member: MembershipContext
    ) -> StudentPageCacheKey {
        StudentPageCacheKey(
            districtID: member.districtID,
            userID: member.userID,
            membershipVersion: member.version,
            search: nil,
            schoolID: request.schoolID,
            grade: request.grade,
            assignedMemberID: request.assignedMemberID,
            status: request.status,
            sort: request.sort,
            cursor: request.cursor,
            limit: request.limit
        )
    }

    nonisolated private static func snapshot(
        _ record: StudentRecord
    ) -> FirebaseStudentSnapshot {
        FirebaseStudentSnapshot(
            documentID: record.id,
            document: FirebaseStudentDocument(
                districtId: record.districtID,
                schoolId: record.schoolID,
                displayName: record.displayName,
                grade: record.grade,
                studentIdentifier: record.studentIdentifier,
                dateOfBirth: record.dateOfBirth,
                pronouns: record.pronouns,
                assignedMemberIDs: record.assignedMemberIDs,
                isArchived: record.isArchived,
                schemaVersion: record.metadata.schemaVersion,
                recordVersion: record.metadata.recordVersion,
                createdAt: record.metadata.createdAt,
                createdBy: record.metadata.createdBy,
                updatedAt: record.metadata.updatedAt,
                updatedBy: record.metadata.updatedBy
            )
        )
    }

    nonisolated private static let fixtureMember = MembershipContext(
        userID: "administrator-fixture",
        districtID: "district-fixture",
        schoolIDs: ["school-fixture"],
        role: .schoolAdministrator,
        capabilities: [.studentReadDetail, .studentWriteDetail, .staffManage],
        assignedStudentIDs: [],
        isActive: true,
        version: 1
    )

    nonisolated private static let ava = record(
        id: "student-ava",
        draft: StudentDraft(
            displayName: "Ava Stone",
            schoolID: "school-fixture",
            grade: "7",
            studentIdentifier: "0012",
            dateOfBirth: nil,
            pronouns: "she / her",
            assignedMemberIDs: ["administrator-fixture"]
        ),
        member: fixtureMember,
        version: 1,
        createdAt: Date(timeIntervalSince1970: 10)
    )

    nonisolated private static let archivedAva = StudentRecord(
        id: ava.id,
        districtID: ava.districtID,
        schoolID: ava.schoolID,
        displayName: ava.displayName,
        grade: ava.grade,
        studentIdentifier: ava.studentIdentifier,
        dateOfBirth: ava.dateOfBirth,
        pronouns: ava.pronouns,
        assignedMemberIDs: ava.assignedMemberIDs,
        isArchived: true,
        metadata: ava.metadata
    )

    nonisolated private static let mia = record(
        id: "student-mia",
        draft: StudentDraft(
            displayName: "Mia Chen",
            schoolID: "school-fixture",
            grade: "8",
            studentIdentifier: "0024",
            dateOfBirth: nil,
            pronouns: "she / her",
            assignedMemberIDs: ["administrator-fixture"]
        ),
        member: fixtureMember,
        version: 1,
        createdAt: Date(timeIntervalSince1970: 30)
    )

    nonisolated private static let liam = record(
        id: "student-liam",
        draft: StudentDraft(
            displayName: "Liam Ortiz",
            schoolID: "school-fixture",
            grade: "6",
            studentIdentifier: "0036",
            dateOfBirth: nil,
            pronouns: "he / him",
            assignedMemberIDs: ["administrator-fixture"]
        ),
        member: fixtureMember,
        version: 1,
        createdAt: Date(timeIntervalSince1970: 50)
    )

    nonisolated private static let cached = record(
        id: "student-cached",
        draft: StudentDraft(
            displayName: "Casey Cached",
            schoolID: "school-fixture",
            grade: "9",
            studentIdentifier: "0048",
            dateOfBirth: nil,
            pronouns: nil,
            assignedMemberIDs: ["administrator-fixture"]
        ),
        member: fixtureMember,
        version: 1,
        createdAt: Date(timeIntervalSince1970: 70)
    )

    nonisolated private static let workflowRecords: [StudentRecord] =
        [
            ava,
            workflowRecord(id: "student-ben", name: "Ben Adams", grade: "5"),
            workflowRecord(id: "student-cora", name: "Cora Bell", grade: "6"),
            workflowRecord(id: "student-devon", name: "Devon Clark", grade: "7"),
            workflowRecord(id: "student-eli", name: "Eli Diaz", grade: "5"),
            workflowRecord(id: "student-finn", name: "Finn Evans", grade: "6"),
            workflowRecord(id: "student-gia", name: "Gia Ford", grade: "7"),
            workflowRecord(id: "student-hana", name: "Hana Green", grade: "5"),
            workflowRecord(id: "student-imani", name: "Imani Hall", grade: "6"),
            liam,
            mia,
        ]
        + (1...39).map { index in
            workflowRecord(
                id: "student-roster-\(index)",
                name: String(format: "Roster Student %02d", index),
                grade: "\(5 + (index % 3))"
            )
        }
        + [
            workflowRecord(id: "student-zoe", name: "Zoe Young", grade: "7"),
        ]

    nonisolated private static func workflowRecord(
        id: String,
        name: String,
        grade: String
    ) -> StudentRecord {
        record(
            id: id,
            draft: StudentDraft(
                displayName: name,
                schoolID: "school-fixture",
                grade: grade,
                studentIdentifier: nil,
                dateOfBirth: nil,
                pronouns: nil,
                assignedMemberIDs: ["administrator-fixture"]
            ),
            member: fixtureMember,
            version: 1
        )
    }
}
#endif
