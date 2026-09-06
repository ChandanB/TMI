import Foundation
import Observation

@MainActor
@Observable
final class PlanEditorState {
    enum Step: Int, CaseIterable, Identifiable, Sendable {
        case student
        case signals
        case model
        case professionalNeed
        case interestsAndCareers
        case immediateAction
        case goalsAndMeasures
        case responsibleStaff
        case supportMaterials
        case datesAndCadence
        case studentVoiceAndFamily
        case reviewAndSubmit

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .student: "Student"
            case .signals: "Signals"
            case .model: "Model"
            case .professionalNeed: "Professional need"
            case .interestsAndCareers: "Interests & careers"
            case .immediateAction: "Immediate action"
            case .goalsAndMeasures: "Goals & measures"
            case .responsibleStaff: "Responsible staff"
            case .supportMaterials: "Resources, forms & surveys"
            case .datesAndCadence: "Dates & cadence"
            case .studentVoiceAndFamily: "Student voice & family collaboration"
            case .reviewAndSubmit: "Review & submit"
            }
        }
    }

    enum ModelSelection: Equatable, Sendable {
        case recommendation(TMIPlanModel)
        case manual(TMIPlanModel)

        var model: TMIPlanModel {
            switch self {
            case .recommendation(let model), .manual(let model): model
            }
        }

        var source: PlanModelSelectionSource {
            switch self {
            case .recommendation: .recommendation
            case .manual: .manual
            }
        }
    }

    enum SavePhase: Equatable, Sendable {
        case idle
        case saving
        case saved
        case submitted
        case failed(String)
        case versionConflict
    }

    enum SubmissionIssue: String, CaseIterable, Equatable, Sendable {
        case modelRequired
        case signalsReviewRequired
        case professionalNeedRequired
        case interestsAndCareersReviewRequired
        case planOwnerRequired
        case immediateActionRequired
        case immediateActionOwnerRequired
        case immediateActionCadenceRequired
        case immediateActionDateRequired
        case immediateActionDateInvalid
        case goalRequired
        case goalBaselineRequired
        case goalTargetRequired
        case goalMeasureRequired
        case goalOwnerRequired
        case goalDateRequired
        case goalDateInvalid
        case supportMaterialsReviewRequired
        case reviewDateRequired
        case reviewDateInvalid
        case targetDateRequired
        case targetDateInvalid
        case meetingCadenceRequired
        case studentVoiceRequired
        case familyPermissionRequired
        case familyConsentRequired
        case finalReviewRequired

        var message: String {
            switch self {
            case .modelRequired: "Choose an intervention model."
            case .signalsReviewRequired: "Review the student signals and data sources."
            case .professionalNeedRequired: "Describe the professional need."
            case .interestsAndCareersReviewRequired: "Review the student's interests and careers."
            case .planOwnerRequired: "Assign a responsible owner for the plan."
            case .immediateActionRequired: "Add one immediate next action."
            case .immediateActionOwnerRequired: "Assign the immediate action to a staff member."
            case .immediateActionCadenceRequired: "Choose a cadence for the immediate action."
            case .immediateActionDateRequired: "Set a due date for the immediate action."
            case .immediateActionDateInvalid: "The immediate action cannot be due before the plan starts."
            case .goalRequired: "Add at least one measurable goal."
            case .goalBaselineRequired: "Add a goal baseline."
            case .goalTargetRequired: "Add a goal target."
            case .goalMeasureRequired: "Choose how the goal will be measured."
            case .goalOwnerRequired: "Assign responsible staff for the goal."
            case .goalDateRequired: "Set a due date for the goal."
            case .goalDateInvalid: "The goal cannot be due before the plan starts."
            case .supportMaterialsReviewRequired: "Review resources, activities, forms, and surveys."
            case .reviewDateRequired: "Set a review date."
            case .reviewDateInvalid: "The review date must fall within the plan dates."
            case .targetDateRequired: "Set an end date."
            case .targetDateInvalid: "The end date cannot precede the start date."
            case .meetingCadenceRequired: "Choose a meeting cadence."
            case .studentVoiceRequired: "Record the student's voice in their own words."
            case .familyPermissionRequired: "Record whether family collaboration is authorized."
            case .familyConsentRequired: "Link the consent record that authorizes family collaboration."
            case .finalReviewRequired: "Complete the final review before submitting."
            }
        }
    }

    struct ImmediateActionDraft: Equatable, Sendable {
        var title = ""
        var ownerMemberID = ""
        var audience: ActionAudience = .staff
        var cadence: ActionCadence?
        var dueDate: Date?
    }

    struct GoalDraft: Equatable, Sendable {
        var title = ""
        var studentFacingTitle = ""
        var measure: GoalMeasure?
        var baseline = ""
        var target = ""
        var dueDate: Date?
        var responsibleMemberID = ""
    }

    struct Conflict: Equatable, Sendable {
        let expectedVersion: Int
        let actualVersion: Int
        let localDraft: PlanDraft
        let serverRecord: PlanRecord?
    }

    let studentID: String
    let studentName: String
    let schoolID: String
    let member: MembershipContext

    var modelSelection: ModelSelection?
    var selectedNeedTags: [PlanNeedTag]
    var signalsReviewed: Bool
    var professionalNeed: String
    var interestsAndCareersReviewed: Bool
    var relatedInterestIDs: Set<String>
    var relatedCareerIDs: Set<String>
    var planOwnerMemberID: String
    var immediateAction: ImmediateActionDraft
    var goal: GoalDraft
    var supportMaterialsReviewed: Bool
    var startDate: Date
    var targetDate: Date?
    var reviewDate: Date?
    var meetingCadence: ActionCadence?
    var studentVoice: String
    var familyCollaborationPermission: PlanFamilyCollaborationPermission
    var familyConsentID: String
    var reviewedForSubmission = false
    var title: String
    var summary: String
    var savePhase: SavePhase = .idle
    var currentRecord: PlanRecord?
    var conflict: Conflict?

    @ObservationIgnored private let repository: any PlanRecordRepository
    @ObservationIgnored private let children: any PlanChildRepositoryProtocol
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let operationID: UUID
    @ObservationIgnored private var selectedRecommendation: PlanRecommendation?
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?

    init(
        studentID: String,
        studentName: String,
        schoolID: String,
        member: MembershipContext,
        repository: any PlanRecordRepository,
        children: any PlanChildRepositoryProtocol,
        existingPlan: PlanRecord? = nil,
        now: @escaping () -> Date = { Date() },
        operationID: UUID = UUID()
    ) {
        self.studentID = studentID
        self.studentName = studentName
        self.schoolID = schoolID
        self.member = member
        self.repository = repository
        self.children = children
        self.now = now
        self.operationID = operationID
        self.currentRecord = existingPlan

        if let existingPlan {
            switch existingPlan.modelSelectionSource {
            case .recommendation:
                self.modelSelection = .recommendation(existingPlan.model)
            case .manual, nil:
                self.modelSelection = .manual(existingPlan.model)
            }
            self.selectedNeedTags = existingPlan.needTags
            self.signalsReviewed = existingPlan.signalsReviewed
            self.professionalNeed = existingPlan.professionalNeed ?? ""
            self.interestsAndCareersReviewed = existingPlan.interestsAndCareersReviewed
            self.relatedInterestIDs = existingPlan.relatedInterestIDs
            self.relatedCareerIDs = existingPlan.relatedCareerIDs
            self.planOwnerMemberID = existingPlan.effectiveOwnerMemberID
            self.supportMaterialsReviewed = existingPlan.supportMaterialsReviewed
            self.startDate = existingPlan.startDate
            self.targetDate = existingPlan.targetDate
            self.reviewDate = existingPlan.reviewDate
            self.meetingCadence = existingPlan.meetingCadence
            self.studentVoice = existingPlan.studentVoice ?? ""
            self.familyCollaborationPermission = existingPlan.familyCollaborationPermission
            self.familyConsentID = existingPlan.familyConsentID ?? ""
            self.title = existingPlan.title
            self.summary = existingPlan.summary ?? ""
        } else {
            self.modelSelection = nil
            self.selectedNeedTags = []
            self.signalsReviewed = false
            self.professionalNeed = ""
            self.interestsAndCareersReviewed = false
            self.relatedInterestIDs = []
            self.relatedCareerIDs = []
            self.planOwnerMemberID = member.userID
            self.supportMaterialsReviewed = false
            self.startDate = now()
            self.targetDate = nil
            self.reviewDate = nil
            self.meetingCadence = nil
            self.studentVoice = ""
            self.familyCollaborationPermission = .notRecorded
            self.familyConsentID = ""
            self.title = ""
            self.summary = ""
        }

        self.immediateAction = ImmediateActionDraft()
        self.goal = GoalDraft()
    }

    var recommendations: [PlanRecommendation] {
        var input = PlanRecommendationInput()
        input.needTags = selectedNeedTags
        return PlanRecommendationEngine.recommendations(for: input)
    }

    var selectedModel: TMIPlanModel? { modelSelection?.model }

    var canEdit: Bool {
        currentRecord?.status.isEditable ?? true
    }

    var submissionIssues: [SubmissionIssue] {
        var issues: [SubmissionIssue] = []
        if modelSelection == nil { issues.append(.modelRequired) }
        if !signalsReviewed { issues.append(.signalsReviewRequired) }
        if professionalNeed.trimmed.isEmpty { issues.append(.professionalNeedRequired) }
        if !interestsAndCareersReviewed { issues.append(.interestsAndCareersReviewRequired) }
        if planOwnerMemberID.trimmed.isEmpty { issues.append(.planOwnerRequired) }

        if immediateAction.title.trimmed.isEmpty { issues.append(.immediateActionRequired) }
        if immediateAction.ownerMemberID.trimmed.isEmpty { issues.append(.immediateActionOwnerRequired) }
        if immediateAction.cadence == nil { issues.append(.immediateActionCadenceRequired) }
        if let dueDate = immediateAction.dueDate {
            if dueDate < startDate { issues.append(.immediateActionDateInvalid) }
        } else {
            issues.append(.immediateActionDateRequired)
        }

        if goal.title.trimmed.isEmpty { issues.append(.goalRequired) }
        if goal.baseline.trimmed.isEmpty { issues.append(.goalBaselineRequired) }
        if goal.target.trimmed.isEmpty { issues.append(.goalTargetRequired) }
        if goal.measure == nil { issues.append(.goalMeasureRequired) }
        if goal.responsibleMemberID.trimmed.isEmpty { issues.append(.goalOwnerRequired) }
        if let dueDate = goal.dueDate {
            if dueDate < startDate { issues.append(.goalDateInvalid) }
        } else {
            issues.append(.goalDateRequired)
        }

        if !supportMaterialsReviewed { issues.append(.supportMaterialsReviewRequired) }
        if let targetDate {
            if targetDate < startDate { issues.append(.targetDateInvalid) }
        } else {
            issues.append(.targetDateRequired)
        }
        if let reviewDate {
            if reviewDate < startDate || targetDate.map({ reviewDate > $0 }) == true {
                issues.append(.reviewDateInvalid)
            }
        } else {
            issues.append(.reviewDateRequired)
        }
        if meetingCadence == nil { issues.append(.meetingCadenceRequired) }
        if studentVoice.trimmed.isEmpty { issues.append(.studentVoiceRequired) }
        if familyCollaborationPermission == .notRecorded {
            issues.append(.familyPermissionRequired)
        } else if familyCollaborationPermission == .authorized, familyConsentID.trimmed.isEmpty {
            issues.append(.familyConsentRequired)
        }
        if !reviewedForSubmission { issues.append(.finalReviewRequired) }
        return issues
    }

    func chooseRecommendation(_ recommendation: PlanRecommendation) {
        applyModel(recommendation.model, source: .recommendation)
        selectedRecommendation = recommendation
    }

    func chooseManualModel(_ model: TMIPlanModel) {
        applyModel(model, source: .manual)
        selectedRecommendation = nil
    }

    func scheduleAutosave() {
        guard canEdit else { return }
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(650))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await self?.autosave()
        }
    }

    func autosave() async {
        guard canEdit, let draft = draftForPersistence() else { return }
        guard PlanValidation.issues(for: draft, member: member).isEmpty else { return }

        savePhase = .saving
        conflict = nil
        do {
            let record: PlanRecord
            if let currentRecord {
                record = try await repository.update(
                    id: currentRecord.id,
                    draft: draft,
                    expectedVersion: currentRecord.metadata.recordVersion,
                    member: member
                )
            } else {
                record = try await repository.create(
                    draft,
                    operationID: operationID,
                    member: member
                )
            }
            currentRecord = record
            try await persistCompleteChildren(planID: record.id)
            savePhase = .saved
        } catch let error as PlanRecordRepositoryError {
            await handle(error, localDraft: draft)
        } catch {
            savePhase = .failed("The draft could not be saved. Your changes are still here.")
        }
    }

    func submit() async {
        let issues = submissionIssues
        guard issues.isEmpty else {
            savePhase = .failed(issues.map(\.message).joined(separator: " "))
            return
        }
        await autosave()
        guard savePhase == .saved, let currentRecord else { return }
        do {
            let transitioned = try await repository.transition(
                id: currentRecord.id,
                to: .pendingApproval,
                expectedVersion: currentRecord.metadata.recordVersion,
                member: member
            )
            self.currentRecord = transitioned
            savePhase = .submitted
        } catch let error as PlanRecordRepositoryError {
            guard let draft = draftForPersistence() else { return }
            await handle(error, localDraft: draft)
        } catch {
            savePhase = .failed("The plan could not be submitted. Your draft is still saved.")
        }
    }

    func resolveConflictUsingServer() {
        guard let server = conflict?.serverRecord else { return }
        currentRecord = server
        modelSelection = server.modelSelectionSource == .recommendation
            ? .recommendation(server.model)
            : .manual(server.model)
        selectedNeedTags = server.needTags
        signalsReviewed = server.signalsReviewed
        professionalNeed = server.professionalNeed ?? ""
        interestsAndCareersReviewed = server.interestsAndCareersReviewed
        relatedInterestIDs = server.relatedInterestIDs
        relatedCareerIDs = server.relatedCareerIDs
        planOwnerMemberID = server.effectiveOwnerMemberID
        supportMaterialsReviewed = server.supportMaterialsReviewed
        startDate = server.startDate
        targetDate = server.targetDate
        reviewDate = server.reviewDate
        meetingCadence = server.meetingCadence
        studentVoice = server.studentVoice ?? ""
        familyCollaborationPermission = server.familyCollaborationPermission
        familyConsentID = server.familyConsentID ?? ""
        title = server.title
        summary = server.summary ?? ""
        conflict = nil
        savePhase = .saved
    }

    private func applyModel(_ newModel: TMIPlanModel, source: PlanModelSelectionSource) {
        if let oldModel = modelSelection?.model {
            title = PlanCreation.title(
                movingFrom: oldModel,
                to: newModel,
                currentTitle: title
            )
        } else if title.trimmed.isEmpty {
            title = newModel.rawValue
        }
        modelSelection = source == .recommendation ? .recommendation(newModel) : .manual(newModel)
    }

    private func draftForPersistence() -> PlanDraft? {
        guard let selection = modelSelection else { return nil }
        var assignedMemberIDs = currentRecord?.assignedMemberIDs ?? [member.userID]
        assignedMemberIDs.insert(member.userID)
        if !planOwnerMemberID.trimmed.isEmpty {
            assignedMemberIDs.insert(planOwnerMemberID.trimmed)
        }
        if !immediateAction.ownerMemberID.trimmed.isEmpty {
            assignedMemberIDs.insert(immediateAction.ownerMemberID.trimmed)
        }
        if !goal.responsibleMemberID.trimmed.isEmpty {
            assignedMemberIDs.insert(goal.responsibleMemberID.trimmed)
        }

        let recommendation = selection.source == .recommendation ? selectedRecommendation : nil
        return PlanDraft(
            studentIDs: currentRecord?.studentIDs ?? [studentID],
            schoolIDs: currentRecord?.schoolIDs ?? [schoolID],
            assignedMemberIDs: assignedMemberIDs,
            ownerMemberID: planOwnerMemberID,
            model: selection.model,
            title: title,
            summary: summary,
            startDate: startDate,
            targetDate: targetDate,
            signalsReviewed: signalsReviewed,
            needTags: selectedNeedTags,
            professionalNeed: professionalNeed,
            interestsAndCareersReviewed: interestsAndCareersReviewed,
            relatedInterestIDs: relatedInterestIDs,
            relatedCareerIDs: relatedCareerIDs,
            supportMaterialsReviewed: supportMaterialsReviewed,
            reviewDate: reviewDate,
            meetingCadence: meetingCadence,
            studentVoice: studentVoice,
            familyCollaborationPermission: familyCollaborationPermission,
            familyConsentID: familyConsentID,
            modelSelectionSource: selection.source,
            recommendationInputRecordIDs: Set(recommendation?.inputRecordIDs ?? []),
            recommendationRulesVersion: recommendation?.rulesVersion
        )
        .normalized
    }

    private func persistCompleteChildren(planID: String) async throws {
        if let goal = completeGoal(planID: planID) {
            try await children.save(goal: goal, member: member)
        }
        if let action = completeAction(planID: planID) {
            try await children.save(action: action, member: member)
        }
    }

    private func completeGoal(planID: String) -> GoalRecord? {
        guard let measure = goal.measure,
              let dueDate = goal.dueDate,
              !goal.title.trimmed.isEmpty,
              !goal.baseline.trimmed.isEmpty,
              !goal.target.trimmed.isEmpty,
              !goal.responsibleMemberID.trimmed.isEmpty else {
            return nil
        }
        return GoalRecord(
            id: "goal_primary",
            planID: planID,
            studentID: studentID,
            title: goal.title.trimmed,
            studentFacingTitle: goal.studentFacingTitle.trimmed.isEmpty ? nil : goal.studentFacingTitle.trimmed,
            measure: measure,
            baseline: goal.baseline.trimmed,
            target: goal.target.trimmed,
            dueDate: dueDate,
            responsibleMemberID: goal.responsibleMemberID.trimmed,
            status: .notStarted
        )
    }

    private func completeAction(planID: String) -> ActionRecord? {
        guard let cadence = immediateAction.cadence,
              let dueDate = immediateAction.dueDate,
              !immediateAction.title.trimmed.isEmpty,
              !immediateAction.ownerMemberID.trimmed.isEmpty else {
            return nil
        }
        return ActionRecord(
            id: "action_immediate",
            planID: planID,
            goalID: "goal_primary",
            title: immediateAction.title.trimmed,
            ownerMemberID: immediateAction.ownerMemberID.trimmed,
            audience: immediateAction.audience,
            cadence: cadence,
            dueDate: dueDate,
            status: .open
        )
    }

    private func handle(_ error: PlanRecordRepositoryError, localDraft: PlanDraft) async {
        switch error {
        case .permissionDenied:
            savePhase = .failed("You do not have access to save this plan. Your changes are still here.")
        case .unavailable:
            savePhase = .failed("You appear to be offline. Your draft is still here.")
        case .versionConflict(let expected, let actual):
            var serverRecord: PlanRecord?
            if let id = currentRecord?.id {
                serverRecord = try? await repository.plan(id: id, member: member)
            }
            conflict = Conflict(
                expectedVersion: expected,
                actualVersion: actual,
                localDraft: localDraft,
                serverRecord: serverRecord
            )
            savePhase = .versionConflict
        case .invalidDraft:
            savePhase = .failed("Check the plan details. Your changes are still here.")
        case .notFound:
            savePhase = .failed("This plan is no longer available. Your changes are still here.")
        case .illegalTransition:
            savePhase = .failed("This plan cannot move to approval from its current status.")
        case .invalidResponse:
            savePhase = .failed("The plan response could not be verified. Your changes are still here.")
        }
    }
}
