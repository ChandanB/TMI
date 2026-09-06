#if DEBUG
import Foundation
import SwiftUI

@MainActor
struct CareerDiscoveryUITestingContent: View {
    private let member: MembershipContext
    private let relationshipRepository: CareerDiscoveryUITestingRelationshipRepository
    private let careerRepository: CareerRepository
    private let planRepository: CareerAttachmentUITestingPlanRepository

    init() {
        self.member = MembershipContext(
            userID: "teacher-a",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: .teacher,
            capabilities: [],
            assignedStudentIDs: ["student-a"],
            isActive: true,
            version: 1
        )
        self.relationshipRepository = CareerDiscoveryUITestingRelationshipRepository()
        self.planRepository = CareerAttachmentUITestingPlanRepository()
        self.careerRepository = CareerRepository(
            catalog: CareerDiscoveryUITestingCatalog()
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                StudentCareerDiscoveryView(
                    studentID: "student-a",
                    studentName: "Ava Stone",
                    approvedInterests: [Self.technologyInterest],
                    clusters: [],
                    member: member,
                    relationshipRepository: relationshipRepository,
                    planRepository: planRepository,
                    repository: careerRepository
                )
                .padding(TMISpacing.lg)
            }
            .navigationTitle("Career discovery")
        }
        .tint(TMIColors.teal)
    }

    private static let technologyInterest = StudentInterest(
        studentId: "student-a",
        interestId: "technology",
        name: "Technology",
        category: "academic",
        strength: 4,
        rank: 1,
        source: .survey,
        capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
        createdBy: "teacher-a",
        sourceResponseID: nil,
        sourceDefinitionID: nil,
        sourceDefinitionVersion: nil,
        mergeHistory: []
    )
}

@MainActor
struct CareerDetailUITestingContent: View {
    private let member: MembershipContext
    private let planRepository: CareerAttachmentUITestingPlanRepository
    private let planAttacher: CareerAttachmentUITestingAttacher

    init() {
        self.member = MembershipContext(
            userID: "teacher-a",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: .teacher,
            capabilities: [.studentReadDetail, .studentWriteDetail],
            assignedStudentIDs: ["student-a"],
            isActive: true,
            version: 1
        )
        self.planRepository = CareerAttachmentUITestingPlanRepository()
        self.planAttacher = CareerAttachmentUITestingAttacher()
    }

    var body: some View {
        NavigationStack {
            CanonicalCareerDetailView(
                career: Self.career,
                match: CareerMatch(
                    careerID: Self.career.id,
                    title: Self.career.title,
                    score: 1,
                    rank: 1,
                    matchedInterestIDs: ["technology"],
                    matchedClusterIDs: [],
                    reasons: ["Matches interests you approved: Technology."],
                    algorithmVersion: CareerMatcher.algorithmVersion
                ),
                studentContext: CareerPlanAttachmentContext(
                    studentID: "student-a",
                    studentName: "Ava Stone",
                    member: member,
                    planRepository: planRepository,
                    planAttacher: planAttacher
                )
            )
        }
        .tint(TMIColors.teal)
    }

    private static let career = CareerRecord(
        id: "technology--frontend-developer",
        title: "Frontend Developer",
        category: "technology",
        subcategory: "Software Development",
        summary: "Builds the parts of apps and websites people use.",
        interestIDs: ["technology"],
        clusterIDs: ["technology"],
        educationLevel: .bachelors,
        salary: nil,
        outlook: nil
    )
}

@MainActor
private final class CareerAttachmentUITestingAttacher: CareerPlanAttaching {
    func attach(_ request: CareerPlanAttachmentRequest) async throws -> CareerPlanAttachmentRequest {
        request
    }
}

@MainActor
private final class CareerAttachmentUITestingPlanRepository: PlanRecordRepository {
    private var record = PlanRecord(
        id: "plan-a",
        districtID: "district-a",
        studentIDs: ["student-a"],
        schoolIDs: ["school-a"],
        assignedMemberIDs: ["teacher-a"],
        ownerMemberID: "teacher-a",
        status: .draft,
        model: .acknowledgeInterests,
        title: "Technology confidence plan",
        summary: nil,
        startDate: Date(timeIntervalSince1970: 1_700_000_000),
        targetDate: nil,
        approvalStatus: .notRequested,
        metadata: CanonicalRecordMetadata(
            schemaVersion: 1,
            recordVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdBy: "teacher-a",
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedBy: "teacher-a"
        )
    )

    func plans(member _: MembershipContext) async throws -> [PlanRecord] { [record] }
    func plan(id _: String, member _: MembershipContext) async throws -> PlanRecord { record }
    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }
    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        throw PlanRecordRepositoryError.unavailable
    }
}

@MainActor
private struct CareerDiscoveryUITestingCatalog: CareerCatalogProviding {
    func careers() async throws -> [CareerRecord] {
        [
            CareerRecord(
                id: "health--registered-nurse",
                title: "Registered Nurse",
                category: "health",
                subcategory: "Patient Care",
                summary: "Cares for patients and coordinates treatment.",
                interestIDs: ["helping"],
                clusterIDs: ["health"],
                educationLevel: .associates,
                salary: nil,
                outlook: nil
            ),
            CareerRecord(
                id: "technology--frontend-developer",
                title: "Frontend Developer",
                category: "technology",
                subcategory: "Software Development",
                summary: "Builds the parts of apps and websites people use.",
                interestIDs: ["technology"],
                clusterIDs: ["technology"],
                educationLevel: .bachelors,
                salary: nil,
                outlook: nil
            ),
            CareerRecord(
                id: "arts--illustrator",
                title: "Illustrator",
                category: "arts",
                subcategory: nil,
                summary: "Creates visual stories and explanations.",
                interestIDs: ["creative_arts"],
                clusterIDs: ["arts"],
                educationLevel: .varies,
                salary: nil,
                outlook: nil
            ),
        ]
    }
}

@MainActor
private final class CareerDiscoveryUITestingRelationshipRepository:
    CareerRelationshipProviding {
    private var stored: [String: CareerRelationship] = [:]

    func relationships(
        studentID: String,
        member _: MembershipContext
    ) async throws -> [CareerRelationship] {
        stored.values.filter { $0.studentID == studentID }
    }

    func save(
        _ relationship: CareerRelationship,
        member _: MembershipContext
    ) async throws {
        stored[relationship.careerID] = relationship
    }
}
#endif
