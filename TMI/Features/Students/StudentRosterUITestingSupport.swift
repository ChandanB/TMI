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

    private static let fixtureMember = MembershipContext(
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
    }

    private let scenario: Scenario

    init(scenario: Scenario) {
        self.scenario = scenario
    }

    func page(
        _ request: StudentPageRequest,
        member: MembershipContext
    ) async throws -> StudentPage {
        switch scenario {
        case .populated:
            return StudentPage(records: [Self.ava], nextCursor: nil, source: .server)
        case .archived:
            return StudentPage(records: [Self.archivedAva], nextCursor: nil, source: .server)
        case .empty, .createQueued, .createSaving, .createDuplicate:
            return StudentPage(records: [], nextCursor: nil, source: .server)
        case .offline:
            return StudentPage(records: [Self.ava], nextCursor: nil, source: .cache)
        case .permissionDenied:
            throw StudentRepositoryError.permissionDenied
        }
    }

    func student(
        id: String,
        member: MembershipContext
    ) async throws -> StudentRecord {
        guard id == Self.ava.id else { throw StudentRepositoryError.notFound }
        return Self.ava
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
            return StudentRecord(
                id: "student-created",
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
                    createdAt: .now,
                    createdBy: member.userID,
                    updatedAt: .now,
                    updatedBy: member.userID
                )
            )
        case .createDuplicate:
            throw StudentRepositoryError.duplicate(candidateIDs: [Self.ava.id])
        case .populated, .empty, .offline, .permissionDenied, .archived:
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

    private static let ava = StudentRecord(
        id: "student-ava",
        districtID: "district-fixture",
        schoolID: "school-fixture",
        displayName: "Ava Stone",
        grade: "7",
        studentIdentifier: "0012",
        dateOfBirth: nil,
        pronouns: "she / her",
        assignedMemberIDs: ["administrator-fixture"],
        isArchived: false,
        metadata: CanonicalRecordMetadata(
            schemaVersion: 1,
            recordVersion: 1,
            createdAt: Date(timeIntervalSince1970: 10),
            createdBy: "administrator-fixture",
            updatedAt: Date(timeIntervalSince1970: 20),
            updatedBy: "administrator-fixture"
        )
    )

    private static let archivedAva = StudentRecord(
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
}
#endif
