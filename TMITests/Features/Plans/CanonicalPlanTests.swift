import Foundation
import Testing
@testable import TMI

struct CanonicalPlanTests {
    private let member = MembershipContext(
        userID: "teacher-1",
        districtID: "d1",
        schoolIDs: ["school-1"],
        role: .teacher,
        capabilities: [.studentReadDetail, .studentWriteDetail],
        assignedStudentIDs: [],
        isActive: true,
        version: 1
    )

    private func variant(
        capabilities: Set<Capability> = [.studentReadDetail, .studentWriteDetail],
        isActive: Bool = true
    ) -> MembershipContext {
        MembershipContext(
            userID: member.userID,
            districtID: member.districtID,
            schoolIDs: member.schoolIDs,
            role: member.role,
            capabilities: capabilities,
            assignedStudentIDs: member.assignedStudentIDs,
            isActive: isActive,
            version: member.version
        )
    }

    private func draft(
        studentIDs: Set<String> = ["student-1"],
        schoolIDs: Set<String> = ["school-1"],
        assignedMemberIDs: Set<String> = ["teacher-1"],
        title: String = "Chase Your Space",
        targetDate: Date? = nil
    ) -> PlanDraft {
        PlanDraft(
            studentIDs: studentIDs,
            schoolIDs: schoolIDs,
            assignedMemberIDs: assignedMemberIDs,
            model: .chaseYourSpace,
            title: title,
            summary: nil,
            startDate: Date(timeIntervalSince1970: 1_000_000),
            targetDate: targetDate
        )
    }

    // MARK: - Lifecycle

    @Test("A plan walks forward through its lifecycle")
    func lifecycleMovesForward() {
        #expect(!PlanLifecycle.isLegal(from: .draft, to: .active))
        #expect(PlanLifecycle.isLegal(from: .draft, to: .pendingApproval))
        #expect(!PlanLifecycle.isLegal(from: .pendingApproval, to: .active))
        #expect(PlanLifecycle.isLegal(from: .active, to: .paused))
        #expect(PlanLifecycle.isLegal(from: .paused, to: .active))
        #expect(PlanLifecycle.isLegal(from: .active, to: .completed))
        #expect(PlanLifecycle.isLegal(from: .completed, to: .archived))
    }

    @Test("A completed plan is never reopened")
    func completedIsTerminal() {
        #expect(!PlanLifecycle.isLegal(from: .completed, to: .active))
        #expect(!PlanLifecycle.isLegal(from: .completed, to: .draft))
        #expect(!PlanLifecycle.isLegal(from: .completed, to: .paused))
        #expect(PlanLifecycle.allowedTransitions(from: .archived).isEmpty)
    }

    @Test("A plan cannot skip or reverse the lifecycle")
    func lifecycleRefusesShortcuts() {
        #expect(!PlanLifecycle.isLegal(from: .draft, to: .completed))
        #expect(!PlanLifecycle.isLegal(from: .draft, to: .paused))
        #expect(!PlanLifecycle.isLegal(from: .active, to: .draft))
        #expect(!PlanLifecycle.isLegal(from: .paused, to: .draft))
    }

    @Test("A repeated command is not a new lifecycle transition")
    func identityTransitionIsNotAMove() {
        for status in PlanRecordStatus.allCases {
            #expect(!PlanLifecycle.isLegal(from: status, to: status))
        }
    }

    @Test("Approval is a separate persisted state before activation")
    func approvalHasItsOwnState() {
        #expect(PlanRecordStatus(rawValue: "approved") == .approved)
        #expect(PlanLifecycle.isLegal(from: .pendingApproval, to: .approved))
        #expect(PlanLifecycle.isLegal(from: .approved, to: .active))
    }

    // MARK: - Validation

    @Test("A well-formed draft has no issues")
    func validDraftPasses() {
        #expect(PlanValidation.issues(for: draft(), member: member).isEmpty)
    }

    @Test("A plan cannot reach outside the member's schools")
    func rejectsForeignSchool() {
        let issues = PlanValidation.issues(
            for: draft(schoolIDs: ["school-elsewhere"]),
            member: member
        )
        #expect(!issues.isEmpty)
    }

    @Test("The author must be assigned to a plan they create")
    func rejectsUnassignedAuthor() {
        let issues = PlanValidation.issues(
            for: draft(assignedMemberIDs: ["teacher-2"]),
            member: member
        )
        #expect(!issues.isEmpty)
    }

    @Test("A plan needs a student, a school, and a title")
    func rejectsEmptyScope() {
        #expect(!PlanValidation.issues(for: draft(studentIDs: []), member: member).isEmpty)
        #expect(!PlanValidation.issues(for: draft(schoolIDs: []), member: member).isEmpty)
        #expect(!PlanValidation.issues(for: draft(title: "   "), member: member).isEmpty)
    }

    @Test("A target date cannot precede the start date")
    func rejectsInvertedDates() {
        let issues = PlanValidation.issues(
            for: draft(targetDate: Date(timeIntervalSince1970: 1)),
            member: member
        )
        #expect(!issues.isEmpty)
    }

    // MARK: - Storage identity

