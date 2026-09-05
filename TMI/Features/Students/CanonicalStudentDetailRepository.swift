import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore

/// Aggregates canonical discovery and plan records for the student hub.
/// A read failure is never converted into a zero count.
nonisolated struct CanonicalStudentDetailRepository: StudentDetailRepository {
    struct Signals: Sendable {
        var plans: [PlanRecord] = []
        var interestIDs: [String] = []
        var savedCareerIDs: [String] = []
        var historicalCareerIDs: [String] = []
    }
    typealias LoadSignals = @MainActor @Sendable (String, MembershipContext) async throws -> Signals
    private let students: any StudentRepository
    private let loadSignals: LoadSignals

    init(students: any StudentRepository, loadSignals: @escaping LoadSignals) {
        self.students = students
        self.loadSignals = loadSignals
    }

    func hub(studentID: String, member: MembershipContext) async throws -> StudentDetailHubSnapshot {
        let student = try await students.student(id: studentID, member: member)
        guard member.isActive, student.id == studentID, student.districtID == member.districtID else {
            throw StudentRepositoryError.permissionDenied
        }
        let signals = try await loadSignals(studentID, member)
        let plans = signals.plans.filter { $0.districtID == member.districtID && $0.studentIDs.contains(studentID) }
        let active = plans.filter { $0.status == .active && $0.approvalStatus == .approved }.count
        return StudentDetailHubSnapshot(student: student,
            activePlanStatus: active == 0 ? .none : .active(count: active),
            lastInteractionAt: nil,
            collections: StudentDetailCanonicalCollections(currentItemIDs: [
                .interests: signals.interestIDs.sorted(), .careers: signals.savedCareerIDs.sorted(),
                .plans: plans.filter { $0.status.isOpen }.map(\.id).sorted()
            ], historyItemIDs: [
                .careers: signals.historicalCareerIDs.sorted(),
                .plans: plans.filter { !$0.status.isOpen }.map(\.id).sorted()
            ]), source: .server)
    }

    func privateNotes(studentID: String, member: MembershipContext) async throws -> StudentDetailRelatedRecords<StudentPrivateNoteProjection> {
        .unavailable(nextAvailableRelease: 4)
    }
    func studentReflections(studentID: String, member: MembershipContext) async throws -> StudentDetailRelatedRecords<StudentReflectionProjection> {
        .unavailable(nextAvailableRelease: 4)
    }
    func update(id: String, draft: StudentDraft, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws -> StudentRecord {
        try await students.update(id: id, draft: draft, expectedVersion: expectedVersion, operationID: operationID, member: member)
    }
    func archive(id: String, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws {
        try await students.archive(id: id, expectedVersion: expectedVersion, operationID: operationID, member: member)
    }

    @MainActor
    static func firebase(students: any StudentRepository, plans: any PlanRecordRepository, firestore: Firestore) -> Self {
        Self(students: students) { studentID, member in
#if DEBUG
            if DebugPlanRepository.isDebug(member) {
                return Signals(plans: try await plans.plans(member: member))
            }
#endif
            guard Auth.auth().currentUser?.uid == member.userID, member.isActive else {
                throw StudentRepositoryError.permissionDenied
            }
            do {
                let records = try await plans.plans(member: member)
                let student = firestore.collection("districts").document(member.districtID)
                    .collection("students").document(studentID)
                let interests = try await student.collection("interests").getDocuments(source: .server)
                let careers = try await student.collection("careers").getDocuments(source: .server)
                let interestIDs = try interests.documents.map { document in
                    let edge = try document.data(as: StudentInterest.self)
                    guard edge.studentId == studentID else { throw StudentRepositoryError.invalidResponse }
                    return document.documentID
                }
                let relationships = try careers.documents.map { document in
                    guard let edge = CareerRelationshipRepository.record(id: document.documentID, data: document.data(),
                        expectedDistrictID: member.districtID, expectedStudentID: studentID) else {
                        throw StudentRepositoryError.invalidResponse
                    }
                    return edge
                }
                guard Auth.auth().currentUser?.uid == member.userID else { throw StudentRepositoryError.permissionDenied }
                return Signals(plans: records, interestIDs: interestIDs,
                    savedCareerIDs: relationships.filter(\.isSaved).map(\.careerID),
                    historicalCareerIDs: relationships.filter { !$0.isSaved && $0.hasStudentOpinion }.map(\.careerID))
            } catch {
                if let error = error as? StudentRepositoryError { throw error }
                switch CanonicalPlanRepository.mapped(error) {
                case .permissionDenied: throw StudentRepositoryError.permissionDenied
                case .unavailable: throw StudentRepositoryError.unavailable
                default: throw StudentRepositoryError.invalidResponse
                }
            }
        }
    }
}
