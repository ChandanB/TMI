import Foundation
import Testing
@testable import TMI

@Suite("Dashboard State Model")
struct DashboardStateModelTests {
    @Test("Teacher prioritizes low-engagement students before plan creation work")
    func teacherPrioritizesLowEngagementStudents() {
        let lowEngagementStudent = makeStudent(
            id: "student-low",
            name: "Low Engagement",
            surveyCompleted: true,
            engagementScores: [0.22, 0.24]
        )
        let readyForPlanStudent = makeStudent(
            id: "student-plan",
            name: "Needs Plan",
            surveyCompleted: true,
            engagementScores: [0.72, 0.75]
        )

        let action = DashboardStateModel.prioritizedNextBestAction(
            membership: membership(role: .teacher),
            students: [lowEngagementStudent, readyForPlanStudent],
            plans: []
        )

        #expect(action?.type == .checkProgress)
        #expect(action?.targetStudentId == "student-low")
        #expect(action?.priority == .high)
    }

    @Test("Teacher prioritizes plan creation before survey follow-up")
    func teacherPrioritizesPlanCreationBeforeSurveyFollowUp() {
        let readyForPlanStudent = makeStudent(
            id: "student-plan",
            name: "Needs Plan",
            surveyCompleted: true,
            engagementScores: [0.66, 0.68]
        )
        let surveyPendingStudent = makeStudent(
            id: "student-survey",
            name: "Survey Pending",
            surveyCompleted: false,
            engagementScores: [0.61, 0.63]
        )

        let action = DashboardStateModel.prioritizedNextBestAction(
            membership: membership(role: .teacher),
            students: [readyForPlanStudent, surveyPendingStudent],
            plans: []
        )

        #expect(action?.type == .createPlan)
        #expect(action?.targetStudentId == "student-plan")
        #expect(action?.priority == .medium)
    }

    @Test("Counselor approvals outrank student-level actions")
    func counselorApprovalsOutrankStudentActions() {
        let lowEngagementStudent = makeStudent(
            id: "student-low",
            name: "Low Engagement",
            surveyCompleted: true,
            engagementScores: [0.18, 0.22]
        )
        let pendingPlan = makePlan(
            id: "plan-pending",
            students: [lowEngagementStudent],
            approvalStatus: .pendingApproval
        )

        let action = DashboardStateModel.prioritizedNextBestAction(
            membership: membership(role: .counselor, capabilities: [.planApprove]),
            students: [lowEngagementStudent],
            plans: [pendingPlan]
        )

        #expect(action?.type == .pendingApproval)
        #expect(action?.targetPlanId == "plan-pending")
        #expect(action?.priority == .urgent)
    }

    @Test("Teacher falls back to survey follow-up when it is the only candidate")
    func teacherFallsBackToSurveyFollowUp() {
        let surveyPendingStudent = makeStudent(
            id: "student-survey",
            name: "Survey Pending",
            surveyCompleted: false,
            engagementScores: [0.61, 0.63]
        )

        let action = DashboardStateModel.prioritizedNextBestAction(
            membership: membership(role: .teacher),
            students: [surveyPendingStudent],
            plans: []
        )

        #expect(action?.type == .addInterests)
        #expect(action?.targetStudentId == "student-survey")
        #expect(action?.priority == .low)
    }

    @Test("Next best action is nil when no candidates apply")
    func nextBestActionIsNilWhenNoCandidatesApply() {
        let studentWithPlan = makeStudent(
            id: "student-covered",
            name: "Covered Student",
            surveyCompleted: true,
            engagementScores: [0.64, 0.66]
        )
        let approvedPlan = makePlan(
            id: "plan-approved",
            students: [studentWithPlan],
            approvalStatus: .approved
        )

        let action = DashboardStateModel.prioritizedNextBestAction(
            membership: membership(role: .teacher),
            students: [studentWithPlan],
            plans: [approvedPlan]
        )

        #expect(action == nil)
    }