    @Test("Brand-fixed model names round-trip through stable identifiers")
    func modelIdentifiersRoundTrip() {
        for model in TMIPlanModel.allCases {
            let identifier = PlanModelIdentifier.identifier(for: model)
            // The display name is brand-fixed but is not a safe storage key.
            #expect(identifier != model.rawValue)
            #expect(!identifier.contains(" "))
            #expect(PlanModelIdentifier.model(for: identifier) == model)
        }
    }

    @Test("An unknown model identifier does not resolve")
    func unknownModelIdentifierFails() {
        #expect(PlanModelIdentifier.model(for: "notAModel") == nil)
    }

    // MARK: - Decoding

    @Test("A canonical document decodes into a plan record")
    func decodesCanonicalDocument() throws {
        let record = try #require(
            CanonicalPlanRepository.record(
                id: "plan-1",
                data: [
                    "districtId": "d1",
                    "studentIDs": ["student-1"],
                    "schoolIDs": ["school-1"],
                    "assignedMemberIDs": ["teacher-1"],
                    "modelID": "chaseYourSpace",
                    "title": "Chase Your Space",
                    "status": "active",
                    "createdBy": "teacher-1",
                    "recordVersion": 3
                ]
            )
        )
        #expect(record.id == "plan-1")
        #expect(record.status == .active)
        #expect(record.model == .chaseYourSpace)
        #expect(record.metadata.recordVersion == 3)
    }

    @Test("A document missing required scope fails closed")
    func rejectsIncompleteDocument() {
        // No studentIDs: the rules would refuse this document, so the client
        // must not surface it as a usable plan either.
        #expect(
            CanonicalPlanRepository.record(
                id: "plan-1",
                data: [
                    "districtId": "d1",
                    "studentIDs": [String](),
                    "schoolIDs": ["school-1"],
                    "modelID": "chaseYourSpace",
                    "title": "Broken",
                    "status": "active",
                    "createdBy": "teacher-1",
                    "recordVersion": 1
                ]
            ) == nil
        )
        #expect(
            CanonicalPlanRepository.record(
                id: "plan-1",
                data: ["districtId": "d1"]
            ) == nil
        )
    }

    // MARK: - Creation

    @Test("Creating a plan needs the authority a roster write needs")
    func creationRequiresRosterWriteAuthority() {
        #expect(PlanCreation.isAvailable(to: member))

        #expect(!PlanCreation.isAvailable(to: variant(capabilities: [.studentReadDetail])))
        #expect(!PlanCreation.isAvailable(to: variant(isActive: false)))
    }

    @Test("The title follows the chosen model until the educator claims it")
    func titleFollowsModelUntilEdited() {
        // Untouched: still the title the previous model supplied.
        #expect(
            PlanCreation.title(
                movingFrom: .chaseYourSpace,
                to: .acknowledgeInterests,
                currentTitle: TMIPlanModel.chaseYourSpace.rawValue
            ) == TMIPlanModel.acknowledgeInterests.rawValue
        )

        // An empty title is nobody's, so the model still fills it.
        #expect(
            PlanCreation.title(
                movingFrom: .chaseYourSpace,
                to: .acknowledgeInterests,
                currentTitle: "   "
            ) == TMIPlanModel.acknowledgeInterests.rawValue
        )

        // Once it is theirs, switching models leaves it alone.
        #expect(
            PlanCreation.title(
                movingFrom: .chaseYourSpace,
                to: .acknowledgeInterests,
                currentTitle: "Marcus, third period"
            ) == "Marcus, third period"
        )
    }

    @Test("A plan takes its scope from the student's roster record")
    func draftTakesScopeFromTheStudent() {
        let draft = PlanCreation.draft(
            studentID: "student-1",
            schoolID: "school-1",
            member: member,
            model: .chaseYourSpace,
            title: "  Chase   Your Space  ",
            summary: "   ",
            startDate: Date(timeIntervalSince1970: 1_000_000),
            targetDate: nil
        )

        #expect(draft.studentIDs == ["student-1"])
        #expect(draft.schoolIDs == ["school-1"])
        // The creator is assigned, which the rules require.
        #expect(draft.assignedMemberIDs == [member.userID])
        #expect(draft.title == "Chase Your Space")
        #expect(draft.summary == nil)
        #expect(PlanValidation.issues(for: draft, member: member).isEmpty)
    }

    @Test("A plan started outside your schools is refused")
    func draftCannotReachOutsideYourSchools() {
        let draft = PlanCreation.draft(
            studentID: "student-1",
            schoolID: "school-9",
            member: member,
            model: .chaseYourSpace,
            title: "Chase Your Space",
            summary: "",
            startDate: Date(timeIntervalSince1970: 1_000_000),
            targetDate: nil
        )

        #expect(
            PlanValidation.issues(for: draft, member: member)
                .contains("A plan cannot reach outside your schools.")
        )
    }

    @Test("A target date before the start is refused")
    func draftRefusesATargetBeforeTheStart() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let draft = PlanCreation.draft(
            studentID: "student-1",
            schoolID: "school-1",
            member: member,
            model: .chaseYourSpace,
            title: "Chase Your Space",
            summary: "",
            startDate: start,
            targetDate: start.addingTimeInterval(-60)
        )

        #expect(
            PlanValidation.issues(for: draft, member: member)
                .contains("The target date cannot precede the start date.")
        )
    }
}
