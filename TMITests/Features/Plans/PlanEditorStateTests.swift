import Foundation
import Testing
@testable import TMI

@MainActor
@Suite("Plan editor state")
struct PlanEditorStateTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let member = MembershipContext(
        userID: "teacher-1",
        districtID: "district-1",
        schoolIDs: ["school-1"],
        role: .teacher,
        capabilities: [.studentReadDetail, .studentWriteDetail],
        assignedStudentIDs: ["student-1"],
        isActive: true,
        version: 1
    )

    @Test("The editor exposes the twelve approved workflow steps in order")
    func workflowSteps() {
        #expect(PlanEditorState.Step.allCases.map(\.title) == [
            "Student",
            "Signals",
            "Model",
            "Professional need",
            "Interests & careers",
            "Immediate action",
            "Goals & measures",
            "Responsible staff",
            "Resources, forms & surveys",
            "Dates & cadence",
            "Student voice & family collaboration",
            "Review & submit",
        ])
    }

    @Test("Recommendations remain explainable and manual model choice remains available")
    func recommendationAndManualSelection() throws {
        let state = makeState()
        state.selectedNeedTags = [.engagement]

        let recommendation = try #require(state.recommendations.first)
        #expect(recommendation.model == .acknowledgeInterests)
        state.chooseRecommendation(recommendation)
        #expect(state.modelSelection == .recommendation(.acknowledgeInterests))

        state.chooseManualModel(.alignYourMind)
        #expect(state.modelSelection == .manual(.alignYourMind))
        #expect(state.title == TMIPlanModel.alignYourMind.rawValue)
    }

    @Test("A new plan has an explicit responsible owner separate from action and goal owners")
    func explicitPlanOwnerDefaultsToCurrentMember() {
        let state = makeState()

        #expect(state.planOwnerMemberID == member.userID)
        #expect(state.immediateAction.ownerMemberID.isEmpty)
        #expect(state.goal.responsibleMemberID.isEmpty)
    }

    @Test("Submission validates action, cadence, owner, dates, voice, family permission, and review")
    func submissionValidation() {
        let state = makeState()
        state.chooseManualModel(.chaseYourSpace)
        state.signalsReviewed = true
        state.professionalNeed = "Increase consistent participation during independent work."
        state.interestsAndCareersReviewed = true
        state.supportMaterialsReviewed = true

        #expect(state.submissionIssues.contains(.immediateActionRequired))
        #expect(state.submissionIssues.contains(.goalRequired))
        #expect(!state.submissionIssues.contains(.planOwnerRequired))
        #expect(state.submissionIssues.contains(.reviewDateRequired))
        #expect(state.submissionIssues.contains(.meetingCadenceRequired))
        #expect(state.submissionIssues.contains(.studentVoiceRequired))
        #expect(state.submissionIssues.contains(.familyPermissionRequired))

        state.immediateAction.title = "Choose a first project task"
        state.immediateAction.ownerMemberID = member.userID
        state.immediateAction.cadence = .weekly
        state.immediateAction.dueDate = now.addingTimeInterval(86_400)
        state.goal.title = "Complete one project milestone"
        state.goal.studentFacingTitle = "Finish one project step"
        state.goal.measure = .count
        state.goal.baseline = "0 per week"
        state.goal.target = "1 per week"
        state.goal.dueDate = now.addingTimeInterval(86_400 * 14)
        state.goal.responsibleMemberID = member.userID
        state.reviewDate = now.addingTimeInterval(86_400 * 7)
        state.targetDate = now.addingTimeInterval(86_400 * 30)
        state.meetingCadence = .weekly
        state.studentVoice = "I want to build something I can show my family."
        state.familyCollaborationPermission = .notAuthorized
        state.reviewedForSubmission = true

        #expect(state.submissionIssues.isEmpty)

        state.immediateAction.dueDate = now.addingTimeInterval(-1)
        #expect(state.submissionIssues.contains(.immediateActionDateInvalid))
        state.immediateAction.dueDate = now.addingTimeInterval(86_400)
        state.immediateAction.ownerMemberID = ""
        #expect(state.submissionIssues.contains(.immediateActionOwnerRequired))
        state.planOwnerMemberID = ""
        #expect(state.submissionIssues.contains(.planOwnerRequired))
    }

    @Test("Autosave uses one operation identity and persists complete goal and action children")
    func autosave() async throws {
        let repository = EditorPlanRepository()
        let children = EditorChildRepository()
        let state = makeState(repository: repository, children: children)
        makeReady(state)

        await state.autosave()
        #expect(repository.createOperationIDs.count == 1)
        #expect(repository.updateCalls == 0)
        #expect(repository.record.ownerMemberID == member.userID)
        #expect(children.savedGoals.count == 1)
        #expect(children.savedActions.count == 1)
        let operationID = try #require(repository.createOperationIDs.first)

        state.summary = "A later draft edit"
        await state.autosave()
        #expect(repository.createOperationIDs == [operationID])
        #expect(repository.updateCalls == 1)
        #expect(state.savePhase == .saved)
    }

    @Test("Submit saves the draft and then requests approval")
    func submit() async {
        let repository = EditorPlanRepository()
        let state = makeState(repository: repository, children: EditorChildRepository())
        makeReady(state)

        await state.submit()

        #expect(repository.transitions == [.pendingApproval])
        #expect(state.savePhase == .submitted)
        #expect(state.currentRecord?.status == .pendingApproval)
    }

    @Test("A recoverable save failure preserves the draft and succeeds on retry")
    func recoverableFailure() async {
        let repository = EditorPlanRepository()
        repository.nextSaveError = .unavailable
        let state = makeState(repository: repository, children: EditorChildRepository())
        makeReady(state)
        state.title = "Keep this local title"

        await state.autosave()
        #expect(state.savePhase == .failed("You appear to be offline. Your draft is still here."))
        #expect(state.title == "Keep this local title")

        await state.autosave()
        #expect(state.savePhase == .saved)
        #expect(state.title == "Keep this local title")
    }

    @Test("Version conflict preserves local and server drafts for explicit resolution")
    func versionConflict() async throws {
        let repository = EditorPlanRepository()
        let existing = repository.record
        repository.nextSaveError = .versionConflict(expected: 1, actual: 2)
        repository.serverRecord.title = "Server title"
        repository.serverRecord.metadata = repository.metadata(version: 2)
        let state = makeState(repository: repository, children: EditorChildRepository(), existingPlan: existing)
        state.title = "Local title"

        await state.autosave()

        let conflict = try #require(state.conflict)
        #expect(conflict.expectedVersion == 1)
        #expect(conflict.actualVersion == 2)
        #expect(conflict.localDraft.title == "Local title")
        #expect(conflict.serverRecord?.title == "Server title")
        #expect(state.title == "Local title")
        #expect(state.savePhase == .versionConflict)
    }

    private func makeState(
        repository: EditorPlanRepository = EditorPlanRepository(),
        children: EditorChildRepository = EditorChildRepository(),
        existingPlan: PlanRecord? = nil
    ) -> PlanEditorState {
        PlanEditorState(
            studentID: "student-1",
            studentName: "Avery Student",
            schoolID: "school-1",
            member: member,
            repository: repository,
            children: children,
            existingPlan: existingPlan,
            now: { now }
        )
    }

    private func makeReady(_ state: PlanEditorState) {
        state.chooseManualModel(.chaseYourSpace)
        state.signalsReviewed = true
        state.professionalNeed = "Increase consistent participation during independent work."
        state.interestsAndCareersReviewed = true
        state.immediateAction.title = "Choose a first project task"
        state.immediateAction.ownerMemberID = member.userID
        state.immediateAction.cadence = .weekly
        state.immediateAction.dueDate = now.addingTimeInterval(86_400)
        state.goal.title = "Complete one project milestone"
        state.goal.studentFacingTitle = "Finish one project step"
        state.goal.measure = .count
        state.goal.baseline = "0 per week"
        state.goal.target = "1 per week"
        state.goal.dueDate = now.addingTimeInterval(86_400 * 14)
        state.goal.responsibleMemberID = member.userID
        state.supportMaterialsReviewed = true
        state.reviewDate = now.addingTimeInterval(86_400 * 7)
        state.targetDate = now.addingTimeInterval(86_400 * 30)
        state.meetingCadence = .weekly
        state.studentVoice = "I want to build something I can show my family."
        state.familyCollaborationPermission = .notAuthorized
        state.reviewedForSubmission = true
    }
}

