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
        #expect(PlanLifecycle.isLegal(from: .draft, to: .active))
        #expect(PlanLifecycle.isLegal(from: .draft, to: .pendingApproval))
        #expect(PlanLifecycle.isLegal(from: .pendingApproval, to: .active))
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

    @Test("Staying in the same status is always legal")
    func identityTransitionIsLegal() {
        for status in PlanRecordStatus.allCases {
            #expect(PlanLifecycle.isLegal(from: status, to: status))
        }
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
}