    @MainActor
    @Test("Dashboard plan metrics are computed from canonical plan records")
    func dashboardComputesMetricsFromCanonicalPlans() async {
        let activePlan = makePlanRecord(
            id: "plan-active",
            status: .active,
            approvalStatus: .approved,
            studentIDs: ["student-a"]
        )
        let pendingPlan = makePlanRecord(
            id: "plan-pending",
            status: .pendingApproval,
            approvalStatus: .pending,
            studentIDs: ["student-b"]
        )
        let archivedPlan = makePlanRecord(
            id: "plan-archived",
            status: .archived,
            approvalStatus: .approved,
            studentIDs: ["student-c"]
        )
        let planRepository = DashboardTestPlanRepository(
            plans: [activePlan, pendingPlan, archivedPlan]
        )
        let studentRepository = DashboardTestStudentRepository()
        let model = DashboardStateModel(
            studentRepository: studentRepository,
            planRepository: planRepository
        )

        await model.fetchWithMembership(membership(role: .teacher))

        #expect(model.value?.activeTMIPlans == 1)
        #expect(model.value?.plansAligned == 2)
        #expect(model.value?.nextBestAction?.type == .pendingApproval)
        #expect(model.value?.nextBestAction?.targetPlanId == "plan-pending")
    }

    @MainActor
    @Test("Dashboard recent activity and role data are wired to canonical records")
    func dashboardWiresRecentActivityAndRoleDataToCanonicalRecords() async {
        let now = Date()
        let studentRecord = makeStudentRecord(
            id: "student-a",
            displayName: "Ada Lovelace",
            createdAt: now.addingTimeInterval(-30 * 24 * 60 * 60)
        )
        let activePlan = makePlanRecord(
            id: "plan-active",
            status: .active,
            approvalStatus: .approved,
            studentIDs: ["student-a"],
            updatedAt: now
        )
        let pendingPlan = makePlanRecord(
            id: "plan-pending",
            status: .pendingApproval,
            approvalStatus: .pending,
            studentIDs: ["student-a"],
            updatedAt: now
        )
        let planRepository = DashboardTestPlanRepository(
            plans: [activePlan, pendingPlan]
        )
        let studentRepository = DashboardTestStudentRepository(records: [studentRecord])
        let model = DashboardStateModel(
            studentRepository: studentRepository,
            planRepository: planRepository
        )

        await model.fetchWithMembership(membership(role: .teacher))

        let updateActivity = model.value?.recentActivities.first {
            $0.title == "TMI Plan Updated"
        }
        #expect(updateActivity != nil)
        #expect(updateActivity?.description.contains("Ada Lovelace") == true)
        #expect(model.value?.roleData?.classroomPlansActive == 1)
    }
}

private extension DashboardStateModelTests {
    func membership(
        role: StaffRole,
        capabilities: Set<Capability> = []
    ) -> MembershipContext {
        MembershipContext(
            userID: "staff-1",
            districtID: "district-a",
            schoolIDs: ["school-a"],
            role: role,
            capabilities: capabilities,
            assignedStudentIDs: ["student-low", "student-plan", "student-survey", "student-covered"],
            isActive: true,
            version: 1
        )
    }

    func makeStudent(
        id: String,
        name: String,
        surveyCompleted: Bool,
        engagementScores: [Double]
    ) -> Student {
        Student(
            id: id,
            name: name,
            grade: "5",
            school: "North Elementary",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            surveyResults: surveyCompleted ? [
                SurveyResult(
                    id: "\(id)-survey",
                    surveyName: "Interest Survey",
                    date: Date(),
                    isComplete: true,
                    responses: []
                )
            ] : [],
            engagementHistory: engagementScores.enumerated().map { index, score in
                EngagementRecord(
                    date: Date().addingTimeInterval(TimeInterval(index) * -86_400),
                    score: score,
                    source: .teacherInput
                )
            }
        )
    }