@MainActor
private final class EditorPlanRepository: PlanRecordRepository {
    var record = PlanRecord(
        id: "plan-1",
        districtID: "district-1",
        studentIDs: ["student-1"],
        schoolIDs: ["school-1"],
        assignedMemberIDs: ["teacher-1"],
        status: .draft,
        model: .chaseYourSpace,
        title: "Draft plan",
        summary: nil,
        startDate: Date(timeIntervalSince1970: 1_800_000_000),
        targetDate: nil,
        approvalStatus: .notRequested,
        metadata: CanonicalRecordMetadata(
            schemaVersion: 1,
            recordVersion: 1,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            createdBy: "teacher-1",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedBy: "teacher-1"
        )
    )
    var serverRecord: PlanRecord
    var createOperationIDs: [UUID] = []
    var updateCalls = 0
    var transitions: [PlanRecordStatus] = []
    var nextSaveError: PlanRecordRepositoryError?

    init() {
        serverRecord = record
    }

    func plans(member: MembershipContext) async throws -> [PlanRecord] { [record] }

    func plan(id: String, member: MembershipContext) async throws -> PlanRecord { serverRecord }

    func create(
        _ draft: PlanDraft,
        operationID: UUID,
        member: MembershipContext
    ) async throws -> PlanRecord {
        if let nextSaveError {
            self.nextSaveError = nil
            throw nextSaveError
        }
        createOperationIDs.append(operationID)
        apply(draft)
        return record
    }

