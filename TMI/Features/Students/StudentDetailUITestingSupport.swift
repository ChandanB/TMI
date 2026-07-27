#if DEBUG
import SwiftUI

@MainActor
struct StudentDetailUITestingContent: View {
    private let member: MembershipContext
    private let dependencies: AppDependencies
    @State private var router: AppRouter

    init(fixture: String) {
        let member = Self.member
        let repository = StudentDetailUITestingRepository(
            fixture: fixture
        )
        self.member = member
        self.dependencies = .preview(
            memberships: [member],
            studentDetailRepository: repository
        )
        _router = State(
            initialValue: AppRouter(
                policy: AppNavigationPolicy(membership: member)
            )
        )
    }

    var body: some View {
        NavigationStack {
            StudentDetailView(
                studentID: Self.student.id,
                member: member
            )
        }
        .environment(\.appDependencies, dependencies)
        .environment(router)
        .tint(TMIColors.teal)
    }

    private static let member = MembershipContext(
        userID: "teacher-a",
        districtID: "district-a",
        schoolIDs: ["school-a"],
        role: .teacher,
        capabilities: [],
        assignedStudentIDs: ["student-a"],
        isActive: true,
        version: 1
    )

    nonisolated fileprivate static let student = StudentRecord(
        id: "student-a",
        districtID: "district-a",
        schoolID: "school-a",
        displayName: "Ava Stone",
        grade: "7",
        studentIdentifier: "0012",
        dateOfBirth: nil,
        pronouns: "she / her",
        assignedMemberIDs: ["teacher-a", "counselor-a"],
        isArchived: false,
        metadata: CanonicalRecordMetadata(
            schemaVersion: 1,
            recordVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdBy: "teacher-a",
            updatedAt: Date(timeIntervalSince1970: 1_700_100_000),
            updatedBy: "teacher-a"
        )
    )
}

private actor StudentDetailUITestingRepository: StudentDetailRepository {
    private enum Fixture: Equatable {
        case populated
        case release1
        case offline
        case permissionDenied

        init(rawValue: String) {
            switch rawValue {
            case "student-detail-offline":
                self = .offline
            case "student-detail-release1":
                self = .release1
            case "student-detail-permission-denied":
                self = .permissionDenied
            default:
                self = .populated
            }
        }
    }

    private let fixture: Fixture

    init(fixture: String) {
        self.fixture = Fixture(rawValue: fixture)
    }

    func hub(
        studentID: String,
        member _: MembershipContext
    ) async throws -> StudentDetailHubSnapshot {
        guard fixture != .permissionDenied else {
            throw StudentRepositoryError.permissionDenied
        }
        guard studentID == StudentDetailUITestingContent.student.id else {
            throw StudentRepositoryError.notFound
        }
        return StudentDetailHubSnapshot(
            student: StudentDetailUITestingContent.student,
            activePlanStatus: .none,
            lastInteractionAt: Date(timeIntervalSince1970: 1_700_200_000),
            collections: .empty,
            source: fixture == .offline ? .cache : .server
        )
    }

    func privateNotes(
        studentID _: String,
        member _: MembershipContext
    ) async throws -> StudentDetailRelatedRecords<StudentPrivateNoteProjection> {
        guard fixture != .permissionDenied else {
            throw StudentRepositoryError.permissionDenied
        }
        guard fixture != .release1 else {
            return .unavailable(nextAvailableRelease: 4)
        }
        return .available(
            [
                StudentPrivateNoteProjection(
                    id: "note-a",
                    summary: "Staff follow-up scheduled",
                    occurredAt: Date(timeIntervalSince1970: 1_700_300_000)
                ),
            ]
        )
    }

    func studentReflections(
        studentID _: String,
        member _: MembershipContext
    ) async throws -> StudentDetailRelatedRecords<StudentReflectionProjection> {
        guard fixture != .permissionDenied else {
            throw StudentRepositoryError.permissionDenied
        }
        guard fixture != .release1 else {
            return .unavailable(nextAvailableRelease: 4)
        }
        return .available(
            [
                StudentReflectionProjection(
                    id: "reflection-a",
                    summary: "Student check-in completed",
                    occurredAt: Date(timeIntervalSince1970: 1_700_250_000)
                ),
            ]
        )
    }

    func update(
        id: String,
        draft: StudentDraft,
        expectedVersion: Int,
        operationID _: UUID,
        member _: MembershipContext
    ) async throws -> StudentRecord {
        guard fixture == .populated, expectedVersion == 1 else {
            throw StudentRepositoryError.onlineRequired
        }
        return StudentRecord(
            id: id,
            districtID: StudentDetailUITestingContent.student.districtID,
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
                recordVersion: 2,
                createdAt: StudentDetailUITestingContent.student.metadata.createdAt,
                createdBy: StudentDetailUITestingContent.student.metadata.createdBy,
                updatedAt: Date(timeIntervalSince1970: 1_700_400_000),
                updatedBy: "teacher-a"
            )
        )
    }

    func archive(
        id _: String,
        expectedVersion _: Int,
        operationID _: UUID,
        member _: MembershipContext
    ) async throws {
        guard fixture == .populated else {
            throw StudentRepositoryError.onlineRequired
        }
    }
}
#endif