    func makePlan(
        id: String,
        students: [Student],
        approvalStatus: PlanApprovalStatus
    ) -> TMIPlan {
        TMIPlan(
            id: id,
            title: "Support Plan",
            students: students,
            model: .chaseYourSpace,
            interests: [],
            startDate: Date(),
            endDate: nil,
            creationDate: Date(),
            lastUpdated: Date(),
            goals: [],
            progress: 0,
            notes: "",
            createdBy: "teacher-1",
            approvalStatus: approvalStatus
        )
    }

    func makePlanRecord(
        id: String,
        status: PlanRecordStatus,
        approvalStatus: PlanApprovalState,
        studentIDs: Set<String>,
        updatedAt: Date = Date()
    ) -> PlanRecord {
        let now = Date()
        return PlanRecord(
            id: id,
            districtID: "district-a",
            studentIDs: studentIDs,
            schoolIDs: ["school-a"],
            assignedMemberIDs: ["staff-1"],
            ownerMemberID: "staff-1",
            status: status,
            model: .chaseYourSpace,
            title: "Support Plan",
            summary: nil,
            startDate: now.addingTimeInterval(-604_800),
            targetDate: nil,
            approvalStatus: approvalStatus,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 1,
                createdAt: now.addingTimeInterval(-604_800),
                createdBy: "staff-1",
                updatedAt: updatedAt,
                updatedBy: "staff-1"
            )
        )
    }

    func makeStudentRecord(
        id: String,
        displayName: String,
        createdAt: Date
    ) -> StudentRecord {
        StudentRecord(
            id: id,
            districtID: "district-a",
            schoolID: "school-a",
            displayName: displayName,
            grade: "5",
            studentIdentifier: nil,
            dateOfBirth: nil,
            pronouns: nil,
            assignedMemberIDs: ["staff-1"],
            isArchived: false,
            metadata: CanonicalRecordMetadata(
                schemaVersion: 1,
                recordVersion: 1,
                createdAt: createdAt,
                createdBy: "staff-1",
                updatedAt: createdAt,
                updatedBy: "staff-1"
            )
        )
    }
}

@MainActor
private final class DashboardTestPlanRepository: PlanRecordRepository {
    private let stored: [PlanRecord]

    init(plans: [PlanRecord]) { stored = plans }

    func plans(member: MembershipContext) async throws -> [PlanRecord] { stored }
    func plan(id: String, member: MembershipContext) async throws -> PlanRecord {
        guard let record = stored.first(where: { $0.id == id }) else {
            throw PlanRecordRepositoryError.notFound
        }
        return record
    }
    func create(_ draft: PlanDraft, operationID: UUID, member: MembershipContext) async throws -> PlanRecord {
        stored[0]
    }
    func update(id: String, draft: PlanDraft, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        stored[0]
    }
    func transition(id: String, to status: PlanRecordStatus, expectedVersion: Int, member: MembershipContext) async throws -> PlanRecord {
        stored[0]
    }
}

private struct DashboardTestStudentRepository: StudentRepository {
    private let records: [StudentRecord]

    init(records: [StudentRecord] = []) {
        self.records = records
    }

    func page(_ request: StudentPageRequest, member: MembershipContext) async throws -> StudentPage {
        StudentPage(records: records, nextCursor: nil, source: .server)
    }
    func student(id: String, member: MembershipContext) async throws -> StudentRecord {
        throw StudentRepositoryError.notFound
    }
    func create(_ draft: StudentDraft, operationID: UUID, member: MembershipContext) async throws -> StudentRecord {
        throw StudentRepositoryError.invalidDraft
    }
    func reconcilePendingCreates(member: MembershipContext) async throws -> [StudentRecord] { [] }
    func update(id: String, draft: StudentDraft, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws -> StudentRecord {
        throw StudentRepositoryError.invalidDraft
    }
    func archive(id: String, expectedVersion: Int, operationID: UUID, member: MembershipContext) async throws {}
}