    func update(
        id: String,
        draft: PlanDraft,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord {
        if let nextSaveError {
            self.nextSaveError = nil
            throw nextSaveError
        }
        updateCalls += 1
        apply(draft)
        record.metadata = metadata(version: record.metadata.recordVersion + 1)
        serverRecord = record
        return record
    }

    func transition(
        id: String,
        to status: PlanRecordStatus,
        expectedVersion: Int,
        member: MembershipContext
    ) async throws -> PlanRecord {
        transitions.append(status)
        record.status = status
        record.metadata = metadata(version: record.metadata.recordVersion + 1)
        serverRecord = record
        return record
    }

    func metadata(version: Int) -> CanonicalRecordMetadata {
        CanonicalRecordMetadata(
            schemaVersion: record.metadata.schemaVersion,
            recordVersion: version,
            createdAt: record.metadata.createdAt,
            createdBy: record.metadata.createdBy,
            updatedAt: record.metadata.updatedAt,
            updatedBy: record.metadata.updatedBy
        )
    }

    private func apply(_ draft: PlanDraft) {
        record.studentIDs = draft.studentIDs
        record.schoolIDs = draft.schoolIDs
        record.assignedMemberIDs = draft.assignedMemberIDs
        record.ownerMemberID = draft.ownerMemberID
        record.model = draft.model
        record.title = draft.normalized.title
        record.summary = draft.normalized.summary
        record.startDate = draft.startDate
        record.targetDate = draft.targetDate
        serverRecord = record
    }
}

@MainActor
private final class EditorChildRepository: PlanChildRepositoryProtocol {
    var savedGoals: [GoalRecord] = []
    var savedActions: [ActionRecord] = []

    func goals(planID: String, member: MembershipContext) async throws -> [GoalRecord] { savedGoals }
    func actions(planID: String, member: MembershipContext) async throws -> [ActionRecord] { savedActions }
    func progress(planID: String, member: MembershipContext) async throws -> [ProgressRecord] { [] }
    func revisions(planID: String, member: MembershipContext) async throws -> [PlanRevision] { [] }

    func save(goal: GoalRecord, member: MembershipContext) async throws {
        savedGoals.removeAll { $0.id == goal.id }
        savedGoals.append(goal)
    }

    func save(action: ActionRecord, member: MembershipContext) async throws {
        savedActions.removeAll { $0.id == action.id }
        savedActions.append(action)
    }

    func append(progress: ProgressRecord, member: MembershipContext) async throws {}
    func freeze(revision: PlanRevision, member: MembershipContext) async throws {}
}
